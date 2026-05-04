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
        burst_foundation_3type(BURST_SIZE_4BYTES);
        foundation_3type_size(BURST_LEN_4BEATS);

        `uvm_info(get_type_name(), "========== axicb_burst_type_test_start ==========", UVM_LOW)
    endtask

    local task burst_foundation_3type(burst_size_enum burst_size);
        //FIXED
        fixed_type_wr_rd(BURST_LEN_SINGLE, burst_size);
        fixed_type_wr_rd(BURST_LEN_2BEATS, burst_size);
        fixed_type_wr_rd(BURST_LEN_4BEATS, burst_size);
        fixed_type_wr_rd(BURST_LEN_8BEATS, burst_size);
        fixed_type_wr_rd(BURST_LEN_16BEATS, burst_size);
        //INCR
        incr_type_wr_rd(BURST_LEN_SINGLE, burst_size);
        incr_type_wr_rd(BURST_LEN_2BEATS, burst_size);
        incr_type_wr_rd(BURST_LEN_4BEATS, burst_size);
        incr_type_wr_rd(BURST_LEN_8BEATS, burst_size);
        incr_type_wr_rd(BURST_LEN_16BEATS, burst_size);
        //WRAP 0/4/8/C 10/14/18/1C 20/24/28/2C 30/34/38/3C
        wrap_type_wr_rd(BURST_LEN_2BEATS, s1_base_addr, burst_size);
        wrap_type_wr_rd(BURST_LEN_4BEATS, s1_base_addr + 32'hC, burst_size);
        wrap_type_wr_rd(BURST_LEN_8BEATS, s1_base_addr + 32'h1C, burst_size);
        wrap_type_wr_rd(BURST_LEN_16BEATS, s1_base_addr + 32'h3C, burst_size);
    endtask

    local task foundation_3type_size(burst_len_enum burst_len);
        //FIXED
        fixed_type_wr_rd(burst_len, BURST_SIZE_1BYTE);
        fixed_type_wr_rd(burst_len, BURST_SIZE_2BYTES);
        fixed_type_wr_rd(burst_len, BURST_SIZE_4BYTES);
        //INCR
        incr_type_wr_rd(burst_len, BURST_SIZE_1BYTE);
        incr_type_wr_rd(burst_len, BURST_SIZE_2BYTES);
        incr_type_wr_rd(burst_len, BURST_SIZE_4BYTES);
        //WRAP
        wrap_type_wr_rd(burst_len, s1_mid_addr, BURST_SIZE_1BYTE);
        wrap_type_wr_rd(burst_len, s1_mid_addr, BURST_SIZE_2BYTES);
        wrap_type_wr_rd(burst_len, s1_mid_addr, BURST_SIZE_4BYTES);
    endtask
    
endclass

`endif 
