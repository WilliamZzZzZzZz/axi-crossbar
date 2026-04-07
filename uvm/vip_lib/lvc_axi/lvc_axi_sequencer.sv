`ifndef LVC_AXI_SEQUENCER_SV
`define LVC_AXI_SEQUENCER_SV

class lvc_axi_sequencer #(type REQ = lvc_axi_transaction, type RSP = REQ) extends uvm_sequencer #(REQ, RSP);

  `uvm_component_param_utils(lvc_axi_sequencer#(REQ, RSP))

  function new(string name = "lvc_axi_sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

endclass

`endif // LVC_AXI_SEQUENCER_SV
