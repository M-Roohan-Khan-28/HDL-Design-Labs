`timescale 1ns/1ps

module tb_ahb_lite_slave_ram;

logic        HCLK;
logic        HRESETn;
logic        HSEL;
logic [7:0]  HADDR;
logic [1:0]  HTRANS;
logic        HWRITE;
logic [2:0]  HSIZE;
logic [31:0] HWDATA;
logic        HREADY;
logic [31:0] HRDATA;
logic        HREADYOUT;
logic        HRESP;
integer      pass_count;
integer      fail_count;

ahb_lite_slave_ram dut(
    .HCLK(HCLK),
    .HRESETn(HRESETn),
    .HSEL(HSEL),
    .HADDR(HADDR),
    .HTRANS(HTRANS),
    .HWRITE(HWRITE),
    .HSIZE(HSIZE),
    .HWDATA(HWDATA),
    .HREADY(HREADY),
    .HRDATA(HRDATA),
    .HREADYOUT(HREADYOUT),
    .HRESP(HRESP)
);

assign HREADY = HREADYOUT;
always #5 HCLK = ~HCLK;

task automatic check(input logic condition, input string message);
begin
    if(condition)
    begin
        $display("PASS: %s", message);
        pass_count = pass_count + 1;
    end
    else
    begin
        $display("FAIL: %s", message);
        fail_count = fail_count + 1;
    end
end
endtask

task automatic ahb_write(
    input logic [7:0] address,
    input logic [31:0] data,
    input logic expect_error
);
begin
    @(negedge HCLK);
    HSEL = 1'b1;
    HTRANS = 2'b10;
    HWRITE = 1'b1;
    HSIZE = 3'b010;
    HADDR = address;

    @(posedge HCLK);
    @(negedge HCLK);
    HSEL = 1'b0;
    HTRANS = 2'b00;
    HWRITE = 1'b0;
    HWDATA = data;

    #1;
    check(HREADYOUT === 1'b1, "Slave has zero wait states");
    check(HRESP === expect_error, "Write response is correct");

    @(posedge HCLK);
    @(negedge HCLK);
    HWDATA = 32'h0000_0000;
end
endtask

task automatic ahb_read(
    input logic [7:0] address,
    input logic [31:0] expected_data,
    input logic expect_error
);
begin
    @(negedge HCLK);
    HSEL = 1'b1;
    HTRANS = 2'b10;
    HWRITE = 1'b0;
    HSIZE = 3'b010;
    HADDR = address;

    @(posedge HCLK);
    @(negedge HCLK);
    HSEL = 1'b0;
    HTRANS = 2'b00;

    #1;
    check(HRESP === expect_error, "Read response is correct");

    if(expect_error)
        check(HRDATA === 32'h0000_0000, "Invalid read returns zero");
    else
        check(HRDATA === expected_data, "Read data matches RAM");

    @(posedge HCLK);
end
endtask

initial
begin
    $dumpfile("ahb_lite_slave_ram.vcd");
    $dumpvars(0, tb_ahb_lite_slave_ram);

    HCLK = 1'b0;
    HRESETn = 1'b0;
    HSEL = 1'b0;
    HADDR = 8'h00;
    HTRANS = 2'b00;
    HWRITE = 1'b0;
    HSIZE = 3'b010;
    HWDATA = 32'h0000_0000;
    pass_count = 0;
    fail_count = 0;

    repeat(2) @(posedge HCLK);
    @(negedge HCLK);
    HRESETn = 1'b1;

    ahb_read(8'h00, 32'h0000_0000, 1'b0);
    ahb_write(8'h00, 32'hDEAD_BEEF, 1'b0);
    ahb_write(8'h04, 32'h1234_5678, 1'b0);
    ahb_write(8'h3C, 32'hCAFE_BABE, 1'b0);
    ahb_read(8'h00, 32'hDEAD_BEEF, 1'b0);
    ahb_read(8'h04, 32'h1234_5678, 1'b0);
    ahb_read(8'h3C, 32'hCAFE_BABE, 1'b0);
    ahb_write(8'h02, 32'h1111_2222, 1'b1);
    ahb_read(8'h40, 32'h0000_0000, 1'b1);

    $display("TOTAL PASSED = %0d", pass_count);
    $display("TOTAL FAILED = %0d", fail_count);

    if(fail_count == 0)
        $display("ALL AHB-LITE TESTS PASSED");
    else
        $fatal(1, "AHB-LITE TESTBENCH FAILED");

    #20;
    $finish;
end

endmodule
