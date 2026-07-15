`timescale 1ns / 1ps

// =============================================================================
// BaudRateGenerator
// -----------------------------------------------------------------------------
// Generates a single-clock-cycle pulse (o_tick) at BAUDRATE * OVERSAMPLE Hz.
// UartRx and UartTx use this tick to sample / drive bits with OVERSAMPLE-times
// oversampling per bit.
//
// Divisor formula:
//     N_CONT = f_clk / (BAUDRATE * OVERSAMPLE)
//
// Example @ 100 MHz, 19200 baud, 16x:
//     N_CONT = 100_000_000 / (19200 * 16) = 325.5 -> 325
//     Actual baud = 100e6 / (325 * 16) = 19230 baud  (error < 0.2 %, fine for UART)
//
// The counter runs 0..N_CONT-1; on reaching N_CONT-1 it emits the tick and wraps
// to 0, so the tick period is exactly N_CONT cycles.
// =============================================================================
module BaudRateGenerator #(
    parameter int CLK        = 100_000_000,  // input clock frequency [Hz]
    parameter int BAUDRATE   = 19200,        // baud rate [bits/s]
    parameter int OVERSAMPLE = 16            // ticks per bit (oversampling)
) (
    input logic i_clk,   // system clock
    input logic i_reset, // synchronous active-high reset

    output logic o_tick  // 1-cycle pulse at BAUDRATE*OVERSAMPLE Hz
);

    // Clock cycles between ticks, and the bits needed to count them.
    localparam int N_CONT = CLK / (BAUDRATE * OVERSAMPLE);
    localparam int N_BITS = (N_CONT > 1) ? $clog2(N_CONT) : 1;

    logic [N_BITS-1:0] r_counter;

    always_ff @(posedge i_clk) begin
        if (i_reset) begin
            r_counter <= '0;
        end else if (r_counter == N_BITS'(N_CONT - 1)) begin
            r_counter <= '0;  // wrap on the last cycle
        end else begin
            r_counter <= r_counter + 1'b1;
        end
    end

    // The tick is a pulse of exactly one clock cycle.
    assign o_tick = (r_counter == N_BITS'(N_CONT - 1));

endmodule
