`timescale 1ns / 1ps

// =============================================================================
// Uart  -  Full-duplex UART wrapper
// -----------------------------------------------------------------------------
// Bundles into a single module:
//   - BaudRateGenerator : generates the shared oversampling tick
//   - UartRx            : serial -> parallel reception
//   - UartTx            : parallel -> serial transmission
//
// Default configuration: 100 MHz clock, 19200 baud, 8N1, 16x oversampling.
// All widths and timing are parameterizable.
//
// Usage:
//   - Reception: when o_rx_done_tick pulses, o_rx_data holds the valid byte.
//   - Transmission: place the byte on i_tx_data and pulse i_tx_start for one
//     cycle (only while TX is free); o_tx_done_tick pulses when done.
// =============================================================================
module Uart #(
    parameter int CLK        = 100_000_000,  // clock frequency [Hz]
    parameter int BAUDRATE   = 19200,        // baud rate [bits/s]
    parameter int OVERSAMPLE = 16,           // ticks per bit
    parameter int NB_DATA    = 8             // data bits per frame
) (
    input logic i_clk,   // system clock
    input logic i_reset, // synchronous active-high reset

    // Serial side
    input  logic i_rx,  // serial input line
    output logic o_tx,  // serial output line

    // Parallel side - reception
    output logic [NB_DATA-1:0] o_rx_data,      // received byte
    output logic               o_rx_done_tick, // pulse: byte received

    // Parallel side - transmission
    input  logic [NB_DATA-1:0] i_tx_data,      // byte to transmit
    input  logic               i_tx_start,     // pulse: start transmission
    output logic               o_tx_done_tick  // pulse: transmission done
);

    // Oversampling tick shared by RX and TX.
    logic w_s_tick;

    BaudRateGenerator #(
        .CLK       (CLK),
        .BAUDRATE  (BAUDRATE),
        .OVERSAMPLE(OVERSAMPLE)
    ) u_baud_gen (
        .i_clk  (i_clk),
        .i_reset(i_reset),
        .o_tick (w_s_tick)
    );

    UartRx #(
        .DBIT   (NB_DATA),
        .SB_TICK(OVERSAMPLE)
    ) u_rx (
        .i_clk         (i_clk),
        .i_reset       (i_reset),
        .i_rx          (i_rx),
        .i_s_tick      (w_s_tick),
        .o_rx_done_tick(o_rx_done_tick),
        .o_data        (o_rx_data)
    );

    UartTx #(
        .DBIT   (NB_DATA),
        .SB_TICK(OVERSAMPLE)
    ) u_tx (
        .i_clk         (i_clk),
        .i_reset       (i_reset),
        .i_tx_start    (i_tx_start),
        .i_s_tick      (w_s_tick),
        .i_data        (i_tx_data),
        .o_tx_done_tick(o_tx_done_tick),
        .o_tx          (o_tx)
    );

endmodule
