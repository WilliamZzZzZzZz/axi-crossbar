`ifndef LVC_AXI_DRIVER_SV
`define LVC_AXI_DRIVER_SV

class lvc_axi_driver #(type REQ = lvc_axi_transaction, type RSP = REQ) extends uvm_driver #(REQ, RSP);

  `uvm_component_param_utils(lvc_axi_driver#(REQ, RSP))

  function new(string name = "lvc_axi_driver", uvm_component parent = null);
    super.new(name, parent);
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

`endif // LVC_AXI_DRIVER_SV
