`ifndef AXICB_VIRTUAL_SEQUENCER_SV
`define AXICB_VIRTUAL_SEQUENCER_SV

class axicb_virtual_sequencer extends uvm_sequencer;
    `uvm_component_utils(axicb_virtual_sequencer)

    axi_master_sequencer axi_mst_sqr00;
    axi_master_sequencer axi_mst_sqr01;

    function new(string name = "axicb_virtual_sequencer", uvm_component parent = null);
        super.new(name, parent);
    endfunction

endclass

`endif 