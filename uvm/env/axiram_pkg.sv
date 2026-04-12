`ifndef AXICB_PKG_SV
`define AXICB_PKG_SV

package axicb_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import axi_pkg::*;

    `include "axicb_virtual_sequencer.sv"
    `include "axicb_scoreboard.sv"
    `include "axicb_coverage.sv"
    `include "axi_crossbar_env.sv"
    `include "axiram_virt_seq_lib.svh"
    `include "axiram_tests_lib.svh"
    

endpackage

`endif 