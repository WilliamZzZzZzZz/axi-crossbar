`ifndef AXICB_DECODE_FULL_RANGE_VSEQ_SV
`define AXICB_DECODE_FULL_RANGE_VSEQ_SV

class axicb_decode_full_range_vseq extends axicb_decerr_base_vseq;
    `uvm_object_utils(axicb_decode_full_range_vseq)

    function new(string name = "axicb_decode_full_range_vseq");
        super.new(name);
    endfunction

    virtual task body();
        super.body();
        `uvm_info(get_type_name(), "========== decode_full_range_test_start ==========", UVM_LOW)


        `uvm_info(get_type_name(), "========== decode_full_range_test_end ==========", UVM_LOW)
    endtask


endclass

`endif 
