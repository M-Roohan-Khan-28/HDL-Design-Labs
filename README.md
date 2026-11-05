# HDL Design and Verification Collection

The original collection of six Verilog/SystemVerilog designs covering arithmetic, APB and AHB-Lite memory interfaces, cache lookup, and VGA timing. Each project keeps its RTL, testbench, simulation entry point, and available evidence together.

- [Eight-operation ALU](projects/alu/README.md)
- [APB RAM with a SystemVerilog interface](projects/apb-interface/README.md)
- [APB RAM using interface modports](projects/apb-modports/README.md)
- [AHB-Lite RAM](projects/ahb-lite-ram/README.md)
- [Two-way set-associative cache](projects/two-way-cache/README.md)
- [VGA controller with SRAM framebuffer](projects/vga-sram/README.md)

The six source projects listed above form this collection. Their standalone versions document subsequent packaging and verification work separately.

Four testbenches passed their supplied checks with ModelSim Starter. Two require
a Questa verification license. See [validation results](VALIDATION.md) for the
counts, limitations, and the small VGA compatibility fix.

Use ModelSim/Questa with SystemVerilog support. Run each project separately: some exercises intentionally reuse interface names. Packaging does not establish protocol compliance or coverage closure.
