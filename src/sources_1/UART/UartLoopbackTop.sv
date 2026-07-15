`timescale 1ns / 1ps

// =============================================================================
// UartLoopbackTop  -  On-board test top (echo / loopback)
// -----------------------------------------------------------------------------
// Minimal top to validate the UART directly on the Basys-3, WITHOUT depending on
// the pipeline or the debug unit. Echoes back over TX every byte that arrives on
// RX, and shows the last received byte on the 8 LEDs.
//
// Expected test: send a sequence of bytes to the serial port and verify they
// come back identical.
//
// Overlap handling: if a byte arrives while TX is still sending the previous one,
// it is stored in r_byte with an r_pending flag and emitted as soon as TX is
// free. At 19200 baud with immediate echo this should not happen (RX and TX run
// at the same rate), but the flag covers it anyway.
//
// Pins (see src/constrs_1/new/basys3_uart_loopback.xdc):
//   i_clk   = W5  (100 MHz)
//   i_reset = btn
//   i_rx    = B18 (USB-UART bridge RX -> FPGA)
//   o_tx    = A18 (FPGA TX -> USB-UART bridge)
//   o_led   = LEDs
// =============================================================================
module UartLoopbackTop #(
    parameter int CLK      = 100_000_000,  // 100 MHz
    parameter int BAUDRATE = 19200,        // baud rate
    parameter int NB_DATA  = 8             // bits per byte
) (
    input logic i_clk,    // 100 MHz clock (W5)
    input logic i_reset,  // synchronous active-high reset (button)
    input logic i_rx,     // serial input line

    output logic               o_tx,  // serial output line
    output logic [NB_DATA-1:0] o_led  // last received byte (visual debug)
);

    // --- UART signals -----------------------------------------------------
    logic [NB_DATA-1:0] w_rx_data;
    logic               w_rx_done_tick;
    logic               w_tx_done_tick;

    // --- Echo state -------------------------------------------------------
    logic [NB_DATA-1:0] r_byte;  // captured byte, pending re-send
    logic               r_pending;  // a byte is waiting to transmit
    logic               r_tx_busy;  // TX is transmitting

    // Start transmission when there is a pending byte and TX is free.
    logic               w_tx_start;
    assign w_tx_start = r_pending & ~r_tx_busy;

    always_ff @(posedge i_clk) begin
        if (i_reset) begin
            r_byte    <= '0;
            r_pending <= 1'b0;
            r_tx_busy <= 1'b0;
        end else begin
            // Start transmission: consume the pending byte and mark TX busy.
            if (w_tx_start) begin
                r_pending <= 1'b0;
                r_tx_busy <= 1'b1;
            end
            // End of transmission: TX becomes free.
            if (w_tx_done_tick) begin
                r_tx_busy <= 1'b0;
            end
            // Capture incoming byte (takes priority over the r_pending clear
            // above so a byte arriving right as the previous one is launched is
            // not lost).
            if (w_rx_done_tick) begin
                r_byte    <= w_rx_data;
                r_pending <= 1'b1;
            end
        end
    end

    // Mirror the last received byte on the LEDs.
    assign o_led = r_byte;

    // --- UART instance ----------------------------------------------------
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
