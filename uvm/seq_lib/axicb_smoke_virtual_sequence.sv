`ifndef AXICB_SMOKE_VIRTUAL_SEQUENCE_SV
`define AXICB_SMOKE_VIRTUAL_SEQUENCE_SV

class axicb_smoke_virtual_sequence extends axiram_base_virtual_sequence;

    `uvm_object_utils(axicb_smoke_virtual_sequence)

    function new(string name = "axicb_smoke_virtual_sequence");
        super.new(name);
    endfunction

    virtual task body();

    endtask

endclass

`endif 