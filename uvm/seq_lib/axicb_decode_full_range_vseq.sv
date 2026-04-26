`ifndef AXICB_DECODE_FULL_RANGE_VSEQ_SV
`define AXICB_DECODE_FULL_RANGE_VSEQ_SV

class axicb_decode_full_range_vseq extends axicb_decode_base_vseq;
    `uvm_object_utils(axicb_decode_full_range_vseq)

    function new(string name = "axicb_decode_full_range_vseq");
        super.new(name);
    endfunction

    virtual task body();
        super.body();
        `uvm_info(get_type_name(), "========== decode_full_range_test_start ==========", UVM_LOW)

        m0_s0_decode_write();

        `uvm_info(get_type_name(), "========== decode_full_range_test_end ==========", UVM_LOW)
    endtask

    local task m0_s0_decode_write();
        bit ups_decode_error = 0;
        bit downs_decode_error = 0;
        fork
            do_legal_write(0, base_addr, BURST_LEN_SINGLE, INCR, BURST_SIZE_4BYTES, 8'b1111_1111);
            upstream_decode_checker(WRITE, 0, 8'b1111_1111, ups_decode_error);
            downstream_decode_checker(WRITE, 0, base_addr, 8'b1111_1111, downs_decode_error);
        join

        //upstream check
        if(ups_decode_error)
            `uvm_error(get_type_name(), "upstream DECODE ERROR!")
        else 
            `uvm_info(get_type_name(), "upstream DECODE PASSED!", UVM_LOW)
        //downstream check
        if(downs_decode_error)
            `uvm_error(get_type_name(), "downstream DECODE ERROR!")
        else 
            `uvm_info(get_type_name(), "downstream DECODE PASSED!", UVM_LOW)
        
    endtask


endclass

`endif 
