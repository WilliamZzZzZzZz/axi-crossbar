`ifndef LVC_AXI_MASTER_SEQUENCER_SV
`define LVC_AXI_MASTER_SEQUENCER_SV

class lvc_axi_master_sequencer extends lvc_axi_sequencer #(lvc_axi_master_transaction);

  lvc_axi_agent_configuration cfg;
  virtual lvc_axi_if vif;

  `uvm_component_utils(lvc_axi_master_sequencer)

  function new(string name = "lvc_axi_master_sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
  endfunction

endclass

`endif // LVC_AXI_MASTER_SEQUENCER_SV
