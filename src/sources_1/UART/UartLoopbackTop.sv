`timescale 1ns / 1ps

// =============================================================================
// UartLoopbackTop  -  Top de prueba en placa (echo / loopback)
// -----------------------------------------------------------------------------
// Top mínimo para validar la UART directamente en la Basys-3, SIN depender del
// pipeline ni de la unidad de debug (Stage 9b). Reenvía por TX cada byte que
// llega por RX (eco), y muestra el último byte recibido en los 8 LEDs.
//
// Prueba esperada (con .claude/skills/program-board/scripts/uart_echo_test.py): se envía una secuencia de
// bytes al puerto serie y se verifica que vuelvan idénticos.
//
// Manejo de solapamiento: si llega un byte mientras el TX todavía está
// transmitiendo el anterior, se guarda en r_byte con un flag r_pending y se
// emite en cuanto el TX queda libre. A 19200 baud con eco inmediato no debería
// ocurrir (RX y TX van a la misma velocidad), pero el flag lo cubre igual.
//
// Pines (ver src/constrs_1/new/basys3_uart_loopback.xdc):
//   i_clk   = W5  (100 MHz)
//   i_reset = btn
//   i_rx    = B18 (RX del puente USB-UART -> FPGA)
//   o_tx    = A18 (TX del FPGA -> puente USB-UART)
//   o_led   = LEDs
// =============================================================================
module UartLoopbackTop #(
    parameter int CLK      = 100_000_000,  // reloj de la Basys-3 [Hz]
    parameter int BAUDRATE = 19200,        // baud rate
    parameter int NB_DATA  = 8             // bits por byte
) (
    input logic i_clk,    // reloj 100 MHz (W5)
    input logic i_reset,  // reset sincronico activo-alto (boton)
    input logic i_rx,     // linea serie de entrada

    output logic               o_tx,  // linea serie de salida
    output logic [NB_DATA-1:0] o_led  // ultimo byte recibido (debug visual)
);

    // --- Senales hacia/desde la UART --------------------------------------
    logic [NB_DATA-1:0] w_rx_data;
    logic               w_rx_done_tick;
    logic               w_tx_done_tick;

    // --- Estado del eco ---------------------------------------------------
    logic [NB_DATA-1:0] r_byte;  // byte capturado, pendiente de reenviar
    logic               r_pending;  // hay un byte esperando para transmitir
    logic               r_tx_busy;  // el TX esta transmitiendo

    // Se lanza la transmision cuando hay un byte pendiente y el TX esta libre.
    logic               w_tx_start;
    assign w_tx_start = r_pending & ~r_tx_busy;

    always_ff @(posedge i_clk) begin
        if (i_reset) begin
            r_byte    <= '0;
            r_pending <= 1'b0;
            r_tx_busy <= 1'b0;
        end else begin
            // Lanzar transmision: consume el pendiente y marca el TX ocupado.
            if (w_tx_start) begin
                r_pending <= 1'b0;
                r_tx_busy <= 1'b1;
            end
            // Fin de transmision: el TX queda libre.
            if (w_tx_done_tick) begin
                r_tx_busy <= 1'b0;
            end
            // Capturar byte entrante (tiene prioridad sobre el clear de
            // r_pending de arriba para no perder un byte que llegue justo
            // al lanzar el anterior).
            if (w_rx_done_tick) begin
                r_byte    <= w_rx_data;
                r_pending <= 1'b1;
            end
        end
    end

    // Espejo del ultimo byte recibido en los LEDs.
    assign o_led = r_byte;

    // --- Instancia de la UART ---------------------------------------------
    Uart #(
        .CLK     (CLK),
        .BAUDRATE(BAUDRATE),
        .NB_DATA (NB_DATA)
    ) u_uart (
        .i_clk         (i_clk),
        .i_reset       (i_reset),
        .i_rx          (i_rx),
        .o_tx          (o_tx),
        .o_rx_data     (w_rx_data),
        .o_rx_done_tick(w_rx_done_tick),
        .i_tx_data     (r_byte),
        .i_tx_start    (w_tx_start),
        .o_tx_done_tick(w_tx_done_tick)
    );

endmodule
