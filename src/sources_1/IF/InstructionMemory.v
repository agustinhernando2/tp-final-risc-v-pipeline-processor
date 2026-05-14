`timescale 1ns / 1ps

module InstructionMemory#(
    parameter NB_PC = 32,
    parameter NB_inst = 32,
    parameter NB_ADDR = 8
)(
    input i_clk,
    input i_reset,
    input [NB_PC-1:0] i_PC,
    input i_mem_wr,                    // Indica si se va a escribir 
    input [NB_ADDR-1:0] i_mem_addr,    // Address donde se va a escribir
    input [NB_inst-1:0 ]i_mem_data,    // Dato a escribir en la memoria

    output [NB_inst-1:0] o_instruction
);

    reg [NB_inst-1:0] reg_instructionMemory [2**NB_ADDR-1:0];
    
    integer i=0;
    initial begin
        // Initialize memory with 0s
        for (i = 0; i<2**NB_ADDR ;i=i+1) begin
            reg_instructionMemory[i] = 32'b0;
        end
        // Load program if in simulation
        // Note: program.hex must be in the simulation execution directory
        $readmemh("program.hex", reg_instructionMemory);
    end

    always @(posedge i_clk) begin
        if (i_reset) begin
            for (i = 0; i<2**NB_ADDR ;i=i+1) begin
                reg_instructionMemory[i] <= 32'b0;
            end
        end else if (i_mem_wr) begin
            reg_instructionMemory[i_mem_addr] <= i_mem_data;
        end
    end

    assign o_instruction = reg_instructionMemory[i_PC & {NB_ADDR {1'b1}}]; // mascara de los bits menos significativos

endmodule
