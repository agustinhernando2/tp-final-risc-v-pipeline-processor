`timescale 1ns / 1ps

// =============================================================================
// Uart  -  Wrapper UART full-duplex
// -----------------------------------------------------------------------------
// Integra en un solo modulo:
//   - BaudRateGenerator : genera el tick de sobre-muestreo compartido
//   - UartRx            : recepcion serie -> paralelo
//   - UartTx            : transmision paralelo -> serie
//
// Configuracion por defecto: 100 MHz de reloj, 19200 baud, 8N1, oversampling 16x.
// Todos los anchos y la temporizacion son parametrizables.
//
// Uso:
//   - Recepcion: cuando o_rx_done_tick pulsa, o_rx_data tiene el byte valido.
//   - Transmision: poner el byte en i_tx_data y pulsar i_tx_start un ciclo
//     (solo cuando el TX este libre); o_tx_done_tick pulsa al terminar.
// =============================================================================
module Uart #(
    parameter int CLK        = 100_000_000,  // frecuencia del reloj [Hz]
    parameter int BAUDRATE   = 19200,        // tasa de baudios [bits/s]
    parameter int OVERSAMPLE = 16,           // ticks por bit
    parameter int NB_DATA    = 8             // bits de datos por trama
) (
    input logic i_clk,   // reloj del sistema
    input logic i_reset, // reset sincronico activo-alto

    // Lado serie
    input  logic i_rx,  // linea serie de entrada
    output logic o_tx,  // linea serie de salida

    // Lado paralelo - recepcion
    output logic [NB_DATA-1:0] o_rx_data,      // byte recibido
    output logic               o_rx_done_tick, // pulso: byte recibido

    // Lado paralelo - transmision
    input  logic [NB_DATA-1:0] i_tx_data,      // byte a transmitir
    input  logic               i_tx_start,     // pulso: iniciar transmision
    output logic               o_tx_done_tick  // pulso: transmision lista
);

    // Tick de sobre-muestreo compartido por RX y TX.
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
