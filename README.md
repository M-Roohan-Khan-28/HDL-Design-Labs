# HDL labs

A collection of Verilog/SystemVerilog exercises from my digital-design coursework. Each project keeps its RTL, testbench, and simulation entry point together.

- [Eight-operation ALU](projects/alu/README.md)
- [APB RAM with a SystemVerilog interface](projects/apb-interface/README.md)
- [APB RAM using interface modports](projects/apb-modports/README.md)
- [AHB-Lite RAM](projects/ahb-lite-ram/README.md)
- [Two-way set-associative cache](projects/two-way-cache/README.md)
- [VGA controller with SRAM framebuffer](projects/vga-sram/README.md)

These six exercises were located in the available source folders. The remaining tasks from the planned set of roughly 16 have not been identified yet.

Four testbenches passed their supplied checks with ModelSim Starter. Two require
a Questa verification license. See [validation results](VALIDATION.md) for the
counts, limitations, and the small VGA compatibility fix.

Use ModelSim/Questa with SystemVerilog support. Run each project separately: some exercises intentionally reuse interface names. Packaging does not establish protocol compliance or coverage closure.
