`ifndef AXIRAM_VIRTUAL_SEQUENCER_SV
`define AXIRAM_VIRTUAL_SEQUENCER_SV

class axiram_virtual_sequencer extends uvm_sequencer;
    `uvm_component_utils(axiram_virtual_sequencer)

    axi_master_sequencer axi_mst_sqr[2];

    function new(string name = "axiram_virtual_sequencer", uvm_component parent = null);
        super.new(name, parent);
    endfunction

endclass

`endif
