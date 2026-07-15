`timescale 1ns / 1ps

// =============================================================================
// UartTx  -  UART transmitter (8N1)
// -----------------------------------------------------------------------------
// Transmits a byte serially (1 start bit, DBIT data bits LSB-first, 1 stop bit).
// Transmission starts on a pulse of i_tx_start, which captures i_data. When done
// it pulses o_tx_done_tick for one cycle. The o_tx line idles high (1) when not
// transmitting.
//
// Synchronization: uses the BaudRateGenerator tick (i_s_tick). Each bit lasts
// SB_TICK ticks.
//
// State machine:
//   IDLE  -> o_tx = 1; on i_tx_start, loads i_data and starts
//   START -> o_tx = 0 for one bit (start bit)
//   DATA  -> drives shiftreg[0] (LSB) and shifts right every SB_TICK ticks
//   STOP  -> o_tx = 1 for one bit (stop bit) and pulses o_tx_done_tick
// =============================================================================
module UartTx #(
    parameter int DBIT    = 8,   // data bits per frame
    parameter int SB_TICK = 16   // ticks per bit (= baud gen OVERSAMPLE)
) (
    input logic            i_clk,       // system clock
    input logic            i_reset,     // synchronous active-high reset
    input logic            i_tx_start,  // pulse: start transmission
    input logic            i_s_tick,    // BaudRateGenerator tick
    input logic [DBIT-1:0] i_data,      // byte to transmit

    output logic o_tx_done_tick,  // 1-cycle pulse: transmission done
    output logic o_tx             // serial output line (idles high)
);

    // FSM states.
    typedef enum logic [1:0] {
        IDLE,   // idle, waiting for i_tx_start
        START,  // sending start bit
        DATA,   // sending data bits
        STOP    // sending stop bit
    } state_t;

    state_t r_state, w_next_state;
    logic [$clog2(SB_TICK)-1:0] r_tick_cnt, w_next_tick_cnt;  // tick counter within a bit
    logic [$clog2(DBIT)-1:0] r_data_cnt, w_next_data_cnt;  // data-bit counter
    logic [DBIT-1:0] r_shiftreg, w_next_shiftreg;  // shift register
    logic r_tx, w_next_tx;  // registered TX line value

    // --- State registers (sequential) -------------------------------------
    always_ff @(posedge i_clk) begin
        if (i_reset) begin
            r_state    <= IDLE;
            r_tick_cnt <= '0;
            r_data_cnt <= '0;
            r_shiftreg <= '0;
            r_tx       <= 1'b1;  // line idle (high)
        end else begin
            r_state    <= w_next_state;
            r_tick_cnt <= w_next_tick_cnt;
            r_data_cnt <= w_next_data_cnt;
            r_shiftreg <= w_next_shiftreg;
            r_tx       <= w_next_tx;
        end
    end

    // --- Next-state logic (combinational) ---------------------------------
    always_comb begin
        // defaults: hold state
        w_next_state    = r_state;
        w_next_tick_cnt = r_tick_cnt;
        w_next_data_cnt = r_data_cnt;
        w_next_shiftreg = r_shiftreg;
        w_next_tx       = r_tx;
        o_tx_done_tick  = 1'b0;

        case (r_state)
            IDLE: begin
                w_next_tx = 1'b1;  // line idle
                if (i_tx_start) begin
                    w_next_state    = START;
                    w_next_tick_cnt = '0;
                    w_next_shiftreg = i_data;  // capture the byte to transmit
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
                w_next_tx = r_shiftreg[0];  // drive the LSB
                if (i_s_tick) begin
                    if (r_tick_cnt == (SB_TICK - 1)) begin
                        w_next_tick_cnt = '0;
                        w_next_shiftreg = r_shiftreg >> 1;  // next bit to the LSB
                        if (r_data_cnt == (DBIT - 1)) begin
                            w_next_state = STOP;  // all bits sent
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
