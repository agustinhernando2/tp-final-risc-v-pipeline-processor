`timescale 1ns / 1ps

// =============================================================================
// DebugUnit  -  Processor debug / control unit over UART
// -----------------------------------------------------------------------------
// FSM that drives the RISC-V external interface:
//
//   - Program load: receives the program bytes over UART, assembles them into
//     32-bit words (RISC-V instructions) and writes them into the core's
//     instruction memory (i_imem_wr/addr/data port).
//   - Continuous run: runs the pipeline until HALT is detected (i_halt), then
//     dumps state.
//   - Step-by-step: executes exactly one cycle per command and dumps state.
//   - Dump: transmits PC, the 32 registers, data memory, and the contents of the
//     pipeline latches (IF/ID, ID/EX, EX/MEM, MEM/WB buffers).
//
// UART protocol (8N1, MSB-first / big-endian), matching the host GUI:
//   Commands (1 byte): 1=WRITE_IM, 2=CONTINUE, 3=STEP_BY_STEP, 4=SEND_INFO, 5=STEP
//   Load: after 0x01, IM_WORDS instructions x 4 bytes (most significant byte of
//         each instruction first).
//   Dump: PC -> 32 registers -> DM_DEPTH mem words -> LATCH_COUNT latches, each
//         value as NB_BYTES = DATA_WIDTH/8 bytes, MSB-first.
//
// Timing note: the FSM runs on the **falling edge** of the clock. The pipeline
// runs on the rising edge and samples o_pipeline_enable / o_imem_wr; updating the
// FSM on the opposite edge keeps those signals stable before the rising edge that
// uses them (avoids races).
// =============================================================================
module DebugUnit #(
    parameter int NB_DATA = 8,  // UART byte width
    parameter int NB_PC = 64,  // PC width
    parameter int DATA_WIDTH = 64,  // register / data memory width
    parameter int NB_REG = 5,  // register file address width (32 regs)
    parameter int NB_IADDR = 8,  // instruction memory address width (word index)
    parameter int NB_INST = 32,  // instruction width
    parameter int NB_DADDR = 6,  // data memory address width (64 words)
    parameter int IM_WORDS = 64,  // program instructions (must match the host GUI)
    parameter int RB_DEPTH = 32,  // number of registers to dump
    parameter int DM_DEPTH = 64,  // number of data memory words to dump
    parameter int LATCH_COUNT = 25,  // pipeline latch fields to dump
    parameter int NB_LADDR = 5  // latch dump address width (>= clog2(LATCH_COUNT))
) (
    input logic i_clk,
    input logic i_reset,

    // Processor state
    input logic                  i_halt,       // HALT reached MEM (end of program)
    input logic [     NB_PC-1:0] i_pc,         // current PC
    input logic [DATA_WIDTH-1:0] i_reg_data,   // register read at o_reg_addr
    input logic [DATA_WIDTH-1:0] i_mem_data,   // data mem word read at o_mem_data_addr
    input logic [DATA_WIDTH-1:0] i_latch_data, // latch field read at o_latch_addr

    // UART
    input  logic               i_rx_done,  // byte received
    input  logic               i_tx_done,  // byte transmitted
    input  logic [NB_DATA-1:0] i_rx_data,  // received byte
    output logic [NB_DATA-1:0] o_tx_data,  // byte to transmit
    output logic               o_tx_start, // start transmission

    // Instruction memory load
    output logic                o_imem_wr,    // write enable to the core IM
    output logic [NB_IADDR-1:0] o_imem_addr,  // IM word index
    output logic [ NB_INST-1:0] o_imem_data,  // assembled instruction (32 bits)

    // Read addresses for the dump
    output logic [  NB_REG-1:0] o_reg_addr,       // register to read
    output logic [NB_DADDR-1:0] o_mem_data_addr,  // data mem word to read
    output logic [NB_LADDR-1:0] o_latch_addr,     // latch field to read

    // Pipeline control
    output logic o_pipeline_enable,  // 1 = core advances; 0 = frozen

    // FSM state (one-hot, for debug LEDs)
    output logic [7:0] o_state
);

    localparam int NB_BYTES = DATA_WIDTH / 8;  // bytes per dump value

    // -------------------------------------------------------------------------
    // UART commands
    // -------------------------------------------------------------------------
    localparam logic [NB_DATA-1:0] CMD_WRITE_IM = 8'd1;
    localparam logic [NB_DATA-1:0] CMD_CONTINUE = 8'd2;
    localparam logic [NB_DATA-1:0] CMD_STEP_BY_STEP = 8'd3;
    localparam logic [NB_DATA-1:0] CMD_SEND_INFO = 8'd4;
    localparam logic [NB_DATA-1:0] CMD_STEP = 8'd5;

    // -------------------------------------------------------------------------
    // States (one-hot: each state lights a distinct LED)
    // -------------------------------------------------------------------------
    typedef enum logic [8:0] {
        INITIAL    = 9'b0_0000_0001,  // idle: waits for WRITE_IM or SEND_INFO
        WRITE_IM   = 9'b0_0000_0010,  // receiving and writing the program
        READY      = 9'b0_0000_0100,  // program loaded: waits for CONTINUE / STEP_BY_STEP
        RUN        = 9'b0_0000_1000,  // continuous run until HALT
        STEP_MODE  = 9'b0_0001_0000,  // step-by-step: waits for STEP / CONTINUE
        SEND_PC    = 9'b0_0010_0000,  // transmitting the PC
        SEND_REG   = 9'b0_0100_0000,  // transmitting the register file
        SEND_MEM   = 9'b0_1000_0000,  // transmitting data memory
        SEND_LATCH = 9'b1_0000_0000   // transmitting the pipeline latches
    } state_t;

    // -------------------------------------------------------------------------
    // State registers
    // -------------------------------------------------------------------------
    state_t r_state, w_next_state;
    state_t r_prev, w_next_prev;  // state to return to after the dump

    // IM load
    logic [NB_IADDR-1:0] r_word_count, w_next_word_count;  // current word
    logic [1:0] r_byte_in_word, w_next_byte_in_word;
    logic [NB_INST-1:0] r_im_acc, w_next_im_acc;  // 4-byte accumulator
    logic r_mem_wr, w_next_mem_wr;
    logic [NB_IADDR-1:0] r_im_addr, w_next_im_addr;
    logic [NB_INST-1:0] r_im_data, w_next_im_data;

    // Dump
    logic [2:0] r_byte_idx, w_next_byte_idx;  // byte within the value
    logic [NB_REG-1:0] r_reg_idx, w_next_reg_idx;  // current register (0..31)
    logic [NB_DADDR-1:0] r_mem_idx, w_next_mem_idx;  // current word (0..63)
    logic [NB_LADDR-1:0] r_latch_idx, w_next_latch_idx;  // current latch field (0..LATCH_COUNT-1)

    // UART / control
    logic r_tx_start, w_next_tx_start;
    logic [NB_DATA-1:0] r_tx_data, w_next_tx_data;
    logic r_pipeline_enable, w_next_pipeline_enable;

    // -------------------------------------------------------------------------
    // MSB-first byte selection from a DATA_WIDTH-bit value
    //   idx=0 -> most significant byte ... idx=NB_BYTES-1 -> least significant.
    // -------------------------------------------------------------------------
    function automatic logic [NB_DATA-1:0] msb_byte(input logic [DATA_WIDTH-1:0] val,
                                                    input logic [2:0] idx);
        msb_byte = val[(NB_BYTES-1-idx)*8+:8];
    endfunction

    // -------------------------------------------------------------------------
    // Sequential block (falling edge, synchronous active-high reset)
    // -------------------------------------------------------------------------
    always_ff @(negedge i_clk) begin
        if (i_reset) begin
            r_state           <= INITIAL;
            r_prev            <= INITIAL;
            r_word_count      <= '0;
            r_byte_in_word    <= '0;
            r_im_acc          <= '0;
            r_mem_wr          <= 1'b0;
            r_im_addr         <= '0;
            r_im_data         <= '0;
            r_byte_idx        <= '0;
            r_reg_idx         <= '0;
            r_mem_idx         <= '0;
            r_latch_idx       <= '0;
            r_tx_start        <= 1'b0;
            r_tx_data         <= '0;
            r_pipeline_enable <= 1'b0;
        end else begin
            r_state           <= w_next_state;
            r_prev            <= w_next_prev;
            r_word_count      <= w_next_word_count;
            r_byte_in_word    <= w_next_byte_in_word;
            r_im_acc          <= w_next_im_acc;
            r_mem_wr          <= w_next_mem_wr;
            r_im_addr         <= w_next_im_addr;
            r_im_data         <= w_next_im_data;
            r_byte_idx        <= w_next_byte_idx;
            r_reg_idx         <= w_next_reg_idx;
            r_mem_idx         <= w_next_mem_idx;
            r_latch_idx       <= w_next_latch_idx;
            r_tx_start        <= w_next_tx_start;
            r_tx_data         <= w_next_tx_data;
            r_pipeline_enable <= w_next_pipeline_enable;
        end
    end

    // -------------------------------------------------------------------------
    // Next-state combinational block
    // -------------------------------------------------------------------------
    always_comb begin
        // defaults: hold everything
        w_next_state           = r_state;
        w_next_prev            = r_prev;
        w_next_word_count      = r_word_count;
        w_next_byte_in_word    = r_byte_in_word;
        w_next_im_acc          = r_im_acc;
        w_next_mem_wr          = 1'b0;  // pulse: 0 by default
        w_next_im_addr         = r_im_addr;
        w_next_im_data         = r_im_data;
        w_next_byte_idx        = r_byte_idx;
        w_next_reg_idx         = r_reg_idx;
        w_next_mem_idx         = r_mem_idx;
        w_next_latch_idx       = r_latch_idx;
        w_next_tx_start        = r_tx_start;
        w_next_tx_data         = r_tx_data;
        w_next_pipeline_enable = r_pipeline_enable;

        case (r_state)
            // --- Idle ----------------------------------------------------
            INITIAL: begin
                w_next_pipeline_enable = 1'b0;
                if (i_rx_done) begin
                    case (i_rx_data)
                        CMD_WRITE_IM: begin
                            w_next_state        = WRITE_IM;
                            w_next_word_count   = '0;
                            w_next_byte_in_word = '0;
                            w_next_im_acc       = '0;
                        end
                        CMD_SEND_INFO: begin
                            w_next_state    = SEND_PC;
                            w_next_prev     = INITIAL;
                            w_next_byte_idx = '0;
                        end
                        default: ;
                    endcase
                end
            end

            // --- Program load --------------------------------------------
            WRITE_IM: begin
                w_next_pipeline_enable = 1'b0;
                if (i_rx_done) begin
                    // assemble MSB-first: the 1st byte ends up in [31:24]
                    w_next_im_acc = {r_im_acc[NB_INST-9:0], i_rx_data};
                    if (r_byte_in_word == 2'd3) begin
                        // 4th byte: write the full word into the IM
                        w_next_mem_wr       = 1'b1;
                        w_next_im_addr      = r_word_count;
                        w_next_im_data      = {r_im_acc[NB_INST-9:0], i_rx_data};
                        w_next_byte_in_word = 2'd0;
                        if (r_word_count == NB_IADDR'(IM_WORDS - 1)) begin
                            w_next_state      = READY;
                            w_next_word_count = '0;
                        end else begin
                            w_next_word_count = r_word_count + 1'b1;
                        end
                    end else begin
                        w_next_byte_in_word = r_byte_in_word + 1'b1;
                    end
                end
            end

            // --- Program loaded ------------------------------------------
            READY: begin
                w_next_pipeline_enable = 1'b0;
                if (i_rx_done) begin
                    case (i_rx_data)
                        CMD_CONTINUE:     w_next_state = RUN;
                        CMD_STEP_BY_STEP: w_next_state = STEP_MODE;
                        CMD_SEND_INFO: begin
                            w_next_state    = SEND_PC;
                            w_next_prev     = READY;
                            w_next_byte_idx = '0;
                        end
                        default:          ;
                    endcase
                end
            end

            // --- Continuous run ------------------------------------------
            RUN: begin
                w_next_pipeline_enable = 1'b1;  // core advances
                if (i_halt) begin
                    w_next_state           = SEND_PC;
                    w_next_prev            = READY;  // after the dump, back to ready
                    w_next_byte_idx        = '0;
                    w_next_pipeline_enable = 1'b0;
                end
            end

            // --- Step-by-step --------------------------------------------
            STEP_MODE: begin
                w_next_pipeline_enable = 1'b0;  // frozen between steps
                if (i_halt) begin
                    w_next_state    = SEND_PC;
                    w_next_prev     = READY;
                    w_next_byte_idx = '0;
                end else if (i_rx_done) begin
                    case (i_rx_data)
                        CMD_STEP: begin
                            // advance exactly one cycle: enable=1 now, and
                            // SEND_PC brings it back to 0 on the next edge
                            w_next_pipeline_enable = 1'b1;
                            w_next_state           = SEND_PC;
                            w_next_prev            = STEP_MODE;
                            w_next_byte_idx        = '0;
                        end
                        CMD_CONTINUE: w_next_state = RUN;
                        CMD_SEND_INFO: begin
                            w_next_state    = SEND_PC;
                            w_next_prev     = STEP_MODE;
                            w_next_byte_idx = '0;
                        end
                        default:      ;
                    endcase
                end
            end

            // --- Dump: PC (MSB-first) ------------------------------------
            SEND_PC: begin
                w_next_pipeline_enable = 1'b0;
                w_next_tx_start        = 1'b1;
                w_next_tx_data         = msb_byte(i_pc, r_byte_idx);
                if (i_tx_done) begin
                    w_next_tx_start = 1'b0;
                    if (r_byte_idx == 3'(NB_BYTES - 1)) begin
                        w_next_byte_idx = '0;
                        w_next_reg_idx  = '0;
                        w_next_state    = SEND_REG;
                    end else begin
                        w_next_byte_idx = r_byte_idx + 1'b1;
                    end
                end
            end

            // --- Dump: 32 registers --------------------------------------
            SEND_REG: begin
                w_next_pipeline_enable = 1'b0;
                w_next_tx_start        = 1'b1;
                w_next_tx_data         = msb_byte(i_reg_data, r_byte_idx);
                if (i_tx_done) begin
                    w_next_tx_start = 1'b0;
                    if (r_byte_idx == 3'(NB_BYTES - 1)) begin
                        w_next_byte_idx = '0;
                        if (r_reg_idx == NB_REG'(RB_DEPTH - 1)) begin
                            w_next_reg_idx = '0;
                            w_next_mem_idx = '0;
                            w_next_state   = SEND_MEM;
                        end else begin
                            w_next_reg_idx = r_reg_idx + 1'b1;
                        end
                    end else begin
                        w_next_byte_idx = r_byte_idx + 1'b1;
                    end
                end
            end

            // --- Dump: data memory ---------------------------------------
            SEND_MEM: begin
                w_next_pipeline_enable = 1'b0;
                w_next_tx_start        = 1'b1;
                w_next_tx_data         = msb_byte(i_mem_data, r_byte_idx);
                if (i_tx_done) begin
                    w_next_tx_start = 1'b0;
                    if (r_byte_idx == 3'(NB_BYTES - 1)) begin
                        w_next_byte_idx = '0;
                        if (r_mem_idx == NB_DADDR'(DM_DEPTH - 1)) begin
                            w_next_mem_idx   = '0;
                            w_next_latch_idx = '0;
                            w_next_state     = SEND_LATCH;  // continue with the latches
                        end else begin
                            w_next_mem_idx = r_mem_idx + 1'b1;
                        end
                    end else begin
                        w_next_byte_idx = r_byte_idx + 1'b1;
                    end
                end
            end

            // --- Dump: pipeline latches ----------------------------------
            SEND_LATCH: begin
                w_next_pipeline_enable = 1'b0;
                w_next_tx_start        = 1'b1;
                w_next_tx_data         = msb_byte(i_latch_data, r_byte_idx);
                if (i_tx_done) begin
                    w_next_tx_start = 1'b0;
                    if (r_byte_idx == 3'(NB_BYTES - 1)) begin
                        w_next_byte_idx = '0;
                        if (r_latch_idx == NB_LADDR'(LATCH_COUNT - 1)) begin
                            w_next_latch_idx = '0;
                            w_next_state     = r_prev;  // return to the previous state
                        end else begin
                            w_next_latch_idx = r_latch_idx + 1'b1;
                        end
                    end else begin
                        w_next_byte_idx = r_byte_idx + 1'b1;
                    end
                end
            end

            default: w_next_state = INITIAL;
        endcase
    end

    // -------------------------------------------------------------------------
    // Outputs
    // -------------------------------------------------------------------------
    assign o_tx_data         = r_tx_data;
    assign o_tx_start        = r_tx_start;
    assign o_imem_wr         = r_mem_wr;
    assign o_imem_addr       = r_im_addr;
    assign o_imem_data       = r_im_data;
    assign o_reg_addr        = r_reg_idx;
    assign o_mem_data_addr   = r_mem_idx;
    assign o_latch_addr      = r_latch_idx;
    assign o_pipeline_enable = r_pipeline_enable;
    // o_state is 8 LEDs; SEND_LATCH (bit 8) shares its indicator with SEND_MEM (bit 7).
    assign o_state           = r_state[8] ? 8'b1000_0000 : r_state[7:0];

endmodule
