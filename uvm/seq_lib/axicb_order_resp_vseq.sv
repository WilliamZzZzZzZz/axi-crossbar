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

        same_id_same_slave_write_outstanding_accept();

        `uvm_info(get_type_name(), "========== order_resp_test_end ==========", UVM_LOW)
    endtask

    local task same_id_same_slave_write_outstanding_accept();
        set_slave_b_resp_delay(0, 100);
        fork
            expect_upstream_outstanding_depth(WRITE, 0, 4);
            begin
                do_nblock_write(0, s0_base_addr, BURST_LEN_16BEATS, INCR, BURST_SIZE_4BYTES, 8'hBE);
                do_nblock_write(0, s0_base_addr, BURST_LEN_16BEATS, INCR, BURST_SIZE_4BYTES, 8'hBE);
                do_nblock_write(0, s0_base_addr, BURST_LEN_16BEATS, INCR, BURST_SIZE_4BYTES, 8'hBE);
                do_nblock_write(0, s0_base_addr, BURST_LEN_16BEATS, INCR, BURST_SIZE_4BYTES, 8'hBE);
            end
        join
        clear_slave_b_resp_delay(0);
    endtask

endclass

`endif 
