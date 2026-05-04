`ifndef AXICB_BURST_BASE_VSEQ_SV
`define AXICB_BURST_BASE_VSEQ_SV

class axicb_burst_base_vseq extends axicb_base_vseq;

    `uvm_object_utils(axicb_burst_base_vseq)

    function new(string name = "axicb_burst_base_vseq");
        super.new(name);
    endfunction

    protected task fixed_type_wr_rd(burst_len_enum burst_len, burst_size_enum burst_size);
        do_legal_write(1, s1_base_addr, burst_len, FIXED, burst_size, 8'hAC);
        do_legal_read(1, s1_base_addr, burst_len, FIXED, burst_size, 8'hAC);
    endtask

    protected task incr_type_wr_rd(burst_len_enum burst_len, burst_size_enum burst_size);
        do_legal_write(1, s1_mid_addr, burst_len, INCR, burst_size, 8'hAB);
        do_legal_read(1, s1_mid_addr, burst_len, INCR, burst_size, 8'hAB);
    endtask

    protected task wrap_type_wr_rd(burst_len_enum burst_len, bit [ADDR_WIDTH - 1:0] addr, burst_size_enum burst_size);
        do_legal_write(1, addr, burst_len, WRAP, burst_size, 8'hAD);
        do_legal_read(1, addr, burst_len, WRAP, burst_size, 8'hAD);
    endtask
    

endclass

`endif 
