`timescale 1ns / 1ps

// =============================================================================
// UartRx  -  Receptor UART (8N1)
// -----------------------------------------------------------------------------
// Recibe un byte serie (formato 1 start bit, DBIT bits de datos LSB-first,
// 1 stop bit) y lo entrega en paralelo por o_data, pulsando o_rx_done_tick un
// ciclo cuando la recepcion termina.
//
// Sincronizacion: usa el "tick" del BaudRateGenerator (i_s_tick), que pulsa
// SB_TICK veces por bit. La linea i_rx esta en reposo en alto (1).
//
// Maquina de estados:
//   IDLE  -> espera el flanco de bajada (start bit -> i_rx = 0)
//   START -> cuenta hasta la mitad del start bit (tick 7 de 16) para alinear
//            el muestreo al centro de cada bit
//   DATA  -> cada SB_TICK ticks muestrea i_rx y lo mete por el MSB del
//            registro de desplazamiento (recibe LSB primero)
//   STOP  -> espera el stop bit completo y pulsa o_rx_done_tick
// =============================================================================
module UartRx #(
    parameter int DBIT    = 8,   // bits de datos por trama
    parameter int SB_TICK = 16   // ticks por bit (= OVERSAMPLE del baud gen)
) (
    input logic i_clk,    // reloj del sistema
    input logic i_reset,  // reset sincronico activo-alto
    input logic i_rx,     // linea serie de entrada (reposo en 1)
    input logic i_s_tick, // tick del BaudRateGenerator

    output logic            o_rx_done_tick,  // pulso de 1 ciclo: byte recibido
    output logic [DBIT-1:0] o_data           // byte recibido
);

    // Estados de la FSM.
    typedef enum logic [1:0] {
        IDLE,   // esperando start bit
        START,  // alineando al centro del start bit
        DATA,   // recibiendo bits de datos
        STOP    // esperando stop bit
    } state_t;

    state_t r_state, w_next_state;
    logic [$clog2(SB_TICK)-1:0] r_tick_cnt, w_next_tick_cnt;  // contador de ticks dentro del bit
    logic [$clog2(DBIT)-1:0] r_data_cnt, w_next_data_cnt;  // contador de bits de datos
    logic [DBIT-1:0] r_shiftreg, w_next_shiftreg;  // registro de desplazamiento

    // --- Registros de estado (secuencial) ---------------------------------
    always_ff @(posedge i_clk) begin
        if (i_reset) begin
            r_state    <= IDLE;
            r_tick_cnt <= '0;
            r_data_cnt <= '0;
            r_shiftreg <= '0;
        end else begin
            r_state    <= w_next_state;
            r_tick_cnt <= w_next_tick_cnt;
            r_data_cnt <= w_next_data_cnt;
            r_shiftreg <= w_next_shiftreg;
        end
    end

    // --- Logica de proximo estado (combinacional) -------------------------
    always_comb begin
        // valores por defecto: mantener estado
        w_next_state    = r_state;
        w_next_tick_cnt = r_tick_cnt;
        w_next_data_cnt = r_data_cnt;
        w_next_shiftreg = r_shiftreg;
        o_rx_done_tick  = 1'b0;

        case (r_state)
            IDLE: begin
                // Detecta el start bit: la linea cae a 0.
                if (~i_rx) begin
                    w_next_state    = START;
                    w_next_tick_cnt = '0;
                end
            end

            START: begin
                // Avanza tick a tick hasta la mitad del start bit (tick 7),
                // asi a partir de ahi muestreamos en el centro de cada bit.
                if (i_s_tick) begin
                    if (r_tick_cnt == (SB_TICK / 2 - 1)) begin
                        w_next_state    = DATA;
                        w_next_tick_cnt = '0;
                        w_next_data_cnt = '0;
                    end else begin
                        w_next_tick_cnt = r_tick_cnt + 1'b1;
                    end
                end
            end

            DATA: begin
                // Un bit completo cada SB_TICK ticks.
                if (i_s_tick) begin
                    if (r_tick_cnt == (SB_TICK - 1)) begin
                        w_next_tick_cnt = '0;
                        // Entra el bit nuevo por el MSB (recepcion LSB-first).
                        w_next_shiftreg = {i_rx, r_shiftreg[DBIT-1:1]};
                        if (r_data_cnt == (DBIT - 1)) begin
                            w_next_state = STOP;  // ya entraron todos los bits
                        end else begin
                            w_next_data_cnt = r_data_cnt + 1'b1;
                        end
                    end else begin
                        w_next_tick_cnt = r_tick_cnt + 1'b1;
                    end
                end
            end

            STOP: begin
                // Espera el stop bit completo y marca recepcion terminada.
                if (i_s_tick) begin
                    if (r_tick_cnt == (SB_TICK - 1)) begin
                        w_next_state   = IDLE;
                        o_rx_done_tick = 1'b1;
                    end else begin
                        w_next_tick_cnt = r_tick_cnt + 1'b1;
                    end
                end
            end

            default: w_next_state = IDLE;
        endcase
    end

    assign o_data = r_shiftreg;

endmodule
