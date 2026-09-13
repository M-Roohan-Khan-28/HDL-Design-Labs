`timescale 1ns/1ps

module alu #(
    parameter int WIDTH = 8
)(
    input  logic [WIDTH-1:0] a,
    input  logic [WIDTH-1:0] b,
    input  logic [2:0]       op,
    output logic [WIDTH-1:0] y,
    output logic             carry,
    output logic             zero
);

    logic [WIDTH:0] add_tmp;

    always_comb begin
        y       = '0;
        carry   = 1'b0;
        add_tmp = '0;

        unique case (op)
            3'd0: begin // ADD
                add_tmp = {1'b0, a} + {1'b0, b};
                y       = add_tmp[WIDTH-1:0];
                carry   = add_tmp[WIDTH];
            end
            3'd1: y = a - b;          // SUB
            3'd2: y = a & b;          // AND
            3'd3: y = a | b;          // OR
            3'd4: y = a ^ b;          // XOR
            3'd5: y = a << b[2:0];    // SHIFT LEFT 0..7
            3'd6: y = a >> b[2:0];    // SHIFT RIGHT 0..7
            3'd7: y = ~(a ^ b);       // XNOR
            default: y = '0;
        endcase

        zero = (y == '0);
    end

endmodule
