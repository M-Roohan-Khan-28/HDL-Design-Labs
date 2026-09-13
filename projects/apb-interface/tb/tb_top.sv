`timescale 1ns/1ps

// ------------------------------------------------------------
// Base class + inheritance + virtual method (polymorphism base)
// ------------------------------------------------------------
class base_transaction;
    virtual function void display(string tag = "BASE");
        $display("[%s] base transaction", tag);
    endfunction
endclass

class apb_transaction extends base_transaction;
    rand bit [7:0]  addr;
    rand bit [31:0] data;
    rand bit        write;

    bit [31:0] rdata;
    bit        error;

    constraint aligned_c {
        addr[1:0] == 2'b00;
    }

    constraint valid_range_c {
        addr inside {[8'h00:8'hFC]};
    }

    constraint rw_weight_c {
        write dist {1'b1 := 55, 1'b0 := 45};
    }

    constraint addr_weight_c {
        addr dist {
            8'h00 := 5,
            8'hFC := 5,
            [8'h04:8'hF8] := 1
        };
    }

    function void display(string tag = "APB");
        $display("[%s] %s addr=%02h wdata=%08h rdata=%08h err=%0b",
                 tag, write ? "WRITE" : "READ ", addr, data, rdata, error);
    endfunction
endclass

// Lightweight factory pattern: separates creation from use.
class apb_factory;
    static function apb_transaction create();
        apb_transaction tr;
        tr = new();
        return tr;
    endfunction
endclass

// ------------------------------------------------------------
// Generator: constrained-random transaction creation
// ------------------------------------------------------------
class generator;
    mailbox #(apb_transaction) gen2drv;
    event generation_done;

    function new(mailbox #(apb_transaction) gen2drv);
        this.gen2drv = gen2drv;
    endfunction

    task run(int n);
        apb_transaction tr;
        base_transaction base_h;

        for (int i = 0; i < n; i++) begin
            tr = apb_factory::create();

            // First six transfers are coverage-directed using inline constraints.
            case (i)
                0: if (!tr.randomize() with {write == 1; addr == 8'h00; data == 32'h0000_0000;}) $fatal(1, "Directed randomization failed: case 0");
                1: if (!tr.randomize() with {write == 0; addr == 8'h00;})                         $fatal(1, "Directed randomization failed: case 1");
                2: if (!tr.randomize() with {write == 1; addr == 8'h80; data == 32'hFFFF_FFFF;}) $fatal(1, "Directed randomization failed: case 2");
                3: if (!tr.randomize() with {write == 0; addr == 8'h80;})                         $fatal(1, "Directed randomization failed: case 3");
                4: if (!tr.randomize() with {write == 1; addr == 8'hFC; data == 32'hA5A5_A5A5;}) $fatal(1, "Directed randomization failed: case 4");
                5: if (!tr.randomize() with {write == 0; addr == 8'hFC;})                         $fatal(1, "Directed randomization failed: case 5");
                default: begin
                    if (!tr.randomize())
                        $fatal(1, "APB randomization failed at transaction %0d", i);
                end
            endcase

            // Polymorphism demonstration: base handle points to child object.
            if (i == 0) begin
                base_h = tr;
                base_h.display("POLYMORPHIC CALL");
            end

            gen2drv.put(tr); // mailbox communication
        end

        -> generation_done; // event synchronization example
    endtask
endclass

// ------------------------------------------------------------
// Driver: transaction -> APB pin-level protocol
// ------------------------------------------------------------
class driver;
    virtual apb_if vif;
    mailbox #(apb_transaction) gen2drv;
    semaphore bus_lock;

    function new(
        virtual apb_if vif,
        mailbox #(apb_transaction) gen2drv,
        semaphore bus_lock
    );
        this.vif      = vif;
        this.gen2drv  = gen2drv;
        this.bus_lock = bus_lock;
    endfunction

    task reset_bus();
        vif.PSEL    <= 1'b0;
        vif.PENABLE <= 1'b0;
        vif.PWRITE  <= 1'b0;
        vif.PADDR   <= '0;
        vif.PWDATA  <= '0;
    endtask

    task drive_one(apb_transaction tr);
        // The semaphore protects the shared bus resource.
        bus_lock.get(1);

        // SETUP phase: drive controls before next rising edge.
        @(negedge vif.PCLK);
        vif.PSEL    <= 1'b1;
        vif.PENABLE <= 1'b0;
        vif.PWRITE  <= tr.write;
        vif.PADDR   <= tr.addr;
        vif.PWDATA  <= tr.data;

        // ACCESS phase.
        @(negedge vif.PCLK);
        vif.PENABLE <= 1'b1;

        // Wait for transfer completion. This DUT keeps PREADY=1.
        @(posedge vif.PCLK);
        while (!vif.PREADY)
            @(posedge vif.PCLK);

        if (!tr.write)
            tr.rdata = vif.PRDATA;
        tr.error = vif.PSLVERR;

        // Return bus to IDLE.
        @(negedge vif.PCLK);
        vif.PSEL    <= 1'b0;
        vif.PENABLE <= 1'b0;
        vif.PWRITE  <= 1'b0;
        vif.PADDR   <= '0;
        vif.PWDATA  <= '0;

        bus_lock.put(1);
    endtask

    task run(int n);
        apb_transaction tr;
        reset_bus();
        repeat (n) begin
            gen2drv.get(tr);
            drive_one(tr);
        end
    endtask
endclass

// ------------------------------------------------------------
// Monitor + functional coverage
// ------------------------------------------------------------
class monitor;
    virtual apb_if vif;
    mailbox #(apb_transaction) mon2sb;

    covergroup apb_cg with function sample(
        bit        wr,
        bit [7:0]  addr,
        bit [31:0] observed_data
    );
        option.per_instance = 1;

        cp_direction: coverpoint wr {
            bins read  = {0};
            bins write = {1};
        }

        cp_addr_region: coverpoint addr {
            bins low  = {[8'h00:8'h3C]};
            bins mid  = {[8'h40:8'hBC]};
            bins high = {[8'hC0:8'hFC]};
        }

        cp_boundary: coverpoint addr {
            bins first    = {8'h00};
            bins last     = {8'hFC};
            bins interior = default;
        }

        cp_data_class: coverpoint observed_data {
            bins zero  = {32'h0000_0000};
            bins ones  = {32'hFFFF_FFFF};
            bins other = default;
        }

        direction_x_region: cross cp_direction, cp_addr_region;
    endgroup

    function new(virtual apb_if vif, mailbox #(apb_transaction) mon2sb);
        this.vif    = vif;
        this.mon2sb = mon2sb;
        apb_cg      = new();
    endfunction

    task run(int n);
        apb_transaction tr;
        repeat (n) begin
            do @(posedge vif.PCLK);
            while (!(vif.PRESETn && vif.PSEL && vif.PENABLE && vif.PREADY));

            tr       = new();
            tr.addr  = vif.PADDR;
            tr.write = vif.PWRITE;
            tr.data  = vif.PWDATA;
            tr.rdata = vif.PRDATA;
            tr.error = vif.PSLVERR;

            apb_cg.sample(tr.write, tr.addr, tr.write ? tr.data : tr.rdata);
            mon2sb.put(tr);
        end
    endtask

    function real coverage();
        return apb_cg.get_inst_coverage();
    endfunction
endclass

// ------------------------------------------------------------
// Scoreboard: reference RAM model + comparison
// ------------------------------------------------------------
class scoreboard;
    mailbox #(apb_transaction) mon2sb;
    bit [31:0] ref_mem [0:63];
    int pass_count = 0;
    int fail_count = 0;

    function new(mailbox #(apb_transaction) mon2sb);
        this.mon2sb = mon2sb;
        foreach (ref_mem[i])
            ref_mem[i] = 32'h0000_0000;
    endfunction

    task run(int n);
        apb_transaction tr;
        int idx;
        repeat (n) begin
            mon2sb.get(tr);
            idx = tr.addr[7:2];

            if (tr.error) begin
                fail_count++;
                $error("[SB FAIL] PSLVERR at address %02h", tr.addr);
            end
            else if (tr.write) begin
                ref_mem[idx] = tr.data;
                pass_count++;
                $display("[SB PASS] WRITE addr=%02h data=%08h", tr.addr, tr.data);
            end
            else if (tr.rdata !== ref_mem[idx]) begin
                fail_count++;
                $error("[SB FAIL] READ addr=%02h got=%08h expected=%08h",
                       tr.addr, tr.rdata, ref_mem[idx]);
            end
            else begin
                pass_count++;
                $display("[SB PASS] READ  addr=%02h data=%08h", tr.addr, tr.rdata);
            end
        end
    endtask
endclass

// ------------------------------------------------------------
// Environment: connects generator, driver, monitor, scoreboard
// ------------------------------------------------------------
class environment;
    mailbox #(apb_transaction) gen2drv;
    mailbox #(apb_transaction) mon2sb;
    semaphore bus_lock;

    generator  gen;
    driver     drv;
    monitor    mon;
    scoreboard sb;

    function new(virtual apb_if vif);
        gen2drv = new();
        mon2sb  = new();
        bus_lock = new(1);

        gen = new(gen2drv);
        drv = new(vif, gen2drv, bus_lock);
        mon = new(vif, mon2sb);
        sb  = new(mon2sb);
    endfunction

    task run(int n);
        fork
            gen.run(n);
            drv.run(n);
            mon.run(n);
            sb.run(n);
        join
    endtask
endclass

module tb_apb;
    localparam int N_TRANS = 60;

    logic PCLK = 1'b0;
    always #5 PCLK = ~PCLK;

    apb_if apb(PCLK);
    apb_ram dut(apb);

    environment env;

    // VCD block for EDA Playground + EPWave.
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_apb);
    end

    initial begin
        // Reset.
        apb.PRESETn = 1'b0;
        apb.PSEL    = 1'b0;
        apb.PENABLE = 1'b0;
        apb.PWRITE  = 1'b0;
        apb.PADDR   = '0;
        apb.PWDATA  = '0;

        repeat (3) @(posedge PCLK);
        @(negedge PCLK);
        apb.PRESETn = 1'b1;

        env = new(apb);
        env.run(N_TRANS);

        $display("\n========================================");
        $display("TASK 2 SCOREBOARD: PASS=%0d FAIL=%0d",
                 env.sb.pass_count, env.sb.fail_count);
        $display("FUNCTIONAL COVERAGE = %0.2f%%", env.mon.coverage());
        $display("========================================\n");

        #20;
        $finish;
    end
endmodule
