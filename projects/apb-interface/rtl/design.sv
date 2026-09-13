`timescale 1ns/1ps

interface apb_if(input logic PCLK);
    logic        PRESETn;
    logic        PSEL;
    logic        PENABLE;
    logic        PWRITE;
    logic [7:0]  PADDR;
    logic [31:0] PWDATA;
    logic [31:0] PRDATA;
    logic        PREADY;
    logic        PSLVERR;

    // DUT sees bus controls as inputs and response signals as outputs.
    modport DUT (
        input  PCLK, PRESETn, PSEL, PENABLE, PWRITE, PADDR, PWDATA,
        output PRDATA, PREADY, PSLVERR
    );

    // TB role is the reverse direction.
    modport TB (
        input  PCLK, PRDATA, PREADY, PSLVERR,
        output PRESETn, PSEL, PENABLE, PWRITE, PADDR, PWDATA
    );
endinterface

module apb_ram(apb_if.DUT apb);
    logic [31:0] mem [0:63];
    integer i;

    // Zero-wait-state APB slave for this educational lab.
    assign apb.PREADY  = 1'b1;
    assign apb.PSLVERR = 1'b0;

    // Write occurs in APB ACCESS phase.
    always_ff @(posedge apb.PCLK or negedge apb.PRESETn) begin
        if (!apb.PRESETn) begin
            for (i = 0; i < 64; i = i + 1)
                mem[i] <= 32'h0000_0000;
        end
        else if (apb.PSEL && apb.PENABLE && apb.PWRITE && apb.PREADY) begin
            mem[apb.PADDR[7:2]] <= apb.PWDATA;
        end
    end

    // Combinational read path.
    always_comb begin
        apb.PRDATA = 32'h0000_0000;
        if (apb.PSEL && !apb.PWRITE)
            apb.PRDATA = mem[apb.PADDR[7:2]];
    end
endmodule
