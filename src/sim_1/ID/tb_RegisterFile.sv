`timescale 1ns / 1ps

module tb_RegisterFile;

    localparam NB_REG = 5;
    localparam DATA_WIDTH = 32;
    localparam CLK_PERIOD = 10;

    logic                  clk;
    logic                  reset;
    logic [    NB_REG-1:0] read_reg_1;
    logic [    NB_REG-1:0] read_reg_2;
    logic [    NB_REG-1:0] write_reg;
    logic [DATA_WIDTH-1:0] write_data;
    logic                  reg_write;
    logic [DATA_WIDTH-1:0] read_data_1;
    logic [DATA_WIDTH-1:0] read_data_2;

    int                    pass_count;
    int                    fail_count;

    RegisterFile #(
        .NB_REG(NB_REG),
        .DATA_WIDTH(DATA_WIDTH)
    ) DUT (
        .i_clk       (clk),
        .i_reset     (reset),
        .i_read_reg_1(read_reg_1),
        .i_read_reg_2(read_reg_2),
        .i_write_reg (write_reg),
        .i_write_data(write_data),
        .i_regWrite  (reg_write),
        .o_read_reg_1(read_data_1),
        .o_read_reg_2(read_data_2)
    );

    always #(CLK_PERIOD / 2) clk = ~clk;

    task automatic check(input string label, input logic [DATA_WIDTH-1:0] got, expected);
        if (got === expected) begin
            $display("  PASS  %s: 0x%08h", label, got);
            pass_count++;
        end else begin
            $display("  FAIL  %s: expected 0x%08h, got 0x%08h", label, expected, got);
            fail_count++;
        end
    endtask

    task automatic tick();
        @(posedge clk);
        #1;
    endtask

    initial begin
        clk        = 0;
        reset      = 1;
        reg_write  = 0;
        write_reg  = '0;
        write_data = '0;
        read_reg_1 = '0;
        read_reg_2 = '0;
        pass_count = 0;
        fail_count = 0;

        // --- Test 1: x0 reads as 0 after reset ---
        tick();
        reset = 0;
        read_reg_1 = 5'd0;
        #1;
        $display("Test 1: x0 reads 0 after reset");
        check("x0 after reset", read_data_1, 32'h0);

        // --- Test 2: write a value to x1, read it back ---
        $display("Test 2: write 0xDEADBEEF to x1, read back");
        reg_write  = 1;
        write_reg  = 5'd1;
        write_data = 32'hDEAD_BEEF;
        tick();
        reg_write  = 0;
        read_reg_1 = 5'd1;
        #1;
        check("x1 read back", read_data_1, 32'hDEAD_BEEF);

        // --- Test 3: write another value to x2 ---
        $display("Test 3: write 0x12345678 to x2, read back");
        reg_write  = 1;
        write_reg  = 5'd2;
        write_data = 32'h1234_5678;
        tick();
        reg_write  = 0;
        read_reg_1 = 5'd1;
        read_reg_2 = 5'd2;
        #1;
        check("x1 still holds", read_data_1, 32'hDEAD_BEEF);
        check("x2 read back", read_data_2, 32'h1234_5678);

        // --- Test 4: x0 is hardwired zero — write must be ignored ---
        $display("Test 4: attempt to write 0xFFFFFFFF to x0 (must be ignored)");
        reg_write  = 1;
        write_reg  = 5'd0;
        write_data = 32'hFFFF_FFFF;
        tick();
        reg_write  = 0;
        read_reg_1 = 5'd0;
        #1;
        check("x0 hardwired zero", read_data_1, 32'h0);

        // --- Test 5: reset clears all registers ---
        $display("Test 5: reset clears x1 and x2");
        reset = 1;
        tick();
        reset      = 0;
        read_reg_1 = 5'd1;
        read_reg_2 = 5'd2;
        #1;
        check("x1 after reset", read_data_1, 32'h0);
        check("x2 after reset", read_data_2, 32'h0);

        $display("\n--- Results: %0d passed, %0d failed ---", pass_count, fail_count);
        if (fail_count == 0) $display("ALL TESTS PASSED");
        else $display("SOME TESTS FAILED");

        $finish;
    end

endmodule
