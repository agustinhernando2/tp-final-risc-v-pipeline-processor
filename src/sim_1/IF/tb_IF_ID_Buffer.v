`timescale 1ns / 1ps

module tb_IF_ID_Buffer();
    reg clk= 1'b0;
    reg clk, reset, enable;
    reg [31:0] pc_in, inst_in;
    wire [31:0] pc_out, inst_out;

    IF_ID_Buffer uut (
        .i_clk(clk),
        .i_reset(reset),
        .i_enable(enable),
        .i_PC_increment(pc_in),
        .i_instruction(inst_in),
        .o_PC_increment(pc_out),
        .o_instruction(inst_out)
    );

    always #5 clk = ~clk;

    initial begin
        $monitor("t=%0t | rst=%b | en=%b | pc_in=%h | inst_in=%h | pc_out=%h | inst_out=%h", 
                 $time, reset, enable, pc_in, inst_in, pc_out, inst_out);

        clk = 0; reset = 1; enable = 0;
        pc_in = 32'b0;
        inst_in = 32'b0;
        #10
        reset = 0; enable = 1;
    
        #10
        pc_in = 32'hFF00; 
        inst_in = 32'h00FF;
    
        #10
        pc_in = 32'hF000; 
        inst_in = 32'h000F;
    
    
        #10 enable = 0;
        
        #10 
        pc_in = 32'hFFFF; 
        inst_in = 32'hFFFF;

        #10 enable = 1;
        #10 $finish;
    end
endmodule
