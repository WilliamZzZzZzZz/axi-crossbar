`ifndef AXICB_ORDER_RESP_VSEQ_SV
`define AXICB_ORDER_RESP_VSEQ_SV

class axicb_order_resp_vseq extends axicb_conc_base_vseq;
    `uvm_object_utils(axicb_order_resp_vseq)      

    function new(string name = "axicb_order_resp_vseq");
        super.new(name);
    endfunction

    virtual task body();
        super.body();
        `uvm_info(get_type_name(), "========== order_resp_test_start ==========", UVM_LOW)

        threads_depth_test();
        outstanding_depth_test();

        `uvm_info(get_type_name(), "========== order_resp_test_end ==========", UVM_LOW)
    endtask

    //outstanding depth = min(S_ACCEPT=16, M_ISSUE=4), so test depth 4 is enough
    local task outstanding_depth_test();
        same_id_same_slave_write_outstanding_accept(4);
        same_id_same_slave_read_outstanding_accept(4);
    endtask

    //S_THREADS=2, means upstream's slave port max allow 2 different ID transaction concurrently
    local task threads_depth_test();
        unique_id_thread_write(2);
        unique_id_thread_read(2);
    endtask

    local task same_id_same_slave_write_outstanding_accept(int unsigned tested_depth);
        set_slave_b_resp_delay(0, 100);
        fork
            expect_upstream_outstanding_depth(WRITE, 0, tested_depth);
            repeat(tested_depth) begin
                do_nblock_write(0, s0_base_addr, BURST_LEN_4BEATS, INCR, BURST_SIZE_4BYTES, 8'hBE);
            end
        join
        clear_slave_b_resp_delay(0);
    endtask

    local task same_id_same_slave_read_outstanding_accept(int unsigned tested_depth);
        set_slave_r_resp_delay(1, 150);
        fork
            expect_upstream_outstanding_depth(READ, 1, tested_depth);
            repeat(tested_depth) begin
                do_nblock_read(1, s1_mid_addr, BURST_LEN_4BEATS, INCR, BURST_SIZE_4BYTES, 8'hCD);
            end
        join
        clear_slave_r_resp_delay(1);
    endtask

    local task unique_id_thread_write(int unsigned test_threads);
        set_slave_b_resp_delay(0, 100);
        fork
            expect_upstream_unique_id_threads(WRITE, 0, test_threads);
            begin
                do_nblock_write(0, s0_mid_addr, BURST_LEN_4BEATS, INCR, BURST_SIZE_4BYTES, 8'hA1);
                do_nblock_write(0, s0_mid_addr, BURST_LEN_4BEATS, INCR, BURST_SIZE_4BYTES, 8'hA2);
            end
        join
        clear_slave_b_resp_delay(0);
    endtask

    local task unique_id_thread_read(int unsigned test_threads);
        set_slave_r_resp_delay(1, 100);
        fork
            expect_upstream_unique_id_threads(READ, 1, test_threads);
            begin
                do_nblock_read(1, s1_mid_addr, BURST_LEN_4BEATS, INCR, BURST_SIZE_4BYTES, 8'hA3);
                do_nblock_read(1, s1_mid_addr, BURST_LEN_4BEATS, INCR, BURST_SIZE_4BYTES, 8'hA4);
            end
        join
        clear_slave_r_resp_delay(1);
    endtask

endclass

`endif 