`ifndef AXIRAM_BASE_SEQUENCE_SV
`define AXIRAM_BASE_SEQUENCE_SV

class axiram_base_sequence extends uvm_sequence;
    `uvm_object_utils(axiram_base_sequence)
    bit[31:0] wr_val, rd_val;

    `uvm_declare_p_sequencer(axiram_virtual_sequencer)

    function new(string name = "axiram_base_sequence");
        super.new(name);
    endfunction

    virtual task body();
        `uvm_info(get_type_name(), "entering...", UVM_LOW)

        `uvm_info(get_type_name(), "exiting...", UVM_LOW)
    endtask
endclass

`endif 