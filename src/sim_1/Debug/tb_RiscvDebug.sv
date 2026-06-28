`timescale 1ns / 1ps

// =============================================================================
// tb_RiscvDebug — integración DebugUnit + core RISCV (sin UART), Stage 9b
// -----------------------------------------------------------------------------
// Valida el camino completo carga -> ejecución continua -> HALT -> dump, que es
// lo que correrá en la placa, pero sin la temporización lenta de la UART: se
// inyectan los bytes por i_rx_done/i_rx_data y se simula el TX con i_tx_done.
//
// Programa de prueba (termina en HALT):
//   addi x1, x0, 5      ; x1 = 5
//   addi x2, x0, 3      ; x2 = 3
//   add  x3, x1, x2     ; x3 = 8   (forwarding resuelve la dependencia)
//   halt
//   (relleno con 0x00000000 hasta IM_WORDS)
//
// Se reconstruyen x1/x2/x3 desde el dump (MSB-first, 8 bytes por registro) y se
// verifican.
// =============================================================================
module tb_RiscvDebug;

    localparam int IM_WORDS = 8;
    localparam int RB_DEPTH = 8;  // volcamos x0..x7 (alcanza para x1,x2,x3)
    localparam int DM_DEPTH = 2;
    localparam int DUMP_LEN = 8 + RB_DEPTH * 8 + DM_DEPTH * 8;

    logic        clk = 0;
    logic        reset;

    // UART <-> DebugUnit (los maneja el testbench)
    logic [ 7:0] rx_data;
    logic        rx_done;
    logic        tx_done;
    logic [ 7:0] tx_data;
    logic        tx_start;

    // DebugUnit <-> core
    logic        pipeline_enable;
    logic        mem_wr;
    logic [ 7:0] mem_addr;
    logic [31:0] mem_data;
    logic [ 4:0] dbg_reg_addr;
    logic [ 5:0] dbg_mem_addr;
    logic [63:0] pc;
    logic [63:0] dbg_reg_data;
    logic [63:0] dbg_mem_data;
    logic        halt;
    logic [ 7:0] state;

    DebugUnit #(
        .NB_PC(64),
        .DATA_WIDTH(64),
        .NB_REG(5),
        .NB_IADDR(8),
        .NB_INST(32),
        .NB_DADDR(6),
        .IM_WORDS(IM_WORDS),
        .RB_DEPTH(RB_DEPTH),
        .DM_DEPTH(DM_DEPTH)
    ) u_debug (
        .i_clk(clk),
        .i_reset(reset),
        .i_halt(halt),
        .i_pc(pc),
        .i_reg_data(dbg_reg_data),
        .i_mem_data(dbg_mem_data),
        .i_rx_done(rx_done),
        .i_tx_done(tx_done),
        .i_rx_data(rx_data),
        .o_tx_data(tx_data),
        .o_tx_start(tx_start),
        .o_imem_wr(mem_wr),
        .o_imem_addr(mem_addr),
        .o_imem_data(mem_data),
        .o_reg_addr(dbg_reg_addr),
        .o_mem_data_addr(dbg_mem_addr),
        .o_pipeline_enable(pipeline_enable),
        .o_state(state)
    );

    RISCV #(
        .NB_PC(64),
        .NB_INST(32),
        .NB_REG(5),
        .DATA_WIDTH(64),
        .NB_ADDR(8)
    ) u_core (
        .i_clk(clk),
        .i_reset(reset),
        .i_if_enable(pipeline_enable),
        .i_imem_wr(mem_wr),
        .i_imem_addr(mem_addr),
        .i_imem_data(mem_data),
        .o_PC(pc),
        .o_halt(halt),
        .i_dbg_reg_addr(dbg_reg_addr),
        .o_dbg_reg_data(dbg_reg_data),
        .i_dbg_mem_addr(dbg_mem_addr),
        .o_dbg_mem_data(dbg_mem_data)
    );

    always #5 clk = ~clk;

    int pass_count = 0, fail_count = 0;
    logic [7:0] dump[0:DUMP_LEN-1];

    task automatic rx_byte(input logic [7:0] b);
        @(posedge clk);
        rx_data = b;
        rx_done = 1'b1;
        @(posedge clk);
        rx_done = 1'b0;
    endtask

    task automatic tx_get(output logic [7:0] b);
        do @(posedge clk); while (!tx_start);
        b = tx_data;
        tx_done = 1'b1;
        @(posedge clk);
        tx_done = 1'b0;
    endtask

    // envía una instrucción de 32 bits como 4 bytes MSB-first
    task automatic send_word(input logic [31:0] w);
        rx_byte(w[31:24]);
        rx_byte(w[23:16]);
        rx_byte(w[15:8]);
        rx_byte(w[7:0]);
    endtask

    function automatic logic [63:0] reg_from_dump(input int j);
        logic [63:0] v;
        v = '0;
        for (int k = 0; k < 8; k++) v = (v << 8) | dump[8+j*8+k];
        return v;
    endfunction

    task automatic check64(input string name, input logic [63:0] got, input logic [63:0] exp);
        if (got !== exp) begin
            $display("FAIL [%s] got=%016h exp=%016h", name, got, exp);
            fail_count++;
        end else begin
            $display("PASS [%s] = %0d", name, got);
            pass_count++;
        end
    endtask

    initial begin
        reset   = 1;
        rx_done = 0;
        tx_done = 0;
        rx_data = 0;
        repeat (3) @(posedge clk);
        reset = 0;
        @(posedge clk);

        // Cargar programa
        rx_byte(8'h01);  // CMD_WRITE_IM
        send_word(32'h0050_0093);  // addi x1,x0,5
        send_word(32'h0030_0113);  // addi x2,x0,3
        send_word(32'h0020_81B3);  // add  x3,x1,x2
        send_word(32'h0000_000B);  // halt
        send_word(32'h0000_0000);
        send_word(32'h0000_0000);
        send_word(32'h0000_0000);
        send_word(32'h0000_0000);

        // Ejecución continua: corre hasta HALT y vuelca
        rx_byte(8'h02);  // CMD_CONTINUE
        for (int i = 0; i < DUMP_LEN; i++) tx_get(dump[i]);

        check64("x1", reg_from_dump(1), 64'd5);
        check64("x2", reg_from_dump(2), 64'd3);
        check64("x3 = x1 + x2", reg_from_dump(3), 64'd8);
        check64("x0 hardwired 0", reg_from_dump(0), 64'd0);

        $display("----------------------------------------");
        $display("pass=%0d fail=%0d", pass_count, fail_count);
        if (fail_count == 0) $display("ALL TESTS PASSED");
        else $display("SOME TESTS FAILED");
        $finish;
    end

    initial begin
        #5_000_000;
        $display("FAIL [timeout]");
        $display("SOME TESTS FAILED");
        $finish;
    end

endmodule
