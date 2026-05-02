`ifndef AXICB_BURST_TYPE_VSEQ_SV
`define AXICB_BURST_TYPE_VSEQ_SV

class axicb_burst_type_vseq extends axicb_burst_base_vseq;

    `uvm_object_utils(axicb_burst_type_vseq)

    function new(string name = "axicb_burst_type_vseq");
        super.new(name);
    endfunction
 
    virtual task body();
        super.body();
        `uvm_info(get_type_name(), "========== axicb_burst_type_test_start ==========", UVM_LOW)
        burst_foundation_3type();

        `uvm_info(get_type_name(), "========== axicb_burst_type_test_start ==========", UVM_LOW)
    endtask

    local task burst_foundation_3type();
        //FIXED
        do_legal_write(0, s0_mid_addr, BURST_LEN_4BEATS, FIXED, BURST_SIZE_4BYTES, 8'hAB);
        do_legal_read(0, s0_mid_addr, BURST_LEN_4BEATS, FIXED, BURST_SIZE_4BYTES, 8'hAB);
        //INCR
        do_legal_write(0, s1_mid_addr, BURST_LEN_4BEATS, INCR, BURST_SIZE_4BYTES, 8'hAB);
        do_legal_read(0, s1_mid_addr, BURST_LEN_4BEATS, INCR, BURST_SIZE_4BYTES, 8'hAB);  
        //WRAP
        do_legal_write(0, s1_mid_addr + 32'hC, BURST_LEN_4BEATS, WRAP, BURST_SIZE_4BYTES, 8'hAB);
        do_legal_read(0, s1_mid_addr + 32'hC, BURST_LEN_4BEATS, WRAP, BURST_SIZE_4BYTES, 8'hAB);      
    endtask
    

endclass

`endif 
