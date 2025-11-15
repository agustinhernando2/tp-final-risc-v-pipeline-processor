`timescale 1ns / 1ps

module tb_IF();

    reg clk;
    reg reset;
    reg enable;
    reg PCSrc;
    reg [31:0] PCBranch;

    reg mem_wr;
    reg [7:0] mem_addr;
    reg [31:0] mem_data;

    wire [31:0] PC_increment;
    wire [31:0] instruction;
    wire [31:0] PC;

    // Instanciar el Instruction Fetch
    InstructionFetch uut (
        .i_clk(clk),
        .i_reset(reset),
        .i_enable(enable),
        .i_PCSrc(PCSrc),
        .i_PCBranch(PCBranch),
        .i_mem_wr(mem_wr),
        .i_mem_addr(mem_addr),
        .i_mem_data(mem_data),
        .o_PC_increment(PC_increment),
        .o_instruction(instruction),
        .o_PC(PC)
    );

    // Generador de clock
    always #5 clk = ~clk;

    // Inicialización y escritura de instrucciones
    initial begin
        clk = 0; reset = 1; enable = 0; PCBranch = 1'b0; PCSrc = 1'b0;

        #10; // Esperar a que se escriba
        reset = 0;
        //escribimos datos  
        mem_wr = 1'b1;
        mem_addr = 8'd0;
        mem_data = 32'b1010;

        #10;
        mem_addr = 8'd1;
        mem_data = 32'b1111;

        #15;
        mem_wr = 1'b0;
        enable = 1'b1;

        #20 $finish;

    end

endmodule
