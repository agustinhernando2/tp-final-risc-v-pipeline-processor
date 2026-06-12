`timescale 1ns / 1ps

// BUG-001: LUI usa ALUOp=2'b11 (modo I-type), por lo que ALUControl
// decodifica inst[14:12] = imm[14:12] como funct3 y elige una operacion
// ALU arbitraria segun el valor del inmediato.
// Solo cuando imm[14:12]=000 se elige ADD, y aun asi el operando A es un
// registro indexado por imm[19:15] (no necesariamente cero).
//
// Este testbench verifica dos cosas:
//   1. Que ALUControl selecciona ADD (unica operacion correcta para LUI)
//      solo cuando funct3 = 000, y falla para cualquier otro imm[14:12].
//   2. Que la ALU produce el resultado incorrecto en casos concretos.

module tb_lui_bug;

    localparam DATA_WIDTH = 32;
    localparam ALU_CTRL_WIDTH = 4;

    localparam ADD = 4'b0000;

    logic [               1:0] alu_op;
    logic [               2:0] funct3;
    logic                      funct7_5;
    logic [ALU_CTRL_WIDTH-1:0] alu_ctrl;

    logic [    DATA_WIDTH-1:0] operand_a;
    logic [    DATA_WIDTH-1:0] operand_b;
    logic [    DATA_WIDTH-1:0] alu_result;
    logic                      alu_zero;

    int                        pass_count;
    int                        fail_count;

    ALUControl #(
        .ALU_CTRL_WIDTH(ALU_CTRL_WIDTH)
    ) DUT_CTRL (
        .i_ALUOp   (alu_op),
        .i_funct3  (funct3),
        .i_funct7_5(funct7_5),
        .o_ALUCtrl (alu_ctrl)
    );

    ALU #(
        .DATA_WIDTH    (DATA_WIDTH),
        .ALU_CTRL_WIDTH(ALU_CTRL_WIDTH)
    ) DUT_ALU (
        .i_operand_a(operand_a),
        .i_operand_b(operand_b),
        .i_ALUCtrl  (alu_ctrl),
        .o_result   (alu_result),
        .o_zero     (alu_zero)
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

    // LUI necesita siempre ADD (4'b0000). Falla si ALUControl elige otra cosa.
    task automatic check_alu_ctrl(input string label);
        if (alu_ctrl === ADD) begin
            $display("  PASS  ALUCtrl [%s] = ADD (0000) -- correcto para LUI", label);
            pass_count++;
        end else begin
            $display(
                "  FAIL  ALUCtrl [%s]: esperado ADD (0000), obtenido %04b -- LUI producira resultado incorrecto",
                label, alu_ctrl);
            fail_count++;
        end
    endtask

    initial begin
        pass_count = 0;
        fail_count = 0;
        operand_a  = '0;
        operand_b  = '0;
        alu_op     = 2'b11;  // ControlUnit asigna ALUOp=11 a LUI
        funct7_5   = 1'b0;

        // ----------------------------------------------------------------
        // Grupo 1: ALUControl con cada valor posible de imm[14:12]
        // Para LUI, inst[14:12] = imm[14:12], no un funct3 real.
        // Solo 3'b000 produce ADD; todo lo demas es incorrecto.
        // ----------------------------------------------------------------
        $display("--- Grupo 1: ALUControl con imm[14:12] como funct3 (ALUOp=11) ---");

        funct3 = 3'b000;
        #1;
        check_alu_ctrl("imm[14:12]=000");  // ADD -- unico caso que da ADD

        funct3 = 3'b001;
        #1;
        check_alu_ctrl("imm[14:12]=001");  // SLLI

        funct3 = 3'b010;
        #1;
        check_alu_ctrl("imm[14:12]=010");  // SLTI

        funct3 = 3'b011;
        #1;
        check_alu_ctrl("imm[14:12]=011");  // SLTIU

        funct3 = 3'b100;
        #1;
        check_alu_ctrl("imm[14:12]=100");  // XORI

        funct3 = 3'b101;
        #1;
        check_alu_ctrl("imm[14:12]=101");  // SRLI

        funct3 = 3'b110;
        #1;
        check_alu_ctrl("imm[14:12]=110");  // ORI

        funct3 = 3'b111;
        #1;
        check_alu_ctrl("imm[14:12]=111");  // ANDI

        // ----------------------------------------------------------------
        // Grupo 2: resultado concreto de `lui x5, 0x12345`
        //
        // imm = 0x12345 -> imm[14:12] = 3'b101, imm[30] = 0
        // ALUControl: ALUOp=11, funct3=101, funct7_5=0 -> SRLI (4'b0110)
        // operand_b = ImmediateExtend({0x12345, 12'b0}) = 0x12345000
        // operand_b[4:0] = 0 -> SRLI shifts by 0 -> result = operand_a
        // Esperado: 0x12345000   Real: operand_a (basura)
        // ----------------------------------------------------------------
        $display("--- Grupo 2: resultado de lui x5, 0x12345 (imm[14:12]=101 -> SRLI) ---");
        funct3    = 3'b101;
        funct7_5  = 1'b0;
        operand_a = 32'hDEAD_BEEF;  // valor basura del register file
        operand_b = 32'h1234_5000;  // inmediato correcto de LUI
        #1;
        check("lui x5,0x12345", alu_result, 32'h1234_5000);

        // ----------------------------------------------------------------
        // Grupo 3: resultado concreto de `lui x1, 0x00001`
        //
        // imm = 0x00001 -> imm[14:12] = 3'b001, imm[30] = 0
        // ALUControl: ALUOp=11, funct3=001, funct7_5=0 -> SLLI (4'b0010)
        // operand_b = 0x00001000, operand_b[4:0] = 0 -> shifts by 0
        // result = operand_a (basura), no el inmediato
        // ----------------------------------------------------------------
        $display("--- Grupo 3: resultado de lui x1, 0x00001 (imm[14:12]=001 -> SLLI) ---");
        funct3    = 3'b001;
        funct7_5  = 1'b0;
        operand_a = 32'hCAFE_BABE;
        operand_b = 32'h0000_1000;
        #1;
        check("lui x1,0x00001", alu_result, 32'h0000_1000);

        // ----------------------------------------------------------------
        // Grupo 4: caso donde imm[14:12]=000 (ADD) pero operand_a != 0
        // Demuestra que incluso ADD es incorrecto si rs1_garbage != 0.
        //
        // Ejemplo: lui x5, 0x00100  (imm[14:12] = 3'b000, imm=0x00100)
        // ADD: result = operand_a + operand_b = rs1_garbage + 0x00100000
        // Esperado: 0x00100000
        // ----------------------------------------------------------------
        $display("--- Grupo 4: lui x5, 0x00100 (imm[14:12]=000 -> ADD, pero operand_a != 0) ---");
        funct3    = 3'b000;
        funct7_5  = 1'b0;
        operand_a = 32'h0000_0005;  // rs1 basura != 0
        operand_b = 32'h0010_0000;  // 0x00100 << 12
        #1;
        check("lui x5,0x00100 con rs1_garbage=5", alu_result, 32'h0010_0000);

        // ----------------------------------------------------------------
        // Summary
        // ----------------------------------------------------------------
        $display("\n--- Results: %0d passed, %0d failed ---", pass_count, fail_count);
        if (fail_count == 0) $display("ALL TESTS PASSED");
        else $display("SOME TESTS FAILED");

        $finish;
    end

endmodule
