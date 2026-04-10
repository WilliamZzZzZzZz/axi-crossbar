`ifndef AXIRAM_PKG_SV
`define AXIRAM_PKG_SV

package axiram_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import axi_pkg::*;

    `include "axiram_virtual_sequencer.sv"
    `include "axiram_scoreboard.sv"
    `include "axiram_coverage.sv"
    `include "axi_crossbar_env.sv"
    `include "axiram_virt_seq_lib.svh"
    `include "axiram_tests_lib.svh"
    

endpackage

`endif 