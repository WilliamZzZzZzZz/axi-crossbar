`ifndef LVC_AXI_MONITOR_SV
`define LVC_AXI_MONITOR_SV

class lvc_axi_monitor extends uvm_monitor;

  // Analysis ports for observed transactions
  uvm_analysis_port #(lvc_axi_transaction) item_observed_port;
  uvm_analysis_port #(lvc_axi_transaction) write_observed_port;
  uvm_analysis_port #(lvc_axi_transaction) read_observed_port;

  `uvm_component_utils(lvc_axi_monitor)

  function new(string name = "lvc_axi_monitor", uvm_component parent = null);
    super.new(name, parent);
    item_observed_port  = new("item_observed_port", this);
    write_observed_port = new("write_observed_port", this);
    read_observed_port  = new("read_observed_port", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
  endfunction

  task run_phase(uvm_phase phase);
    super.run_phase(phase);
  endtask

endclass

`endif // LVC_AXI_MONITOR_SV
