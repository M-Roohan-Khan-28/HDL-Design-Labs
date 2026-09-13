`timescale 1ns/1ps

class alu_transaction;
    rand bit [7:0] a;
    rand bit [7:0] b;
    rand bit [2:0] op;

    // Legal-value constraint.
    constraint legal_op_c {
        op inside {[3'd0:3'd7]};
    }

    // Weighted distribution: arithmetic and XNOR are seen slightly more often.
    constraint op_weight_c {
        op dist {
            3'd0 := 20,
            3'd1 := 15,
            3'd2 := 10,
            3'd3 := 10,
            3'd4 := 10,
            3'd5 := 10,
            3'd6 := 10,
            3'd7 := 15
        };
    }

    // Corner values occur more often than normal values.
    constraint data_weight_c {
        a dist {8'h00 := 5, 8'hFF := 5, [8'h01:8'hFE] := 1};
        b dist {8'h00 := 5, 8'hFF := 5, [8'h01:8'hFE] := 1};
    }

    // Implication: for shift operations keep the shift amount in 0..7.
    constraint shift_amount_c {
        (op inside {3'd5, 3'd6}) -> (b inside {[8'd0:8'd7]});
    }

    // Soft constraint can be overridden by an inline constraint.
    constraint prefer_different_c {
        soft a != b;
    }

    function void display(string tag = "TR");
        $display("[%s] a=%0h b=%0h op=%0d", tag, a, b, op);
    endfunction
endclass

module tb_alu;
    localparam int N_RANDOM = 64;

    logic [7:0] a, b;
    logic [2:0] op;
    logic [7:0] y;
    logic       carry, zero;

    int pass_count = 0;
    int fail_count = 0;

    alu dut (
        .a(a), .b(b), .op(op),
        .y(y), .carry(carry), .zero(zero)
    );

    // VCD block for EDA Playground + EPWave.
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_alu);
    end

    function automatic logic [8:0] reference_model(
        input bit [7:0] aa,
        input bit [7:0] bb,
        input bit [2:0] oo
    );
        logic [7:0] yy;
        logic       cc;
        logic [8:0] add_tmp;
        begin
            yy = '0;
            cc = 1'b0;
            add_tmp = '0;
            case (oo)
                3'd0: begin
                    add_tmp = {1'b0, aa} + {1'b0, bb};
                    yy = add_tmp[7:0];
                    cc = add_tmp[8];
                end
                3'd1: yy = aa - bb;
                3'd2: yy = aa & bb;
                3'd3: yy = aa | bb;
                3'd4: yy = aa ^ bb;
                3'd5: yy = aa << bb[2:0];
                3'd6: yy = aa >> bb[2:0];
                3'd7: yy = ~(aa ^ bb);
                default: yy = 8'h00;
            endcase
            return {cc, yy};
        end
    endfunction

    task automatic apply_and_check(alu_transaction tr, int id);
        logic [8:0] expected;
        logic       expected_zero;
        begin
            a  = tr.a;
            b  = tr.b;
            op = tr.op;
            #1;

            expected      = reference_model(tr.a, tr.b, tr.op);
            expected_zero = (expected[7:0] == 8'h00);

            if ((y === expected[7:0]) &&
                (carry === expected[8]) &&
                (zero === expected_zero)) begin
                pass_count++;
                $display("[PASS %0d] op=%0d a=%02h b=%02h y=%02h carry=%0b zero=%0b",
                         id, op, a, b, y, carry, zero);
            end
            else begin
                fail_count++;
                $error("[FAIL %0d] op=%0d a=%02h b=%02h y=%02h exp=%02h carry=%0b expC=%0b",
                       id, op, a, b, y, expected[7:0], carry, expected[8]);
            end
        end
    endtask

    initial begin
        alu_transaction tr;
        int id = 0;

        a = '0;
        b = '0;
        op = '0;

        // 1) Directed constrained-random phase using INLINE constraints.
        //    It guarantees that every ALU operation is exercised at least once.
        for (int k = 0; k < 8; k++) begin
            tr = new();
            if (!tr.randomize() with { op == k; }) begin
                $fatal(1, "Randomization failed in directed phase for op=%0d", k);
            end
            apply_and_check(tr, id++);
        end

        // 2) Main constrained-random phase.
        repeat (N_RANDOM) begin
            tr = new();
            if (!tr.randomize()) begin
                $fatal(1, "Randomization failed. Review conflicting constraints.");
            end
            apply_and_check(tr, id++);
        end

        // Example of overriding a SOFT constraint inline.
        tr = new();
        if (!tr.randomize() with { a == b; op == 3'd4; }) begin
            $fatal(1, "Inline override of soft constraint failed unexpectedly.");
        end
        apply_and_check(tr, id++);

        $display("\n========================================");
        $display("TASK 1 SUMMARY: PASS=%0d FAIL=%0d", pass_count, fail_count);
        $display("========================================\n");

        #10;
        $finish;
    end
endmodule
