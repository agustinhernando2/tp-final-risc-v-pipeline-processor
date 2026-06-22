`timescale 1ns / 1ps

// BUG-001 (RESUELTO): regresion de LUI.
//
// Fix: ControlUnit asigna ALUOp=00 (ADD forzado) + o_LUI=1 para LUI, y
// ExecuteStage usa o_LUI para forzar el operando A a 0. Asi la ALU calcula
// 0 + imm = imm para cualquier valor de imm[14:12], sin depender de los bits
// que en U-type no son un funct3 real.
//
// Este testbench ejercita ExecuteStage con i_LUI=1 y verifica que el
// resultado de la ALU sea siempre el inmediato, incluyendo los casos que
// antes fallaban (imm[14:12] != 000) y el caso donde operand_a (basura) != 0.

module tb_lui_bug;

    localparam DATA_WIDTH = 32;
    localparam NB_PC = 32;
    localparam NB_REG = 5;
    localparam ALU_CTRL_WIDTH = 4;

    // ExecuteStage inputs
    logic [DATA_WIDTH-1:0] read_data_1;
    logic [DATA_WIDTH-1:0] read_data_2;
    logic [DATA_WIDTH-1:0] immediate;
    logic [     NB_PC-1:0] pc;
    logic [     NB_PC-1:0] pc_plus_4;
    logic [    NB_REG-1:0] rd;
    logic [           2:0] funct3;
    logic                  funct7_5;
    logic                  ALUSrc;
    logic [           1:0] ALUOp;
    logic                  LUI;
    logic [           1:0] ForwardA;
    logic [           1:0] ForwardB;
    logic [DATA_WIDTH-1:0] ex_mem_alu_result;
    logic [DATA_WIDTH-1:0] wb_write_data;

    // ExecuteStage outputs
    logic [DATA_WIDTH-1:0] alu_result;
    logic                  zero;
    logic [DATA_WIDTH-1:0] o_read_data_2;
    logic [    NB_REG-1:0] o_rd;
    logic [     NB_PC-1:0] branch_target;
    logic [     NB_PC-1:0] o_pc_plus_4;

    int                    pass_count;
    int                    fail_count;

    ExecuteStage #(
        .DATA_WIDTH    (DATA_WIDTH),
        .NB_PC         (NB_PC),
        .NB_REG        (NB_REG),
        .ALU_CTRL_WIDTH(ALU_CTRL_WIDTH)
    ) DUT (
        .i_read_data_1      (read_data_1),
        .i_read_data_2      (read_data_2),
        .i_immediate        (immediate),
        .i_pc               (pc),
        .i_pc_plus_4        (pc_plus_4),
        .i_rd               (rd),
        .i_funct3           (funct3),
        .i_funct7_5         (funct7_5),
        .i_ALUSrc           (ALUSrc),
        .i_ALUOp            (ALUOp),
        .i_LUI              (LUI),
        .i_ForwardA         (ForwardA),
        .i_ForwardB         (ForwardB),
        .i_ex_mem_alu_result(ex_mem_alu_result),
        .i_wb_write_data    (wb_write_data),
        .o_alu_result       (alu_result),
        .o_zero             (zero),
        .o_read_data_2      (o_read_data_2),
        .o_rd               (o_rd),
        .o_branch_target    (branch_target),
        .o_pc_plus_4        (o_pc_plus_4)
    );

    task automatic check(input string label, input logic [DATA_WIDTH-1:0] got, expected);
        if (got === expected) begin
            $display("  PASS  %s: 0x%08h", label, got);
            pass_count++;
        end else begin
            $display("  FAIL  %s: expected 0x%08h, got 0x%08h", label, expected, got);
            fail_count++;
        end
    endtask

    // Ejecuta una instruccion LUI rd, imm: setea las señales fijas de LUI,
    // un operando A basura (que debe ignorarse) y comprueba alu_result == imm.
    task automatic run_lui(input string label, input logic [DATA_WIDTH-1:0] imm,
                           input logic [2:0] f3, input logic [DATA_WIDTH-1:0] garbage);
        ALUSrc      = 1'b1;
        ALUOp       = 2'b00;
        LUI         = 1'b1;
        ForwardA    = 2'b00;
        ForwardB    = 2'b00;
        funct3      = f3;  // en U-type estos son imm[14:12], la ALU debe ignorarlos
        funct7_5    = imm[18];  // imm[30] del valor original; irrelevante para el fix
        immediate   = imm;
        read_data_1 = garbage;  // rs1 basura: ExecuteStage debe forzarlo a 0
        #1;
        check(label, alu_result, imm);
    endtask

    initial begin
        pass_count        = 0;
        fail_count        = 0;
        read_data_2       = '0;
        pc                = '0;
        pc_plus_4         = '0;
        rd                = 5'd5;
        ex_mem_alu_result = '0;
        wb_write_data     = '0;

        $display("--- BUG-001 regresion: LUI produce {imm[31:12], 12'b0} para cualquier imm ---");

        // lui x5, 0x12345 -> imm[14:12]=101 (antes elegia SRLI). Ahora correcto.
        run_lui("lui x5,0x12345", 32'h1234_5000, 3'b101, 32'hDEAD_BEEF);

        // lui x1, 0x00001 -> imm[14:12]=001 (antes SLLI). Ahora correcto.
        run_lui("lui x1,0x00001", 32'h0000_1000, 3'b001, 32'hCAFE_BABE);

        // lui x5, 0x00100 -> imm[14:12]=000 (ADD) pero operand_a basura != 0.
        // Antes daba imm + basura; ahora operand_a se fuerza a 0.
        run_lui("lui x5,0x00100", 32'h0010_0000, 3'b000, 32'h0000_0005);

        // Cobertura de los 8 valores posibles de imm[14:12].
        run_lui("lui imm[14:12]=010", 32'hABCD_2000, 3'b010, 32'h1111_1111);
        run_lui("lui imm[14:12]=011", 32'h5555_3000, 3'b011, 32'h2222_2222);
        run_lui("lui imm[14:12]=100", 32'h0F0F_4000, 3'b100, 32'h3333_3333);
        run_lui("lui imm[14:12]=110", 32'h8000_6000, 3'b110, 32'h4444_4444);
        run_lui("lui imm[14:12]=111", 32'hFFFF_F000, 3'b111, 32'h5555_5555);

        $display("\n--- Results: %0d passed, %0d failed ---", pass_count, fail_count);
        if (fail_count == 0) $display("ALL TESTS PASSED");
        else $display("SOME TESTS FAILED");

        $finish;
    end

endmodule
