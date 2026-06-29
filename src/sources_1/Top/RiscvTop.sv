`timescale 1ns / 1ps

// =============================================================================
// RiscvTop  -  Top de síntesis (SoC) para la Basys-3
// -----------------------------------------------------------------------------
// Integra el procesador RISC-V con su interfaz externa:
//   - Uart       : transceptor serie 8N1 (carga de programa / dump de estado)
//   - DebugUnit  : FSM de control (carga, ejecución continua/paso a paso, dump)
//   - RISCV      : el core de 5 etapas (pipeline IF/ID/EX/MEM/WB)
//
// Es el equivalente RISC-V del TOP.v del proyecto MIPS de base. Este es el módulo
// que se sintetiza y se programa en la placa (no el core RISCV directamente).
//
// Pines (ver src/constrs_1/new/basys3_riscv.xdc):
//   i_clk=W5 (100 MHz), i_reset=btn, i_rx=B18, o_tx=A18, o_led=estado FSM.
//
// Reloj (Stage 11 - cierre de timing):
//   La entrada i_clk de la placa es de 100 MHz, pero el diseno no cierra timing a
//   esa frecuencia (los caminos de dump core->DebugUnit cruzan posedge->negedge y
//   solo tienen medio periodo de presupuesto; ver docs/report-20260628.md). Un MMCM
//   divide el reloj a 65 MHz y todo el SoC corre a 65 MHz, con lo que esos caminos
//   cierran con margen (WNS +0.319 ns). 65 MHz es el maximo confiable con el datapath
//   de 32 bits (DATA_WIDTH=32): el barrido docs/report-fmax-sweep-dw32-20260629.md
//   muestra que el timing aun aguanta ~75 MHz, pero a >=70 MHz la optimizacion por
//   timing replica registros, explota los control sets y satura el device (~99% de
//   slices), volviendo el placement irreproducible. A 65 MHz el diseno usa ~61% de
//   slices y 6% de control sets. El parametro CLK refleja 65 MHz para el divisor de
//   baudios de la UART (sigue ~19200, error <0.3%).
// =============================================================================
module RiscvTop #(
    parameter int CLK        = 65_000_000,  // reloj del SoC tras el MMCM [Hz]
    parameter int BAUDRATE   = 19200,       // tasa de baudios
    parameter int NB_PC      = 64,
    parameter int NB_INST    = 32,
    parameter int NB_REG     = 5,
    parameter int DATA_WIDTH = 32,
    parameter int NB_IADDR   = 8,           // memoria de instrucciones: 256 words
    parameter int NB_DADDR   = 6,           // memoria de datos: 64 words
    parameter int IM_WORDS   = 64,          // tamaño de programa (coincide con la GUI)
    parameter int DM_DEPTH   = 64           // words de mem de datos en el dump
) (
    input  logic       i_clk,
    input  logic       i_reset,
    input  logic       i_rx,
    output logic       o_tx,
    output logic [7:0] o_led     // estado one-hot de la DebugUnit (debug visual)
);

    // -------------------------------------------------------------------------
    // Generación de reloj: MMCM 100 MHz (W5) -> 65 MHz (w_clk)
    // -------------------------------------------------------------------------
    // Instanciamos el primitivo MMCME2_BASE directamente (no el IP Clock Wizard)
    // para que el flujo batch sin proyecto siga siendo autocontenido. El Clock
    // Wizard de la GUI genera exactamente este mismo hardware; ver plans/stage11.md.
    //   VCO = 100 MHz * CLKFBOUT_MULT_F / DIVCLK_DIVIDE = 100*6.5/1 = 650 MHz (en rango)
    //   w_clk = VCO / CLKOUT0_DIVIDE_F = 650/10 = 65 MHz
    logic w_clk;  // reloj de 65 MHz que alimenta todo el SoC
    logic w_clk_unbuf;  // salida CLKOUT0 del MMCM antes del BUFG
    logic w_fb;  // realimentación CLKFBOUT
    logic w_fb_buf;  // realimentación tras BUFG (CLKFBIN)
    logic w_locked;  // 1 cuando el MMCM enganchó

    MMCME2_BASE #(
        .CLKIN1_PERIOD     (10.000),  // 100 MHz de entrada
        .DIVCLK_DIVIDE     (1),
        .CLKFBOUT_MULT_F   (6.500),   // VCO = 650 MHz
        .CLKOUT0_DIVIDE_F  (10.000),  // 65 MHz
        .CLKOUT0_DUTY_CYCLE(0.5),
        .STARTUP_WAIT      ("FALSE")
    ) u_mmcm (
        .CLKIN1   (i_clk),
        .CLKFBIN  (w_fb_buf),
        .CLKFBOUT (w_fb),
        .CLKOUT0  (w_clk_unbuf),
        .CLKOUT0B (),
        .CLKOUT1  (),
        .CLKOUT1B (),
        .CLKOUT2  (),
        .CLKOUT2B (),
        .CLKOUT3  (),
        .CLKOUT3B (),
        .CLKOUT4  (),
        .CLKOUT5  (),
        .CLKOUT6  (),
        .CLKFBOUTB(),
        .LOCKED   (w_locked),
        .PWRDWN   (1'b0),
        .RST      (i_reset)
    );

    BUFG u_bufg_fb (
        .I(w_fb),
        .O(w_fb_buf)
    );
    BUFG u_bufg_clk (
        .I(w_clk_unbuf),
        .O(w_clk)
    );

    // -------------------------------------------------------------------------
    // Reset síncrono al dominio de 60 MHz (reset-bridge: assert async, deassert sync)
    // -------------------------------------------------------------------------
    // Mantiene el reset activo mientras el MMCM no enganchó (w_locked=0) o se pulsa
    // i_reset, y lo libera de forma síncrona un par de ciclos después del lock. Es
    // necesario porque los submódulos usan reset *síncrono*: sin esto, al engancharse
    // el MMCM el reset caería antes del primer flanco estable y los registros nunca
    // se inicializarían.
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
    // Interconexión UART <-> DebugUnit
    // -------------------------------------------------------------------------
    logic [           7:0] w_rx_data;
    logic                  w_rx_done;
    logic                  w_tx_done;
    logic [           7:0] w_tx_data;
    logic                  w_tx_start;

    // -------------------------------------------------------------------------
    // Interconexión DebugUnit <-> RISCV core
    // -------------------------------------------------------------------------
    logic                  w_pipeline_enable;
    logic                  w_imem_wr;
    logic [  NB_IADDR-1:0] w_imem_addr;
    logic [   NB_INST-1:0] w_imem_data;
    logic [    NB_REG-1:0] w_dbg_reg_addr;
    logic [  NB_DADDR-1:0] w_dbg_mem_addr;
    logic [     NB_PC-1:0] w_pc;
    logic [DATA_WIDTH-1:0] w_dbg_reg_data;
    logic [DATA_WIDTH-1:0] w_dbg_mem_data;
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
        .NB_DATA   (8),
        .NB_PC     (NB_PC),
        .DATA_WIDTH(DATA_WIDTH),
        .NB_REG    (NB_REG),
        .NB_IADDR  (NB_IADDR),
        .NB_INST   (NB_INST),
        .NB_DADDR  (NB_DADDR),
        .IM_WORDS  (IM_WORDS),
        .RB_DEPTH  (2 ** NB_REG),
        .DM_DEPTH  (DM_DEPTH)
    ) u_debug (
        .i_clk            (w_clk),
        .i_reset          (w_rst),
        .i_halt           (w_halt),
        .i_pc             (w_pc),
        .i_reg_data       (w_dbg_reg_data),
        .i_mem_data       (w_dbg_mem_data),
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
        .NB_ADDR   (NB_IADDR)
    ) u_core (
        .i_clk         (w_clk),
        .i_reset       (w_rst),
        .i_if_enable   (w_pipeline_enable),
        .i_imem_wr     (w_imem_wr),
        .i_imem_addr   (w_imem_addr),
        .i_imem_data   (w_imem_data),
        .o_PC          (w_pc),
        .o_halt        (w_halt),
        .i_dbg_reg_addr(w_dbg_reg_addr),
        .o_dbg_reg_data(w_dbg_reg_data),
        .i_dbg_mem_addr(w_dbg_mem_addr),
        .o_dbg_mem_data(w_dbg_mem_data)
    );

endmodule
