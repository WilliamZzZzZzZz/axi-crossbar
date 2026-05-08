`ifndef AXICB_CONC_ARB_VSEQ_SV
`define AXICB_CONC_ARB_VSEQ_SV

class axicb_conc_arb_vseq extends axicb_conc_base_vseq;
    `uvm_object_utils(axicb_conc_arb_vseq)      

    function new(string name = "axicb_conc_arb_vseq");
        super.new(name);
    endfunction

    virtual task body();
        super.body();
        `uvm_info(get_type_name(), "========== conc_arb_test_start ==========", UVM_LOW)

        same_slv_write_contention();
        same_slv_read_contention();

        `uvm_info(get_type_name(), "========== conc_arb_range_test_end ==========", UVM_LOW)
    endtask

    local task same_slv_write_contention();
        fork
            expect_same_slave_aw_contention(0);
            expect_downstream_w_burst_integrity(0);
            do_legal_write(0, s0_base_addr, BURST_LEN_16BEATS, INCR, BURST_SIZE_4BYTES, 8'hCD);
            do_legal_write(1, s0_mid_addr, BURST_LEN_16BEATS, INCR, BURST_SIZE_4BYTES, 8'hCD);
        join
    endtask

    local task same_slv_read_contention();
        fork
            expect_same_slave_ar_contention(1);
            expect_downstream_w_burst_integrity(1);
            do_legal_read(0, s1_base_addr, BURST_LEN_4BEATS, INCR, BURST_SIZE_4BYTES, 8'hAC);
            do_legal_read(1, s1_mid_addr, BURST_LEN_4BEATS, INCR, BURST_SIZE_4BYTES, 8'hAC);
        join
    endtask


endclass

`endif 
