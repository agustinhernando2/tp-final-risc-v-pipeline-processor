`timescale 1ns / 1ps

module tb_adder();
    reg [31:0] a, b;
    wire [31:0] sum;

    // Instancia del adder
    Adder #(
        .DATA_WIDTH(32)
    ) adder_uut (
        .i_operand_a(a),
        .i_operand_b(b),
        .o_sum(sum)
    );

    initial begin
        $monitor("Tiempo=%0t | a=%b | b=%b | sum=%b", $time, a, b, sum);

        // Inicialización
        a = 0;
        b = 0;

        // Sumas 

        #10;
        a = 1'b1;
        b = 2'b10;
        #10;

        a = 2'b10;
        b = 2'b11;
        #10;

        a = 4'b1010;
        b = 4'b0101;
        #10;

        a = 8'b00001111;
        b = 8'b00000001;
        #10;

        a = 1'b1;
        b = 1'b1;
        #10;

        $finish;
    end

endmodule
