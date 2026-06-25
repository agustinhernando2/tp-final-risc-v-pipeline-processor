`timescale 1ns / 1ps

// =============================================================================
// tb_DebugUnit — testbench de la FSM de la DebugUnit (Stage 9b)
// -----------------------------------------------------------------------------
// Prueba el protocolo de la DebugUnit sin temporización real de UART: inyecta
// directamente i_rx_done/i_rx_data (comandos + bytes de programa) y simula el
// transmisor pulsando i_tx_done. Los puertos del procesador (i_pc, i_reg_data,
// i_mem_data) se modelan con stubs deterministas para verificar el dump.
//
//   Test 1: WRITE_IM ensambla 4 bytes MSB-first en cada word y los escribe en
//           orden (addr 0,1) con el valor correcto.
//   Test 2: SEND_INFO vuelca PC (8B) + 2 registros (8B c/u) + 2 words de mem
//           (8B c/u) en orden MSB-first, con las direcciones correctas.
//   Test 3: i_halt desde RUN dispara el dump.
// =============================================================================
module tb_DebugUnit;

    localparam int IM_WORDS = 2;
    localparam int RB_DEPTH = 2;
    localparam int DM_DEPTH = 2;
    localparam int DUMP_LEN = 8 + RB_DEPTH * 8 + DM_DEPTH * 8;  // 40

    logic        clk = 0;
    logic        reset;
    logic        halt;
    logic [63:0] pc;
    logic [63:0] reg_data;
    logic [63:0] mem_data;
    logic        rx_done;
    logic        tx_done;
    logic [ 7:0] rx_data;

    logic [ 7:0] tx_data;
    logic        tx_start;
    logic        mem_wr;
    logic [ 7:0] mem_addr;
    logic [31:0] mem_data_w;
    logic [ 4:0] reg_addr;
    logic [ 5:0] mem_data_addr;
    logic        pipeline_enable;
    logic [ 7:0] state;

    int          pass_count = 0;
    int          fail_count = 0;

    // --- Stubs deterministas del "procesador" --------------------------------
    function automatic logic [63:0] reg_stub(input int a);
        return 64'hA0A1_A2A3_A4A5_0000 + a;
    endfunction
    function automatic logic [63:0] mem_stub(input int a);
        return 64'hB0B1_B2B3_B4B5_0000 + a;
    endfunction
    localparam logic [63:0] PC_VAL = 64'h1122_3344_5566_7788;

    assign pc       = PC_VAL;
    assign reg_data = reg_stub(reg_addr);
    assign mem_data = mem_stub(mem_data_addr);

    // --- DUT -----------------------------------------------------------------
    DebugUnit #(
        .NB_DATA   (8),
        .NB_PC     (64),
        .DATA_WIDTH(64),
        .NB_REG    (5),
        .NB_IADDR  (8),
        .NB_INST   (32),
        .NB_DADDR  (6),
        .IM_WORDS  (IM_WORDS),
        .RB_DEPTH  (RB_DEPTH),
        .DM_DEPTH  (DM_DEPTH)
    ) DUT (
        .i_clk            (clk),
        .i_reset          (reset),
        .i_halt           (halt),
        .i_pc             (pc),
        .i_reg_data       (reg_data),
        .i_mem_data       (mem_data),
        .i_rx_done        (rx_done),
        .i_tx_done        (tx_done),
        .i_rx_data        (rx_data),
        .o_tx_data        (tx_data),
        .o_tx_start       (tx_start),
        .o_mem_wr         (mem_wr),
        .o_mem_addr       (mem_addr),
        .o_mem_data       (mem_data_w),
        .o_reg_addr       (reg_addr),
        .o_mem_data_addr  (mem_data_addr),
        .o_pipeline_enable(pipeline_enable),
        .o_state          (state)
    );

    always #5 clk = ~clk;  // 100 MHz

    // --- Captura de escrituras a la memoria de instrucciones -----------------
    logic [ 7:0] im_w_addr[0:255];
    logic [31:0] im_w_data[0:255];
    int          im_n = 0;
    always @(posedge clk) begin
        if (!reset && mem_wr) begin
            im_w_addr[im_n] = mem_addr;
            im_w_data[im_n] = mem_data_w;
            im_n            = im_n + 1;
        end
    end

    // --- Drivers de protocolo ------------------------------------------------
    // Entrega un byte por "RX": el pulso abarca un flanco descendente (donde la
    // FSM lo muestrea), igual que un rx_done real de un ciclo.
    task automatic rx_byte(input logic [7:0] b);
        @(posedge clk);
        rx_data = b;
        rx_done = 1'b1;
        @(posedge clk);
        rx_done = 1'b0;
    endtask

    // Recoge un byte del dump: espera tx_start, lo lee, pulsa tx_done y espera
    // a que tx_start baje (la FSM avanza al siguiente byte).
    task automatic tx_get(output logic [7:0] b);
        do @(posedge clk); while (!tx_start);  // espera a que se presente un byte
        b       = tx_data;
        tx_done = 1'b1;
        @(posedge clk);  // la FSM consume tx_done y avanza
        tx_done = 1'b0;
    endtask

    // --- Helpers de chequeo --------------------------------------------------
    task automatic check32(input string name, input logic [31:0] got, input logic [31:0] exp);
        if (got !== exp) begin
            $display("FAIL [%s] got=%08h exp=%08h", name, got, exp);
            fail_count++;
        end else begin
            $display("PASS [%s] = %08h", name, got);
            pass_count++;
        end
    endtask

    task automatic check8(input string name, input logic [7:0] got, input logic [7:0] exp);
        if (got !== exp) begin
            $display("FAIL [%s] got=%02h exp=%02h", name, got, exp);
            fail_count++;
        end else begin
            pass_count++;
        end
    endtask

    // --- Secuencia principal -------------------------------------------------
    logic [7:0] dump[0:DUMP_LEN-1];
    logic [7:0] exp_byte;
    int idx;

    initial begin
        reset   = 1'b1;
        halt    = 1'b0;
        rx_done = 1'b0;
        tx_done = 1'b0;
        rx_data = 8'h00;
        repeat (3) @(posedge clk);
        reset = 1'b0;
        @(posedge clk);

        // ---------------- Test 1: carga de programa ----------------
        // word0 = DE AD BE EF (MSB-first), word1 = 00 00 00 0B (HALT)
        rx_byte(8'h01);  // CMD_WRITE_IM
        rx_byte(8'hDE);
        rx_byte(8'hAD);
        rx_byte(8'hBE);
        rx_byte(8'hEF);
        rx_byte(8'h00);
        rx_byte(8'h00);
        rx_byte(8'h00);
        rx_byte(8'h0B);
        repeat (4) @(posedge clk);

        check32("IM addr0 data", (im_n > 0) ? im_w_data[0] : 32'hX, 32'hDEAD_BEEF);
        check8("IM addr0 idx", (im_n > 0) ? im_w_addr[0] : 8'hX, 8'h00);
        check32("IM addr1 data", (im_n > 1) ? im_w_data[1] : 32'hX, 32'h0000_000B);
        check8("IM addr1 idx", (im_n > 1) ? im_w_addr[1] : 8'hX, 8'h01);
        if (im_n !== IM_WORDS) begin
            $display("FAIL [IM write count] got=%0d exp=%0d", im_n, IM_WORDS);
            fail_count++;
        end else pass_count++;

        // tras cargar IM_WORDS, la FSM debe estar en READY (one-hot 8'b100)
        #1;
        if (state !== 8'b0000_0100) begin
            $display("FAIL [state READY] got=%08b", state);
            fail_count++;
        end else pass_count++;

        // ---------------- Test 2: dump por SEND_INFO ----------------
        rx_byte(8'h04);  // CMD_SEND_INFO
        for (idx = 0; idx < DUMP_LEN; idx++) tx_get(dump[idx]);

        // PC (8 bytes, MSB-first)
        for (idx = 0; idx < 8; idx++) begin
            exp_byte = PC_VAL[(7-idx)*8+:8];
            check8($sformatf("dump PC byte %0d", idx), dump[idx], exp_byte);
        end
        // Registros
        for (int j = 0; j < RB_DEPTH; j++)
        for (int k = 0; k < 8; k++) begin
            exp_byte = reg_stub(j) >> ((7 - k) * 8);
            check8($sformatf("dump REG%0d byte %0d", j, k), dump[8+j*8+k], exp_byte);
        end
        // Memoria de datos
        for (int j = 0; j < DM_DEPTH; j++)
        for (int k = 0; k < 8; k++) begin
            exp_byte = mem_stub(j) >> ((7 - k) * 8);
            check8($sformatf("dump MEM%0d byte %0d", j, k), dump[8+RB_DEPTH*8+j*8+k], exp_byte);
        end

        // ---------------- Test 3: HALT desde RUN dispara dump ----------------
        rx_byte(8'h02);  // CMD_CONTINUE -> RUN
        repeat (2) @(posedge clk);
        #1;
        if (pipeline_enable !== 1'b1) begin
            $display("FAIL [RUN enables pipeline] got=%b", pipeline_enable);
            fail_count++;
        end else pass_count++;

        halt = 1'b1;  // el core señala HALT
        repeat (2) @(posedge clk);
        halt = 1'b0;
        // ahora debe estar volcando: pipeline congelado y empezando por SEND_PC
        for (idx = 0; idx < DUMP_LEN; idx++) tx_get(dump[idx]);
        check8("halt dump PC byte0", dump[0], PC_VAL[63:56]);
        #1;
        if (pipeline_enable !== 1'b0) begin
            $display("FAIL [frozen after halt dump] got=%b", pipeline_enable);
            fail_count++;
        end else pass_count++;

        // ---------------- Resumen ----------------
        $display("----------------------------------------");
        $display("pass=%0d fail=%0d", pass_count, fail_count);
        if (fail_count == 0) $display("ALL TESTS PASSED");
        else $display("SOME TESTS FAILED");
        $finish;
    end

    // Watchdog
    initial begin
        #2_000_000;
        $display("FAIL [timeout] watchdog tripped");
        $display("SOME TESTS FAILED");
        $finish;
    end

endmodule
