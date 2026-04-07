`ifndef RKV_AXIRAM_PKG_SV
`define RKV_AXIRAM_PKG_SV

package rkv_axiram_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import lvc_axi_pkg::*;

  `include "rkv_axiram_reg.sv"
  `include "rkv_axiram_config.sv"
  `include "rkv_axiram_reg_adapter.sv"
  `include "rkv_axiram_subscriber.sv"
  `include "rkv_axiram_cov.sv"
  `include "rkv_axiram_scoreboard.sv"
  `include "rkv_axiram_virtual_sequencer.sv"
  `include "rkv_axiram_env.sv"
  `include "rkv_axiram_seq_lib.svh"
  `include "rkv_axiram_tests.svh"

endpackage

`endif // RKV_AXIRAM_PKG_SV
