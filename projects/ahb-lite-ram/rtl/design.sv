module ahb_lite_slave_ram(

    input  logic        HCLK,
    input  logic        HRESETn,
    input  logic        HSEL,
    input  logic [7:0]  HADDR,
    input  logic [1:0]  HTRANS,
    input  logic        HWRITE,
    input  logic [2:0]  HSIZE,
    input  logic [31:0] HWDATA,
    input  logic        HREADY,

    output logic [31:0] HRDATA,
    output logic        HREADYOUT,
    output logic        HRESP

);

logic [31:0] memory [0:15];
logic        transfer_q;
logic        write_q;
logic        error_q;
logic [3:0]  index_q;
integer      i;

assign HREADYOUT = 1'b1;
assign HRESP = transfer_q && error_q;
assign HRDATA = (transfer_q && !write_q && !error_q) ?
                memory[index_q] : 32'h0000_0000;

always_ff @(posedge HCLK or negedge HRESETn)
begin

    if(!HRESETn)
    begin

        transfer_q <= 1'b0;
        write_q <= 1'b0;
        error_q <= 1'b0;
        index_q <= 4'd0;

        for(i = 0; i < 16; i = i + 1)
            memory[i] <= 32'h0000_0000;

    end
    else if(HREADY)
    begin

        if(transfer_q && write_q && !error_q)
            memory[index_q] <= HWDATA;

        transfer_q <= HSEL && HTRANS[1];
        write_q <= HWRITE;
        index_q <= HADDR[5:2];
        error_q <= (HADDR[1:0] != 2'b00) ||
                   (HADDR > 8'h3C) ||
                   (HSIZE != 3'b010);

    end

end

endmodule
