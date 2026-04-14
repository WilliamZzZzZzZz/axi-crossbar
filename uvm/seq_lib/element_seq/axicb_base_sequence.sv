`ifndef AXICB_BASE_SEQUENCE_SV
`define AXICB_BASE_SEQUENCE_SV

class axicb_base_sequence extends uvm_sequence;
    `uvm_object_utils(axicb_base_sequence)
    bit[31:0] wr_val, rd_val;

    `uvm_declare_p_sequencer(axicb_virtual_sequencer)

    rand int unsigned src_master_idx;
    constraint src_master_idx_c { src_master_idx inside {0, 1}; }

    function new(string name = "axicb_base_sequence");
        super.new(name);
    endfunction

    virtual task body();
        `uvm_info(get_type_name(), "entering...", UVM_LOW)

        `uvm_info(get_type_name(), "exiting...", UVM_LOW)
    endtask
endclass

`endif 