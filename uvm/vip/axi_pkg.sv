`ifndef AXI_PKG_SV
`define AXI_PKG_SV

package axi_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    `include "axi_types.sv"
    `include "axi_configuration.sv"
    `include "axi_transaction.sv"
    `include "axi_sequence_lib.svh"
    `include "axi_write_driver.sv"
    `include "axi_read_driver.sv"
    `include "axi_master_driver.sv"
    `include "axi_master_monitor.sv"
    `include "axi_master_sequencer.sv"
    `include "axi_master_agent.sv"
    
endpackage


`endif 