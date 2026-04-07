`ifndef LVC_AXI_PKG_SV
`define LVC_AXI_PKG_SV

package lvc_axi_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  `include "lvc_axi_defines.svh"
  `include "lvc_axi_types.sv"
  `include "lvc_axi_agent_configuration.sv"
  `include "lvc_axi_transaction.sv"
  `include "lvc_axi_sequencer.sv"
  `include "lvc_axi_driver.sv"
  `include "lvc_axi_monitor.sv"
  `include "lvc_axi_master_transaction.sv"
  `include "lvc_axi_master_driver.sv"
  `include "lvc_axi_master_monitor.sv"
  `include "lvc_axi_master_sequencer.sv"
  `include "lvc_axi_master_agent.sv"

endpackage

`endif // LVC_AXI_PKG_SV
