`ifndef AXI_MASTER_SEQUENCER_SV
`define AXI_MASTER_SEQUENCER_SV

class axi_master_sequencer extends uvm_sequencer #(axi_transaction);
    `uvm_component_utils(axi_master_sequencer)

    axi_configuration                       cfg;
    virtual axi_if#(.ID_WIDTH(ID_WIDTH))    vif;

    function new(string name = "axi_master_sequencer", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
    endfunction

endclass

`endif 