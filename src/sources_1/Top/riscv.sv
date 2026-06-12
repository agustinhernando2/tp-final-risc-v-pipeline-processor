`timescale 1ns / 1ps

module RISCV #(
    parameter NB_PC      = 64,
    parameter NB_INST    = 32,
    parameter NB_REG     = 5,
    parameter DATA_WIDTH = 64,
    parameter NB_ADDR    = 8
) (
    input  logic               i_clk,
    input  logic               i_reset,
    input  logic               i_rx,
    input  logic               i_if_enable,  // 0 = freeze IF/PC (used for program loading)
    // instruction memory load interface
    input  logic               i_mem_wr,
    input  logic [NB_ADDR-1:0] i_mem_addr,
    input  logic [NB_INST-1:0] i_mem_data,
    output logic               o_tx
);

    // ----------------------------------------------------------------
    // Hazard control signals
    // ----------------------------------------------------------------
    logic w_PCWrite;
    logic w_IF_ID_Write;
    logic w_ID_EX_flush;

    logic w_if_pc_enable;
    logic w_if_id_enable;
    assign w_if_pc_enable = i_if_enable & w_PCWrite;
    assign w_if_id_enable = i_if_enable & w_IF_ID_Write;

    // ----------------------------------------------------------------
    // Branch / Jump control (resolved in MEM stage)
    // ----------------------------------------------------------------
    logic w_PCSrc;
    logic [NB_PC-1:0] w_PCBranch;
    logic w_if_id_flush;

    // ----------------------------------------------------------------
    // IF stage
    // ----------------------------------------------------------------
    logic [NB_PC-1:0] w_if_pc_inc;
    logic [NB_INST-1:0] w_if_instruction;
    logic [NB_PC-1:0] w_if_pc;

    InstructionFetch #(
        .NB_PC  (NB_PC),
        .NB_INST(NB_INST),
        .NB_ADDR(NB_ADDR)
    ) IF (
        .i_clk         (i_clk),
        .i_reset       (i_reset),
        .i_enable      (w_if_pc_enable),
        .i_PCSrc       (w_PCSrc),
        .i_PCBranch    (w_PCBranch),
        .i_mem_wr      (i_mem_wr),
        .i_mem_addr    (i_mem_addr),
        .i_mem_data    (i_mem_data),
        .o_PC_increment(w_if_pc_inc),
        .o_instruction (w_if_instruction),
        .o_PC          (w_if_pc)
    );

    // ----------------------------------------------------------------
    // IF/ID buffer
    // ----------------------------------------------------------------
    logic [  NB_PC-1:0] w_if_id_pc;
    logic [  NB_PC-1:0] w_if_id_pc_plus_1;
    logic [NB_INST-1:0] w_if_id_instruction;

    IF_ID_Buffer #(
        .NB_PC  (NB_PC),
        .NB_INST(NB_INST)
    ) IF_ID (
        .i_clk        (i_clk),
        .i_reset      (i_reset),
        .i_enable     (w_if_id_enable),
        .i_flush      (w_if_id_flush),
        .i_PC         (w_if_pc),
        .i_pc_plus_1  (w_if_pc_inc),
        .i_instruction(w_if_instruction),
        .o_PC         (w_if_id_pc),
        .o_pc_plus_1  (w_if_id_pc_plus_1),
        .o_instruction(w_if_id_instruction)
    );

    // ----------------------------------------------------------------
    // ID stage
    // ----------------------------------------------------------------
    logic [DATA_WIDTH-1:0] w_id_read_data_1;
    logic [DATA_WIDTH-1:0] w_id_read_data_2;
    logic [    NB_REG-1:0] w_id_rd;
    logic [DATA_WIDTH-1:0] w_id_immediate;
    logic [           2:0] w_id_funct3;
    logic                  w_id_funct7_5;
    logic                  w_id_RegWrite;
    logic                  w_id_ALUSrc;
    logic [           1:0] w_id_ALUOp;
    logic                  w_id_MemRead;
    logic                  w_id_MemWrite;
    logic                  w_id_MemToReg;
    logic                  w_id_Branch;
    logic                  w_id_Jump;
    logic                  w_id_JumpReg;

    // WB feedback wires (declared forward; driven by WB stage below)
    logic [DATA_WIDTH-1:0] w_wb_write_data;
    logic [    NB_REG-1:0] w_wb_write_reg;
    logic                  w_wb_RegWrite;

    instructionDecode #(
        .NB_INST   (NB_INST),
        .NB_REG    (NB_REG),
        .DATA_WIDTH(DATA_WIDTH)
    ) ID (
        .i_clk        (i_clk),
        .i_reset      (i_reset),
        .i_instruction(w_if_id_instruction),
        .i_write_reg  (w_wb_write_reg),
        .i_write_data (w_wb_write_data),
        .i_regWrite   (w_wb_RegWrite),
        .o_read_data_1(w_id_read_data_1),
        .o_read_data_2(w_id_read_data_2),
        .o_rd         (w_id_rd),
        .o_immediate  (w_id_immediate),
        .o_funct3     (w_id_funct3),
        .o_funct7_5   (w_id_funct7_5),
        .o_RegWrite   (w_id_RegWrite),
        .o_ALUSrc     (w_id_ALUSrc),
        .o_ALUOp      (w_id_ALUOp),
        .o_MemRead    (w_id_MemRead),
        .o_MemWrite   (w_id_MemWrite),
        .o_MemToReg   (w_id_MemToReg),
        .o_Branch     (w_id_Branch),
        .o_Jump       (w_id_Jump),
        .o_JumpReg    (w_id_JumpReg)
    );

    // rs1/rs2 extracted from the IF/ID instruction for hazard detection and ID/EX buffering
    logic [NB_REG-1:0] w_id_rs1;
    logic [NB_REG-1:0] w_id_rs2;
    assign w_id_rs1 = w_if_id_instruction[19:15];
    assign w_id_rs2 = w_if_id_instruction[24:20];

    // ----------------------------------------------------------------
    // ID/EX buffer
    // ----------------------------------------------------------------
    logic [     NB_PC-1:0] w_id_ex_pc;
    logic [     NB_PC-1:0] w_id_ex_pc_plus_1;
    logic [DATA_WIDTH-1:0] w_id_ex_read_data_1;
    logic [DATA_WIDTH-1:0] w_id_ex_read_data_2;
    logic [DATA_WIDTH-1:0] w_id_ex_immediate;
    logic [    NB_REG-1:0] w_id_ex_rs1;
    logic [    NB_REG-1:0] w_id_ex_rs2;
    logic [    NB_REG-1:0] w_id_ex_rd;
    logic [           2:0] w_id_ex_funct3;
    logic                  w_id_ex_funct7_5;
    logic                  w_id_ex_ALUSrc;
    logic [           1:0] w_id_ex_ALUOp;
    logic                  w_id_ex_RegWrite;
    logic                  w_id_ex_MemRead;
    logic                  w_id_ex_MemWrite;
    logic                  w_id_ex_MemToReg;
    logic                  w_id_ex_Branch;
    logic                  w_id_ex_Jump;
    logic                  w_id_ex_JumpReg;

    ID_EX_Buffer #(
        .NB_PC     (NB_PC),
        .DATA_WIDTH(DATA_WIDTH),
        .NB_REG    (NB_REG)
    ) ID_EX (
        .i_clk        (i_clk),
        .i_reset      (i_reset),
        .i_enable     (1'b1),
        .i_flush      (w_ID_EX_flush | w_PCSrc),
        .i_PC         (w_if_id_pc),
        .i_pc_plus_1  (w_if_id_pc_plus_1),
        .i_read_data_1(w_id_read_data_1),
        .i_read_data_2(w_id_read_data_2),
        .i_immediate  (w_id_immediate),
        .i_rs1        (w_id_rs1),
        .i_rs2        (w_id_rs2),
        .i_rd         (w_id_rd),
        .i_funct3     (w_id_funct3),
        .i_funct7_5   (w_id_funct7_5),
        .i_ALUSrc     (w_id_ALUSrc),
        .i_ALUOp      (w_id_ALUOp),
        .i_RegWrite   (w_id_RegWrite),
        .i_MemRead    (w_id_MemRead),
        .i_MemWrite   (w_id_MemWrite),
        .i_MemToReg   (w_id_MemToReg),
        .i_Branch     (w_id_Branch),
        .i_Jump       (w_id_Jump),
        .i_JumpReg    (w_id_JumpReg),
        .o_PC         (w_id_ex_pc),
        .o_pc_plus_1  (w_id_ex_pc_plus_1),
        .o_read_data_1(w_id_ex_read_data_1),
        .o_read_data_2(w_id_ex_read_data_2),
        .o_immediate  (w_id_ex_immediate),
        .o_rs1        (w_id_ex_rs1),
        .o_rs2        (w_id_ex_rs2),
        .o_rd         (w_id_ex_rd),
        .o_funct3     (w_id_ex_funct3),
        .o_funct7_5   (w_id_ex_funct7_5),
        .o_ALUSrc     (w_id_ex_ALUSrc),
        .o_ALUOp      (w_id_ex_ALUOp),
        .o_RegWrite   (w_id_ex_RegWrite),
        .o_MemRead    (w_id_ex_MemRead),
        .o_MemWrite   (w_id_ex_MemWrite),
        .o_MemToReg   (w_id_ex_MemToReg),
        .o_Branch     (w_id_ex_Branch),
        .o_Jump       (w_id_ex_Jump),
        .o_JumpReg    (w_id_ex_JumpReg)
    );

    // ----------------------------------------------------------------
    // Hazard detection unit
    // ----------------------------------------------------------------
    HazardDetectionUnit #(
        .NB_REG(NB_REG)
    ) HDU (
        .i_id_ex_MemRead(w_id_ex_MemRead),
        .i_id_ex_rd     (w_id_ex_rd),
        .i_if_id_rs1    (w_id_rs1),
        .i_if_id_rs2    (w_id_rs2),
        .o_PCWrite      (w_PCWrite),
        .o_IF_ID_Write  (w_IF_ID_Write),
        .o_ID_EX_flush  (w_ID_EX_flush)
    );

    // ----------------------------------------------------------------
    // EX stage
    // ----------------------------------------------------------------
    logic [DATA_WIDTH-1:0] w_ex_alu_result;
    logic                  w_ex_zero;
    logic [DATA_WIDTH-1:0] w_ex_read_data_2;
    logic [    NB_REG-1:0] w_ex_rd;
    logic [     NB_PC-1:0] w_ex_branch_target;
    logic [     NB_PC-1:0] w_ex_pc_plus_1;

    logic [           1:0] w_ForwardA;
    logic [           1:0] w_ForwardB;

    // EX/MEM and MEM/WB outputs used in forwarding (declared forward)
    logic [DATA_WIDTH-1:0] w_ex_mem_alu_result;
    logic [    NB_REG-1:0] w_ex_mem_rd;
    logic                  w_ex_mem_RegWrite;
    logic [    NB_REG-1:0] w_mem_wb_rd;
    logic                  w_mem_wb_RegWrite;

    ForwardingUnit #(
        .NB_REG(NB_REG)
    ) FWD (
        .i_id_ex_rs1      (w_id_ex_rs1),
        .i_id_ex_rs2      (w_id_ex_rs2),
        .i_ex_mem_rd      (w_ex_mem_rd),
        .i_ex_mem_RegWrite(w_ex_mem_RegWrite),
        .i_mem_wb_rd      (w_mem_wb_rd),
        .i_mem_wb_RegWrite(w_mem_wb_RegWrite),
        .o_ForwardA       (w_ForwardA),
        .o_ForwardB       (w_ForwardB)
    );

    ExecuteStage #(
        .DATA_WIDTH    (DATA_WIDTH),
        .NB_PC         (NB_PC),
        .NB_REG        (NB_REG),
        .ALU_CTRL_WIDTH(4)
    ) EX (
        .i_read_data_1      (w_id_ex_read_data_1),
        .i_read_data_2      (w_id_ex_read_data_2),
        .i_immediate        (w_id_ex_immediate),
        .i_pc               (w_id_ex_pc),
        .i_pc_plus_1        (w_id_ex_pc_plus_1),
        .i_rd               (w_id_ex_rd),
        .i_funct3           (w_id_ex_funct3),
        .i_funct7_5         (w_id_ex_funct7_5),
        .i_ALUSrc           (w_id_ex_ALUSrc),
        .i_ALUOp            (w_id_ex_ALUOp),
        .i_ForwardA         (w_ForwardA),
        .i_ForwardB         (w_ForwardB),
        .i_ex_mem_alu_result(w_ex_mem_alu_result),
        .i_wb_write_data    (w_wb_write_data),
        .o_alu_result       (w_ex_alu_result),
        .o_zero             (w_ex_zero),
        .o_read_data_2      (w_ex_read_data_2),
        .o_rd               (w_ex_rd),
        .o_branch_target    (w_ex_branch_target),
        .o_pc_plus_1        (w_ex_pc_plus_1)
    );

    // ----------------------------------------------------------------
    // EX/MEM buffer
    // ----------------------------------------------------------------
    logic                  w_ex_mem_zero;
    logic [DATA_WIDTH-1:0] w_ex_mem_read_data_2;
    logic [           2:0] w_ex_mem_funct3;
    logic [     NB_PC-1:0] w_ex_mem_branch_target;
    logic [     NB_PC-1:0] w_ex_mem_pc_plus_1;
    logic                  w_ex_mem_MemRead;
    logic                  w_ex_mem_MemWrite;
    logic                  w_ex_mem_MemToReg;
    logic                  w_ex_mem_Branch;
    logic                  w_ex_mem_Jump;
    logic                  w_ex_mem_JumpReg;

    EX_MEM_Buffer #(
        .DATA_WIDTH(DATA_WIDTH),
        .NB_REG    (NB_REG),
        .NB_PC     (NB_PC)
    ) EX_MEM (
        .i_clk          (i_clk),
        .i_reset        (i_reset),
        .i_enable       (1'b1),
        .i_flush        (1'b0),
        .i_alu_result   (w_ex_alu_result),
        .i_zero         (w_ex_zero),
        .i_read_data_2  (w_ex_read_data_2),
        .i_rd           (w_ex_rd),
        .i_funct3       (w_id_ex_funct3),
        .i_branch_target(w_ex_branch_target),
        .i_pc_plus_1    (w_ex_pc_plus_1),
        .i_RegWrite     (w_id_ex_RegWrite),
        .i_MemRead      (w_id_ex_MemRead),
        .i_MemWrite     (w_id_ex_MemWrite),
        .i_MemToReg     (w_id_ex_MemToReg),
        .i_Branch       (w_id_ex_Branch),
        .i_Jump         (w_id_ex_Jump),
        .i_JumpReg      (w_id_ex_JumpReg),
        .o_alu_result   (w_ex_mem_alu_result),
        .o_zero         (w_ex_mem_zero),
        .o_read_data_2  (w_ex_mem_read_data_2),
        .o_rd           (w_ex_mem_rd),
        .o_funct3       (w_ex_mem_funct3),
        .o_branch_target(w_ex_mem_branch_target),
        .o_pc_plus_1    (w_ex_mem_pc_plus_1),
        .o_RegWrite     (w_ex_mem_RegWrite),
        .o_MemRead      (w_ex_mem_MemRead),
        .o_MemWrite     (w_ex_mem_MemWrite),
        .o_MemToReg     (w_ex_mem_MemToReg),
        .o_Branch       (w_ex_mem_Branch),
        .o_Jump         (w_ex_mem_Jump),
        .o_JumpReg      (w_ex_mem_JumpReg)
    );

    // ----------------------------------------------------------------
    // MEM stage
    // ----------------------------------------------------------------
    logic [DATA_WIDTH-1:0] w_mem_read_data;

    MemoryAccessStage #(
        .DATA_WIDTH(DATA_WIDTH),
        .NB_PC     (NB_PC),
        .NB_ADDR   (6)
    ) MEM (
        .i_clk          (i_clk),
        .i_reset        (i_reset),
        .i_alu_result   (w_ex_mem_alu_result),
        .i_zero         (w_ex_mem_zero),
        .i_read_data_2  (w_ex_mem_read_data_2),
        .i_funct3       (w_ex_mem_funct3),
        .i_branch_target(w_ex_mem_branch_target),
        .i_MemWrite     (w_ex_mem_MemWrite),
        .i_Branch       (w_ex_mem_Branch),
        .i_Jump         (w_ex_mem_Jump),
        .i_JumpReg      (w_ex_mem_JumpReg),
        .o_mem_read_data(w_mem_read_data),
        .o_PCSrc        (w_PCSrc),
        .o_PCBranch     (w_PCBranch)
    );

    // ----------------------------------------------------------------
    // MEM/WB buffer
    // ----------------------------------------------------------------
    logic [DATA_WIDTH-1:0] w_mem_wb_alu_result;
    logic [DATA_WIDTH-1:0] w_mem_wb_mem_read_data;
    logic [     NB_PC-1:0] w_mem_wb_pc_plus_1;
    logic                  w_mem_wb_MemToReg;
    logic                  w_mem_wb_Jump;

    MEM_WB_Buffer #(
        .DATA_WIDTH(DATA_WIDTH),
        .NB_REG    (NB_REG),
        .NB_PC     (NB_PC)
    ) MEM_WB (
        .i_clk          (i_clk),
        .i_reset        (i_reset),
        .i_enable       (1'b1),
        .i_alu_result   (w_ex_mem_alu_result),
        .i_mem_read_data(w_mem_read_data),
        .i_rd           (w_ex_mem_rd),
        .i_pc_plus_1    (w_ex_mem_pc_plus_1),
        .i_RegWrite     (w_ex_mem_RegWrite),
        .i_MemToReg     (w_ex_mem_MemToReg),
        .i_Jump         (w_ex_mem_Jump),
        .o_alu_result   (w_mem_wb_alu_result),
        .o_mem_read_data(w_mem_wb_mem_read_data),
        .o_rd           (w_mem_wb_rd),
        .o_pc_plus_1    (w_mem_wb_pc_plus_1),
        .o_RegWrite     (w_mem_wb_RegWrite),
        .o_MemToReg     (w_mem_wb_MemToReg),
        .o_Jump         (w_mem_wb_Jump)
    );

    // ----------------------------------------------------------------
    // WB stage (feeds back to ID)
    // ----------------------------------------------------------------
    WriteBackStage #(
        .DATA_WIDTH(DATA_WIDTH),
        .NB_REG    (NB_REG),
        .NB_PC     (NB_PC)
    ) WB (
        .i_alu_result   (w_mem_wb_alu_result),
        .i_mem_read_data(w_mem_wb_mem_read_data),
        .i_rd           (w_mem_wb_rd),
        .i_pc_plus_1    (w_mem_wb_pc_plus_1),
        .i_RegWrite     (w_mem_wb_RegWrite),
        .i_MemToReg     (w_mem_wb_MemToReg),
        .i_Jump         (w_mem_wb_Jump),
        .o_write_data   (w_wb_write_data),
        .o_write_reg    (w_wb_write_reg),
        .o_RegWrite     (w_wb_RegWrite)
    );

    assign w_if_id_flush = w_PCSrc;

    assign o_tx = 1'b1;

endmodule
