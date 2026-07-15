`timescale 1ns / 1ps

// =============================================================================
// UartRx  -  UART receiver (8N1)
// -----------------------------------------------------------------------------
// Receives a serial byte (1 start bit, DBIT data bits LSB-first, 1 stop bit) and
// delivers it in parallel on o_data, pulsing o_rx_done_tick for one cycle when
// reception completes.
//
// Synchronization: uses the BaudRateGenerator tick (i_s_tick), which pulses
// SB_TICK times per bit. The i_rx line idles high (1).
//
// State machine:
//   IDLE  -> waits for the falling edge (start bit -> i_rx = 0)
//   START -> counts to the middle of the start bit (tick 7 of 16) to align
//            sampling to the center of each bit
//   DATA  -> every SB_TICK ticks, samples i_rx into the MSB of the shift
//            register (LSB received first)
//   STOP  -> waits for the full stop bit and pulses o_rx_done_tick
// =============================================================================
module UartRx #(
    parameter int DBIT    = 8,
    parameter int SB_TICK = 16   // ticks per bit (= baud gen OVERSAMPLE)
) (
    input logic i_clk,
    input logic i_reset,
    input logic i_rx,
    input logic i_s_tick, // BaudRateGenerator tick

    output logic            o_rx_done_tick,  // 1-cycle pulse: byte received
    output logic [DBIT-1:0] o_data           // received byte
);

    // FSM states.
    typedef enum logic [1:0] {
        IDLE,   // waiting for start bit
        START,  // aligning to the center of the start bit
        DATA,   // receiving data bits
        STOP    // waiting for stop bit
    } state_t;

    state_t r_state, w_next_state;
    logic [$clog2(SB_TICK)-1:0] r_tick_cnt, w_next_tick_cnt;  // tick counter within a bit
    logic [$clog2(DBIT)-1:0] r_data_cnt, w_next_data_cnt;  // data-bit counter
    logic [DBIT-1:0] r_shiftreg, w_next_shiftreg;  // shift register

    // --- State registers (sequential) -------------------------------------
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

    // --- Next-state logic (combinational) ---------------------------------
    always_comb begin
        // defaults: hold state
        w_next_state    = r_state;
        w_next_tick_cnt = r_tick_cnt;
        w_next_data_cnt = r_data_cnt;
        w_next_shiftreg = r_shiftreg;
        o_rx_done_tick  = 1'b0;

        case (r_state)
            IDLE: begin
                // Detect the start bit: line drops to 0.
                if (~i_rx) begin
                    w_next_state    = START;
                    w_next_tick_cnt = '0;
                end
            end

            START: begin
                // Advance tick by tick to the middle of the start bit (tick 7),
                // so from there on we sample at the center of each bit.
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
                // One full bit every SB_TICK ticks.
                if (i_s_tick) begin
                    if (r_tick_cnt == (SB_TICK - 1)) begin
                        w_next_tick_cnt = '0;
                        // shift new bit into the MSB, dropping the current LSB
                        w_next_shiftreg = {i_rx, r_shiftreg[DBIT-1:1]};
                        if (r_data_cnt == (DBIT - 1)) begin
                            w_next_state = STOP;
                        end else begin
                            w_next_data_cnt = r_data_cnt + 1'b1;
                        end
                    end else begin
                        w_next_tick_cnt = r_tick_cnt + 1'b1;
                    end
                end
            end

            STOP: begin
                // Wait for the full stop bit and flag reception complete.
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
