`ifndef AXICB_BURST_BASE_VSEQ_SV
`define AXICB_BURST_BASE_VSEQ_SV

class axicb_burst_base_vseq extends axicb_base_vseq;

    `uvm_object_utils(axicb_burst_base_vseq)

    function new(string name = "axicb_burst_base_vseq");
        super.new(name);
    endfunction

    protected task fixed_type_wr_rd(burst_len_enum burst_len);
        do_legal_write(1, s1_base_addr, burst_len, FIXED, BURST_SIZE_4BYTES, 8'hAC);
        do_legal_read(1, s1_base_addr, burst_len, FIXED, BURST_SIZE_4BYTES, 8'hAC);
    endtask

    protected task incr_type_wr_rd(burst_len_enum burst_len);
        do_legal_write(1, s1_mid_addr, burst_len, INCR, BURST_SIZE_4BYTES, 8'hAB);
        do_legal_read(1, s1_mid_addr, burst_len, INCR, BURST_SIZE_4BYTES, 8'hAB);
    endtask

    protected task wrap_type_wr_rd(burst_len_enum burst_len, bit [ADDR_WIDTH - 1:0] addr);
        do_legal_write(1, addr, burst_len, WRAP, BURST_SIZE_4BYTES, 8'hAD);
        do_legal_read(1, addr, burst_len, WRAP, BURST_SIZE_4BYTES, 8'hAD);
    endtask
    

endclass

`endif 
