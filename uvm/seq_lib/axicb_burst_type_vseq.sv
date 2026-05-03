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
        fixed_type_wr_rd(BURST_LEN_SINGLE);
        fixed_type_wr_rd(BURST_LEN_2BEATS);
        fixed_type_wr_rd(BURST_LEN_4BEATS);
        fixed_type_wr_rd(BURST_LEN_8BEATS);
        fixed_type_wr_rd(BURST_LEN_16BEATS);
        //INCR
        incr_type_wr_rd(BURST_LEN_SINGLE);
        incr_type_wr_rd(BURST_LEN_2BEATS);
        incr_type_wr_rd(BURST_LEN_4BEATS);
        incr_type_wr_rd(BURST_LEN_8BEATS);
        incr_type_wr_rd(BURST_LEN_16BEATS);
        //WRAP 0/4/8/C 10/14/18/1C 20/24/28/2C 30/34/38/3C
        wrap_type_wr_rd(BURST_LEN_2BEATS, s1_base_addr);
        wrap_type_wr_rd(BURST_LEN_4BEATS, s1_base_addr + 32'hC);
        wrap_type_wr_rd(BURST_LEN_8BEATS, s1_base_addr + 32'h1C);
        wrap_type_wr_rd(BURST_LEN_16BEATS, s1_base_addr + 32'h3C);
    endtask

    
endclass

`endif 
