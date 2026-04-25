`ifndef AXICB_DECERR_DUAL_MST_VSEQ_SV
`define AXICB_DECERR_DUAL_MST_VSEQ_SV

class axicb_decerr_dual_mst_vseq extends axicb_decerr_base_vseq;
    `uvm_object_utils(axicb_decerr_dual_mst_vseq)

    function new(string name = "axicb_decerr_dual_mst_vseq");
        super.new(name);
    endfunction

    virtual task body();
        super.body();
        `uvm_info(get_type_name(), "========== decerr_dual_master_test_start ==========", UVM_LOW)

        dual_mst_decerr(WRITE);
        dual_mst_decerr(READ);
        one_decerr_one_legal(WRITE);
        one_decerr_one_legal(READ);
        cross_decerr_wr_legal_rd(0, 1);
        cross_decerr_wr_legal_rd(1, 0);
        cross_decerr_rd_legal_wr(0, 1);
        cross_decerr_rd_legal_wr(1, 0);

        `uvm_info(get_type_name(), "========== decerr_dual_master_test_end ==========", UVM_LOW)
    endtask

    local task dual_mst_decerr(trans_type_enum txn_type);
        bit downstream_leak = 0;
        bit monitor_enable  = 1;
        int unsigned monitor_cycle_count = 0;

        if(vif_mst00.arst === 1'b1) @(negedge vif_mst00.arst);
        wait_cycles(5);

        fork
            begin: dual_master_decerr_threads
                fork
                    begin
                        if(txn_type == WRITE)
                            do_decerr_write(0, 32'hDEAD_0000, BURST_LEN_4BEATS, INCR, BURST_SIZE_4BYTES, 8'h01);
                        else
                            do_decerr_read(0, 32'hDEAD_0000, BURST_LEN_4BEATS, INCR, BURST_SIZE_4BYTES, 8'h01);
                    end
                    begin
                        if(txn_type == WRITE)
                            do_decerr_write(1, 32'hBEEF_0000, BURST_LEN_4BEATS, INCR, BURST_SIZE_4BYTES, 8'h02);
                        else
                            do_decerr_read(1, 32'hBEEF_0000, BURST_LEN_4BEATS, INCR, BURST_SIZE_4BYTES, 8'h02);
                    end
                join
                monitor_enable = 0;
            end

            begin: leak_monitor_thread
                while(monitor_enable) begin
                    @(posedge vif_slv00.aclk);
                    monitor_cycle_count++;
                    if(monitor_enable == 0) break;
                    if(vif_slv00.arst === 1'b1) continue;

                    check_downstream_port(txn_type, vif_slv00, downstream_leak);
                    check_downstream_port(txn_type, vif_slv01, downstream_leak);
                end
            end
        join

        downstream_check_report(downstream_leak);
    endtask

    local task one_decerr_one_legal(trans_type_enum txn_type);
        bit downstream_leak = 0;
        bit monitor_enable  = 1;
        int unsigned monitor_cycle_count = 0;
        bit [ID_WIDTH - 1:0] decerr_id;
        bit [ID_WIDTH - 1:0] legal_id;

        decerr_id = (txn_type == WRITE) ? 8'h01 : 8'h05;
        legal_id  = (txn_type == WRITE) ? 8'h02 : 8'h06;

        if(vif_mst00.arst === 1'b1) @(negedge vif_mst00.arst);
        wait_cycles(5);

        fork
            begin: one_decerr_one_legal_threads
                fork
                    begin
                        if(txn_type == WRITE)
                            do_decerr_write(0, 32'hDEAD_0000, BURST_LEN_4BEATS, INCR, BURST_SIZE_4BYTES, decerr_id);
                        else
                            do_decerr_read(0, 32'hDEAD_0000, BURST_LEN_4BEATS, INCR, BURST_SIZE_4BYTES, decerr_id);
                    end
                    begin
                        if(txn_type == WRITE)
                            do_legal_write(1, 32'h0001_0000, BURST_LEN_4BEATS, INCR, BURST_SIZE_4BYTES, legal_id);
                        else
                            do_legal_read(1, 32'h0001_0000, BURST_LEN_4BEATS, INCR, BURST_SIZE_4BYTES, legal_id);
                    end
                join
                monitor_enable = 0;
            end

            begin: leak_monitor_thread
                while(monitor_enable) begin
                    @(posedge vif_slv00.aclk);
                    monitor_cycle_count++;
                    if(monitor_enable == 0) break;
                    if(vif_slv00.arst === 1'b1) continue;

                    if(txn_type == WRITE) begin
                        check_illegal_aw_leak(vif_slv00, downstream_leak);
                        check_illegal_aw_leak(vif_slv01, downstream_leak);
                    end
                    else begin
                        check_illegal_ar_leak(vif_slv00, downstream_leak);
                        check_illegal_ar_leak(vif_slv01, downstream_leak);
                    end
                end
            end
        join

        downstream_check_report(downstream_leak);
    endtask

    local task cross_decerr_wr_legal_rd(int unsigned decerr_mst_idx, int unsigned legal_mst_idx);
        bit downstream_leak = 0;
        bit monitor_enable  = 1;
        int unsigned monitor_cycle_count = 0;

        if(vif_mst00.arst === 1'b1) @(negedge vif_mst00.arst);
        wait_cycles(5);

        fork
            begin: cross_decerr_write_legal_read_threads
                fork
                    do_decerr_write(decerr_mst_idx, 32'hDEAD_0000, BURST_LEN_4BEATS, INCR, BURST_SIZE_4BYTES, 8'h07);
                    do_legal_read(legal_mst_idx, 32'h0001_0000, BURST_LEN_4BEATS, INCR, BURST_SIZE_4BYTES, 8'h08);
                join
                monitor_enable = 0;
            end

            begin: leak_monitor_thread
                while(monitor_enable) begin
                    @(posedge vif_slv00.aclk);
                    monitor_cycle_count++;
                    if(monitor_enable == 0) break;
                    if(vif_slv00.arst === 1'b1) continue;

                    check_downstream_port(WRITE, vif_slv00, downstream_leak);
                    check_downstream_port(WRITE, vif_slv01, downstream_leak);
                end
            end
        join

        downstream_check_report(downstream_leak);
    endtask

    local task cross_decerr_rd_legal_wr(int unsigned decerr_mst_idx, int unsigned legal_mst_idx);
        bit downstream_leak = 0;
        bit monitor_enable  = 1;
        int unsigned monitor_cycle_count = 0;

        if(vif_mst00.arst === 1'b1) @(negedge vif_mst00.arst);
        wait_cycles(5);

        fork
            begin: cross_decerr_read_legal_write_threads
                fork
                    do_decerr_read(decerr_mst_idx, 32'hBEEF_0000, BURST_LEN_4BEATS, INCR, BURST_SIZE_4BYTES, 8'h09);
                    do_legal_write(legal_mst_idx, 32'h0001_0000, BURST_LEN_4BEATS, INCR, BURST_SIZE_4BYTES, 8'h0A);
                join
                monitor_enable = 0;
            end

            begin: leak_monitor_thread
                while(monitor_enable) begin
                    @(posedge vif_slv00.aclk);
                    monitor_cycle_count++;
                    if(monitor_enable == 0) break;
                    if(vif_slv00.arst === 1'b1) continue;

                    check_downstream_port(READ, vif_slv00, downstream_leak);
                    check_downstream_port(READ, vif_slv01, downstream_leak);
                end
            end
        join

        downstream_check_report(downstream_leak);
    endtask

endclass

`endif 
