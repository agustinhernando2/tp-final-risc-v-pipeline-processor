`timescale 1ns / 1ps

// =============================================================================
// BaudRateGenerator
// -----------------------------------------------------------------------------
// Genera un pulso de un ciclo de reloj (o_tick) a una frecuencia de
// BAUDRATE * OVERSAMPLE Hz. Ese "tick" es el que usan UartRx y UartTx para
// muestrear / emitir bits con sobre-muestreo (oversampling) de OVERSAMPLE
// veces por bit.
//
// Formula del divisor (Baud Rate Generator):
//     N_CONT = f_clk / (BAUDRATE * OVERSAMPLE)
//
// Ejemplo Basys-3 @ 100 MHz, 19200 baud, 16x:
//     N_CONT = 100_000_000 / (19200 * 16) = 325,5 -> 325
//     Baud real = 100e6 / (325 * 16) = 19230 baud  (error < 0,2 %, OK para UART)
//
// El contador cuenta de 0 a N_CONT-1 y, al llegar a N_CONT-1, emite el tick y
// vuelve a 0. El periodo del tick es por lo tanto exactamente N_CONT ciclos.
// =============================================================================
module BaudRateGenerator #(
    parameter int CLK        = 100_000_000,  // frecuencia del reloj de entrada [Hz]
    parameter int BAUDRATE   = 19200,        // tasa de baudios [bits/s]
    parameter int OVERSAMPLE = 16            // ticks por bit (sobre-muestreo)
) (
    input logic i_clk,   // reloj del sistema
    input logic i_reset, // reset sincronico activo-alto

    output logic o_tick  // pulso de 1 ciclo a BAUDRATE*OVERSAMPLE Hz
);

    // Numero de ciclos de reloj entre ticks y bits necesarios para contarlos.
    localparam int N_CONT = CLK / (BAUDRATE * OVERSAMPLE);
    localparam int N_BITS = (N_CONT > 1) ? $clog2(N_CONT) : 1;

    logic [N_BITS-1:0] r_counter;

    always_ff @(posedge i_clk) begin
        if (i_reset) begin
            r_counter <= '0;
        end else if (r_counter == N_BITS'(N_CONT - 1)) begin
            r_counter <= '0;  // reinicia el contador en el ultimo ciclo
        end else begin
            r_counter <= r_counter + 1'b1;
        end
    end

    // El tick es un pulso de exactamente un ciclo de reloj.
    assign o_tick = (r_counter == N_BITS'(N_CONT - 1));

endmodule
