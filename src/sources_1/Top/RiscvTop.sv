`timescale 1ns / 1ps

// =============================================================================
// RiscvTop  -  Synthesis top (SoC) for the Basys-3
// -----------------------------------------------------------------------------
// Integrates the RISC-V processor with its external interface:
//   - Uart       : 8N1 serial transceiver (program load / state dump)
//   - DebugUnit  : control FSM (load, continuous/step-by-step run, dump)
//   - RISCV      : the 5-stage core (IF/ID/EX/MEM/WB pipeline)
//
// This is the module synthesized and programmed onto the board (not the bare
// RISCV core).
//
// Pins (see src/constrs_1/new/basys3_riscv.xdc):
//   i_clk=W5 (100 MHz), i_reset=btn, i_rx=B18, o_tx=A18, o_led=FSM state.
//
// Clock:
//   The board input i_clk is 100 MHz; an MMCM divides it and the whole SoC runs
//   at the CLK parameter frequency. CLK must match the actual MMCM output so the
//   UART baud divisor stays correctly calibrated.
// =============================================================================
module RiscvTop #(
    parameter int CLK         = 75_000_000,  // SoC clock after the MMCM [Hz]
    parameter int BAUDRATE    = 19200,       // baud rate
    parameter int NB_PC       = 64,
    parameter int NB_INST     = 32,
    parameter int NB_REG      = 5,
    parameter int DATA_WIDTH  = 32,
    parameter int NB_IADDR    = 8,           // instruction memory: 256 words
    parameter int NB_DADDR    = 6,           // data memory: 64 words
    parameter int IM_WORDS    = 64,          // program size (must match the host GUI)
    parameter int DM_DEPTH    = 64,          // data memory words in the dump
    parameter int LATCH_COUNT = 25,          // pipeline latch fields in the dump
    parameter int NB_LADDR    = 5            // latch dump address width
) (
    input  logic       i_clk,
    input  logic       i_reset,
    input  logic       i_rx,
    output logic       o_tx,
    output logic [7:0] o_led     // DebugUnit one-hot state (visual debug)
);

    // -------------------------------------------------------------------------
    // Clock generation
    // -------------------------------------------------------------------------

    logic w_clk;
    logic w_locked;

    clk_wiz_0 u_clk_wiz (
        .clk_in1(i_clk),
        .clk_out1(w_clk),
        .locked(w_locked),
        .reset(i_reset)
    );

    // -------------------------------------------------------------------------
    // Reset bridge to the MMCM clock domain (assert async, deassert sync)
    // -------------------------------------------------------------------------
    // Holds reset asserted while the MMCM is unlocked (w_locked=0) or i_reset is
    // pressed, and releases it synchronously a couple of cycles after lock. Needed
    // because the submodules use *synchronous* reset: without this, reset would
    // deassert before the first stable edge after MMCM lock and the registers would
    // never initialize.
    logic       w_async_rst;
    logic [1:0] r_rst_sync;
    logic       w_rst;

    assign w_async_rst = i_reset | ~w_locked;

    always_ff @(posedge w_clk or posedge w_async_rst) begin
        if (w_async_rst) r_rst_sync <= 2'b11;
        else r_rst_sync <= {r_rst_sync[0], 1'b0};
    end
    assign w_rst = r_rst_sync[1];

    // -------------------------------------------------------------------------
    // UART <-> DebugUnit interconnect
    // -------------------------------------------------------------------------
    logic [           7:0] w_rx_data;
    logic                  w_rx_done;
    logic                  w_tx_done;
    logic [           7:0] w_tx_data;
    logic                  w_tx_start;

    // -------------------------------------------------------------------------
    // DebugUnit <-> RISCV core interconnect
    // -------------------------------------------------------------------------
    logic                  w_pipeline_enable;
    logic                  w_imem_wr;
    logic [  NB_IADDR-1:0] w_imem_addr;
    logic [   NB_INST-1:0] w_imem_data;
    logic [    NB_REG-1:0] w_dbg_reg_addr;
    logic [  NB_DADDR-1:0] w_dbg_mem_addr;
    logic [  NB_LADDR-1:0] w_dbg_latch_addr;
    logic [     NB_PC-1:0] w_pc;
    logic [DATA_WIDTH-1:0] w_dbg_reg_data;
    logic [DATA_WIDTH-1:0] w_dbg_mem_data;
    logic [DATA_WIDTH-1:0] w_dbg_latch_data;
    logic                  w_halt;

    // -------------------------------------------------------------------------
    // UART
    // -------------------------------------------------------------------------
    Uart #(
        .CLK     (CLK),
        .BAUDRATE(BAUDRATE),
        .NB_DATA (8)
    ) u_uart (
        .i_clk         (w_clk),
        .i_reset       (w_rst),
        .i_rx          (i_rx),
        .o_tx          (o_tx),
        .o_rx_data     (w_rx_data),
        .o_rx_done_tick(w_rx_done),
        .i_tx_data     (w_tx_data),
        .i_tx_start    (w_tx_start),
        .o_tx_done_tick(w_tx_done)
    );

    // -------------------------------------------------------------------------
    // Debug Unit
    // -------------------------------------------------------------------------
    DebugUnit #(
        .NB_DATA    (8),
        .NB_PC      (NB_PC),
        .DATA_WIDTH (DATA_WIDTH),
        .NB_REG     (NB_REG),
        .NB_IADDR   (NB_IADDR),
        .NB_INST    (NB_INST),
        .NB_DADDR   (NB_DADDR),
        .IM_WORDS   (IM_WORDS),
        .RB_DEPTH   (2 ** NB_REG),
        .DM_DEPTH   (DM_DEPTH),
        .LATCH_COUNT(LATCH_COUNT),
        .NB_LADDR   (NB_LADDR)
    ) u_debug (
        .i_clk            (w_clk),
        .i_reset          (w_rst),
        .i_halt           (w_halt),
        .i_pc             (w_pc),
        .i_reg_data       (w_dbg_reg_data),
        .i_mem_data       (w_dbg_mem_data),
        .i_latch_data     (w_dbg_latch_data),
        .i_rx_done        (w_rx_done),
        .i_tx_done        (w_tx_done),
        .i_rx_data        (w_rx_data),
        .o_tx_data        (w_tx_data),
        .o_tx_start       (w_tx_start),
        .o_imem_wr        (w_imem_wr),
        .o_imem_addr      (w_imem_addr),
        .o_imem_data      (w_imem_data),
        .o_reg_addr       (w_dbg_reg_addr),
        .o_mem_data_addr  (w_dbg_mem_addr),
        .o_latch_addr     (w_dbg_latch_addr),
        .o_pipeline_enable(w_pipeline_enable),
        .o_state          (o_led)
    );

    // -------------------------------------------------------------------------
    // RISC-V core
    // -------------------------------------------------------------------------
    RISCV #(
        .NB_PC     (NB_PC),
        .NB_INST   (NB_INST),
        .NB_REG    (NB_REG),
        .DATA_WIDTH(DATA_WIDTH),
        .NB_ADDR   (NB_IADDR),
        .NB_LADDR  (NB_LADDR)
    ) u_core (
        .i_clk           (w_clk),
        .i_reset         (w_rst),
        .i_if_enable     (w_pipeline_enable),
        .i_imem_wr       (w_imem_wr),
        .i_imem_addr     (w_imem_addr),
        .i_imem_data     (w_imem_data),
        .o_PC            (w_pc),
        .o_halt          (w_halt),
        .i_dbg_reg_addr  (w_dbg_reg_addr),
        .o_dbg_reg_data  (w_dbg_reg_data),
        .i_dbg_mem_addr  (w_dbg_mem_addr),
        .o_dbg_mem_data  (w_dbg_mem_data),
        .i_dbg_latch_addr(w_dbg_latch_addr),
        .o_dbg_latch_data(w_dbg_latch_data)
    );

endmodule
