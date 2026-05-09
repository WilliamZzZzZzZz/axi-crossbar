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

        arbiter_contention_test();
        round_robin_grant_fairness_test();

        `uvm_info(get_type_name(), "========== conc_arb_test_end ==========", UVM_LOW)
    endtask

    local task arbiter_contention_test();
        same_slv_write_contention(0);
        same_slv_write_contention(1);
        same_slv_read_contention(0);
        same_slv_read_contention(1);
    endtask

    local task round_robin_grant_fairness_test();
        round_robin_write(0, 10);
        round_robin_write(1, 10);    
        round_robin_read(0,10);
        round_robin_read(1,10);
    endtask

    local task same_slv_write_contention(int unsigned tested_slv);
        case(tested_slv)
            0:
                fork
                    expect_same_slave_aw_contention(.slv_idx(0));
                    expect_downstream_w_burst_integrity(.slv_idx(0));
                    do_legal_write(0, s0_base_addr, BURST_LEN_16BEATS, INCR, BURST_SIZE_4BYTES, 8'hCD);
                    do_legal_write(1, s0_mid_addr, BURST_LEN_16BEATS, INCR, BURST_SIZE_4BYTES, 8'hCD);
                join
            1:
                fork
                    expect_same_slave_aw_contention(.slv_idx(1));
                    expect_downstream_w_burst_integrity(.slv_idx(1));
                    do_legal_write(0, s1_base_addr, BURST_LEN_16BEATS, INCR, BURST_SIZE_4BYTES, 8'hCD);
                    do_legal_write(1, s1_mid_addr, BURST_LEN_16BEATS, INCR, BURST_SIZE_4BYTES, 8'hCD);
                join            
        endcase

    endtask

    local task same_slv_read_contention(int unsigned tested_slv);
        case(tested_slv)
            0:
                fork
                    expect_same_slave_ar_contention(.slv_idx(0));
                    expect_downstream_r_burst_integrity(.slv_idx(0));
                    do_legal_read(0, s0_base_addr, BURST_LEN_4BEATS, INCR, BURST_SIZE_4BYTES, 8'hAC);
                    do_legal_read(1, s0_mid_addr, BURST_LEN_4BEATS, INCR, BURST_SIZE_4BYTES, 8'hAC);
                join            
            1:
                fork
                    expect_same_slave_ar_contention(.slv_idx(1));
                    expect_downstream_r_burst_integrity(.slv_idx(1));
                    do_legal_read(0, s1_base_addr, BURST_LEN_4BEATS, INCR, BURST_SIZE_4BYTES, 8'hAC);
                    do_legal_read(1, s1_mid_addr, BURST_LEN_4BEATS, INCR, BURST_SIZE_4BYTES, 8'hAC);
                join   
        endcase
    endtask

    local task round_robin_write(int unsigned tested_slv, int unsigned rounds);
        fork
            expect_downstream_rr_grant_fairness(WRITE, tested_slv, rounds);
            begin
                repeat(rounds)
                    same_slv_write_contention(tested_slv);
            end
        join
    endtask

    local task round_robin_read(int unsigned tested_slv, int unsigned rounds);
        fork
            expect_downstream_rr_grant_fairness(READ, tested_slv, rounds);
            begin
                repeat(rounds)
                    same_slv_read_contention(tested_slv);
            end
        join
    endtask

endclass

`endif 
