`timescale 1ns/1ps

module tb_cache_2way;

logic       clk;
logic       reset;
logic       write;
logic [2:0] tag;
logic [1:0] index;
logic [7:0] data_in;
logic       way_select;

logic [7:0] data_out;
logic       hit;

logic [47:0] roohan_word;
logic        roohan_ready;

integer pass_count;
integer fail_count;

cache_2way uut(

    .clk        (clk),
    .reset      (reset),
    .write      (write),
    .tag        (tag),
    .index      (index),
    .data_in    (data_in),
    .way_select (way_select),
    .data_out   (data_out),
    .hit        (hit)

);

always #5 clk = ~clk;

task automatic cache_write(

    input logic       selected_way,
    input logic [2:0] write_tag,
    input logic [1:0] write_index,
    input logic [7:0] write_data

);
begin

    @(negedge clk);

    write      = 1'b1;
    way_select = selected_way;
    tag        = write_tag;
    index      = write_index;
    data_in    = write_data;

    @(posedge clk);
    #1;

    @(negedge clk);

    write   = 1'b0;
    data_in = 8'h00;

end
endtask

task automatic cache_read(

    input logic [2:0] read_tag,
    input logic [1:0] read_index,
    input logic [7:0] expected_data,
    input integer     position

);
begin

    @(negedge clk);

    write = 1'b0;
    tag   = read_tag;
    index = read_index;

    #1;

    roohan_word[47 - position*8 -: 8] = data_out;

    if(hit === 1'b1 && data_out === expected_data)
    begin

        $display(
            "PASS: Character %0d = %c, ASCII = %h",
            position + 1,
            data_out,
            data_out
        );

        pass_count = pass_count + 1;

    end
    else
    begin

        $display(
            "FAIL: Character %0d, expected = %h, received = %h, hit = %b",
            position + 1,
            expected_data,
            data_out,
            hit
        );

        fail_count = fail_count + 1;

    end

    @(posedge clk);
    #1;

end
endtask

initial
begin

    $dumpfile("cache_2way_roohan.vcd");
    $dumpvars(0, tb_cache_2way);

    clk          = 1'b0;
    reset        = 1'b1;
    write        = 1'b0;
    tag          = 3'b000;
    index        = 2'b00;
    data_in      = 8'h00;
    way_select   = 1'b0;
    roohan_word  = 48'h000000000000;
    roohan_ready = 1'b0;
    pass_count   = 0;
    fail_count   = 0;

    repeat(2) @(posedge clk);

    @(negedge clk);
    reset = 1'b0;

    // ROOHAN: r=72, o=6F, o=6F, h=68, a=61, n=6E

    cache_write(1'b0, 3'b000, 2'b00, 8'h72);
    cache_write(1'b1, 3'b001, 2'b00, 8'h6F);

    cache_write(1'b0, 3'b010, 2'b01, 8'h6F);
    cache_write(1'b1, 3'b011, 2'b01, 8'h68);

    cache_write(1'b0, 3'b100, 2'b10, 8'h61);
    cache_write(1'b1, 3'b101, 2'b10, 8'h6E);

    cache_read(3'b000, 2'b00, 8'h72, 0);
    cache_read(3'b001, 2'b00, 8'h6F, 1);
    cache_read(3'b010, 2'b01, 8'h6F, 2);
    cache_read(3'b011, 2'b01, 8'h68, 3);
    cache_read(3'b100, 2'b10, 8'h61, 4);
    cache_read(3'b101, 2'b10, 8'h6E, 5);

    roohan_ready = 1'b1;

    $display("------------------------------------------");
    $display("WORD IN HEX   = %h", roohan_word);
    $display("WORD IN ASCII = %s", roohan_word);
    $display("------------------------------------------");

    @(negedge clk);

    tag   = 3'b111;
    index = 2'b11;
    write = 1'b0;

    #1;

    if(hit === 1'b0 && data_out === 8'h00)
    begin

        $display("PASS: Cache miss detected correctly");
        pass_count = pass_count + 1;

    end
    else
    begin

        $display("FAIL: Cache miss was not detected");
        fail_count = fail_count + 1;

    end

    $display("------------------------------------------");
    $display("TOTAL PASSED = %0d", pass_count);
    $display("TOTAL FAILED = %0d", fail_count);
    $display("------------------------------------------");

    if(fail_count == 0)
        $display("ALL CACHE TESTS PASSED");
    else
        $fatal(1, "CACHE TESTBENCH FAILED");

    #10;
    $finish;

end

endmodule