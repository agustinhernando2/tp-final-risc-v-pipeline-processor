`timescale 1ns / 1ps

module tb_DataMemory;

    localparam DATA_WIDTH = 32;
    localparam NB_ADDR = 4;  // 16 words for testing
    localparam CLK_PERIOD = 10;

    logic                  clk;
    logic                  reset;
    logic [   NB_ADDR-1:0] addr;
    logic [DATA_WIDTH-1:0] write_data;
    logic                  mem_write;
    logic [           2:0] funct3;
    logic [DATA_WIDTH-1:0] read_data;

    int                    pass_count;
    int                    fail_count;

    DataMemory #(
        .DATA_WIDTH(DATA_WIDTH),
        .NB_ADDR(NB_ADDR)
    ) DUT (
        .i_clk(clk),
        .i_reset(reset),
        .i_addr(addr),
        .i_write_data(write_data),
        .i_mem_write(mem_write),
        .i_funct3(funct3),
        .o_read_data(read_data)
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

    task write_word(input [NB_ADDR-1:0] test_addr, input [DATA_WIDTH-1:0] test_data);
        addr       <= test_addr;
        write_data <= test_data;
        mem_write  <= 1'b1;
        funct3     <= 3'b010;  // SW: word write
        tick();
        mem_write <= 1'b0;
    endtask

    task write_byte(input [NB_ADDR-1:0] test_addr, input [7:0] test_data);
        addr       <= test_addr;
        write_data <= {{24{1'b0}}, test_data};
        mem_write  <= 1'b1;
        funct3     <= 3'b000;  // SB: byte write
        tick();
        mem_write <= 1'b0;
    endtask

    task write_halfword(input [NB_ADDR-1:0] test_addr, input [15:0] test_data);
        addr       <= test_addr;
        write_data <= {{16{1'b0}}, test_data};
        mem_write  <= 1'b1;
        funct3     <= 3'b001;  // SH: halfword write
        tick();
        mem_write <= 1'b0;
    endtask

    task read_word(input [NB_ADDR-1:0] test_addr);
        addr   <= test_addr;
        funct3 <= 3'b010;  // LW: word read
        tick();
    endtask

    task read_byte_signed(input [NB_ADDR-1:0] test_addr);
        addr   <= test_addr;
        funct3 <= 3'b000;  // LB: byte sign-extended
        tick();
    endtask

    task read_byte_unsigned(input [NB_ADDR-1:0] test_addr);
        addr   <= test_addr;
        funct3 <= 3'b100;  // LBU: byte zero-extended
        tick();
    endtask

    task read_halfword_signed(input [NB_ADDR-1:0] test_addr);
        addr   <= test_addr;
        funct3 <= 3'b001;  // LH: halfword sign-extended
        tick();
    endtask

    task read_halfword_unsigned(input [NB_ADDR-1:0] test_addr);
        addr   <= test_addr;
        funct3 <= 3'b101;  // LHU: halfword zero-extended
        tick();
    endtask

    initial begin
        clk        = 0;
        reset      = 1;
        mem_write  = 0;
        addr       = '0;
        write_data = '0;
        funct3     = '0;
        pass_count = 0;
        fail_count = 0;

        tick();
        reset = 0;
        tick();

        // Test 1: Write and read back a full word
        $display("--- Full word read/write ---");
        write_word(4'h0, 32'hDEADBEEF);
        tick();
        read_word(4'h0);
        check("write/read full word", read_data, 32'hDEADBEEF);

        // Test 2: Byte write to low byte of word
        $display("--- Byte write ---");
        write_word(4'h1, 32'h12345678);
        tick();
        write_byte(4'h1, 8'hAA);
        tick();
        read_word(4'h1);
        check("byte write at [7:0]", read_data, 32'h123456AA);

        // Test 3: Halfword write
        $display("--- Halfword write ---");
        write_word(4'h2, 32'h11223344);
        tick();
        write_halfword(4'h2, 16'hBBCC);
        tick();
        read_word(4'h2);
        check("halfword write at [15:0]", read_data, 32'h1122BBCC);

        // Test 4: Byte sign extension (negative)
        $display("--- Sign extension ---");
        write_word(4'h3, 32'h000000FF);
        tick();
        read_byte_signed(4'h3);
        check("LB sign-extend 0xFF", read_data, 32'hFFFFFFFF);

        // Test 5: Byte zero extension
        $display("--- Zero extension ---");
        write_word(4'h4, 32'h000000FF);
        tick();
        read_byte_unsigned(4'h4);
        check("LBU zero-extend 0xFF", read_data, 32'h000000FF);

        // Test 6: Halfword sign extension (negative)
        $display("--- Halfword sign extension ---");
        write_word(4'h5, 32'h0000FFFF);
        tick();
        read_halfword_signed(4'h5);
        check("LH sign-extend 0xFFFF", read_data, 32'hFFFFFFFF);

        // Test 7: Halfword zero extension
        $display("--- Halfword zero extension ---");
        write_word(4'h6, 32'h0000FFFF);
        tick();
        read_halfword_unsigned(4'h6);
        check("LHU zero-extend 0xFFFF", read_data, 32'h0000FFFF);

        // Test 8: Reset does NOT clear memory (data persists so the array maps
        // to BRAM instead of distributed flip-flops). Program/data are reloaded
        // over UART, so a memory-clearing reset is neither needed nor wanted.
        $display("--- Reset behavior ---");
        write_word(4'h0, 32'hDEADBEEF);
        tick();
        reset = 1;
        tick();
        reset = 0;
        tick();
        read_word(4'h0);
        check("memory retained across reset", read_data, 32'hDEADBEEF);

        // Test 9: Byte write doesn't corrupt upper bits
        $display("--- Byte write isolation ---");
        write_word(4'h7, 32'hAABBCCDD);
        tick();
        write_byte(4'h7, 8'h44);
        tick();
        read_word(4'h7);
        check("byte write preserves upper bits", read_data, 32'hAABBCC44);

        // Test 10: Positive byte sign extension
        $display("--- Positive sign extension ---");
        write_byte(4'h8, 8'h7F);
        tick();
        read_byte_signed(4'h8);
        check("LB sign-extend 0x7F", read_data, 32'h0000007F);

        $display("\n--- Results: %0d passed, %0d failed ---", pass_count, fail_count);
        if (fail_count == 0) $display("ALL TESTS PASSED");
        else $display("SOME TESTS FAILED");
        $finish;
    end

endmodule
