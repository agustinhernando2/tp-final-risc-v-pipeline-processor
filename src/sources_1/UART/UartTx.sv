`timescale 1ns / 1ps

// =============================================================================
// UartTx  -  Transmisor UART (8N1)
// -----------------------------------------------------------------------------
// Transmite un byte en serie (1 start bit, DBIT bits de datos LSB-first,
// 1 stop bit). La transmision arranca con un pulso en i_tx_start, que captura
// i_data. Al terminar pulsa o_tx_done_tick un ciclo. La linea o_tx queda en
// reposo en alto (1) cuando no transmite.
//
// Sincronizacion: usa el "tick" del BaudRateGenerator (i_s_tick). Cada bit dura
// SB_TICK ticks.
//
// Maquina de estados:
//   IDLE  -> o_tx = 1; al recibir i_tx_start carga i_data y arranca
//   START -> o_tx = 0 durante un bit (start bit)
//   DATA  -> emite shiftreg[0] (LSB) y desplaza a la derecha cada SB_TICK ticks
//   STOP  -> o_tx = 1 durante un bit (stop bit) y pulsa o_tx_done_tick
// =============================================================================
module UartTx #(
    parameter int DBIT    = 8,   // bits de datos por trama
    parameter int SB_TICK = 16   // ticks por bit (= OVERSAMPLE del baud gen)
) (
    input logic            i_clk,       // reloj del sistema
    input logic            i_reset,     // reset sincronico activo-alto
    input logic            i_tx_start,  // pulso: iniciar transmision
    input logic            i_s_tick,    // tick del BaudRateGenerator
    input logic [DBIT-1:0] i_data,      // byte a transmitir

    output logic o_tx_done_tick,  // pulso de 1 ciclo: transmision lista
    output logic o_tx             // linea serie de salida (reposo en 1)
);

    // Estados de la FSM.
    typedef enum logic [1:0] {
        IDLE,   // en reposo, esperando i_tx_start
        START,  // enviando start bit
        DATA,   // enviando bits de datos
        STOP    // enviando stop bit
    } state_t;

    state_t r_state, w_next_state;
    logic [$clog2(SB_TICK)-1:0] r_tick_cnt, w_next_tick_cnt;  // contador de ticks dentro del bit
    logic [$clog2(DBIT)-1:0] r_data_cnt, w_next_data_cnt;  // contador de bits de datos
    logic [DBIT-1:0] r_shiftreg, w_next_shiftreg;  // registro de desplazamiento
    logic r_tx, w_next_tx;  // valor registrado de la linea TX

    // --- Registros de estado (secuencial) ---------------------------------
    always_ff @(posedge i_clk) begin
        if (i_reset) begin
            r_state    <= IDLE;
            r_tick_cnt <= '0;
            r_data_cnt <= '0;
            r_shiftreg <= '0;
            r_tx       <= 1'b1;  // linea en reposo (alto)
        end else begin
            r_state    <= w_next_state;
            r_tick_cnt <= w_next_tick_cnt;
            r_data_cnt <= w_next_data_cnt;
            r_shiftreg <= w_next_shiftreg;
            r_tx       <= w_next_tx;
        end
    end

    // --- Logica de proximo estado (combinacional) -------------------------
    always_comb begin
        // valores por defecto: mantener estado
        w_next_state    = r_state;
        w_next_tick_cnt = r_tick_cnt;
        w_next_data_cnt = r_data_cnt;
        w_next_shiftreg = r_shiftreg;
        w_next_tx       = r_tx;
        o_tx_done_tick  = 1'b0;

        case (r_state)
            IDLE: begin
                w_next_tx = 1'b1;  // linea en reposo
                if (i_tx_start) begin
                    w_next_state    = START;
                    w_next_tick_cnt = '0;
                    w_next_shiftreg = i_data;  // captura el byte a transmitir
                end
            end

            START: begin
                w_next_tx = 1'b0;  // start bit
                if (i_s_tick) begin
                    if (r_tick_cnt == (SB_TICK - 1)) begin
                        w_next_state    = DATA;
                        w_next_tick_cnt = '0;
                        w_next_data_cnt = '0;
                    end else begin
                        w_next_tick_cnt = r_tick_cnt + 1'b1;
                    end
                end
            end

            DATA: begin
                w_next_tx = r_shiftreg[0];  // emite el LSB
                if (i_s_tick) begin
                    if (r_tick_cnt == (SB_TICK - 1)) begin
                        w_next_tick_cnt = '0;
                        w_next_shiftreg = r_shiftreg >> 1;  // siguiente bit al LSB
                        if (r_data_cnt == (DBIT - 1)) begin
                            w_next_state = STOP;  // ya se enviaron todos los bits
                        end else begin
                            w_next_data_cnt = r_data_cnt + 1'b1;
                        end
                    end else begin
                        w_next_tick_cnt = r_tick_cnt + 1'b1;
                    end
                end
            end

            STOP: begin
                w_next_tx = 1'b1;  // stop bit
                if (i_s_tick) begin
                    if (r_tick_cnt == (SB_TICK - 1)) begin
                        w_next_state   = IDLE;
                        o_tx_done_tick = 1'b1;
                    end else begin
                        w_next_tick_cnt = r_tick_cnt + 1'b1;
                    end
                end
            end

            default: w_next_state = IDLE;
        endcase
    end

    assign o_tx = r_tx;

endmodule
