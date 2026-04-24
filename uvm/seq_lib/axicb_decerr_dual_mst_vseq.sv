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

        dual_mst_wr_wr();
        dual_mst_rd_rd();

        `uvm_info(get_type_name(), "========== decerr_dual_master_test_end ==========", UVM_LOW)
    endtask

    //dual master decerr write simultaneously
    local task dual_mst_wr_wr();
        bit downstream_leak = 0;
        bit monitor_enable  = 1;
        int unsigned monitor_cycle_count = 0;

        if(vif_mst00.arst === 1'b1) @(negedge vif_mst00.arst);
        wait_cycles(5);

        fork
            begin: decerr_write_threads
                fork
                    do_decerr_write(
                                    .mst_idx(0),
                                    .addr(32'hDEAD_0000),
                                    .burst_len(BURST_LEN_4BEATS),
                                    .burst_type(INCR),
                                    .burst_size(BURST_SIZE_4BYTES),
                                    .tr_id(8'h01)
                    );
                    do_decerr_write(
                                    .mst_idx(1),
                                    .addr(32'hBEEF_0000),
                                    .burst_len(BURST_LEN_4BEATS),
                                    .burst_type(INCR),
                                    .burst_size(BURST_SIZE_4BYTES),
                                    .tr_id(8'h02)
                    );
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

        if(downstream_leak == 0)
            `uvm_info(get_type_name(), $sformatf("dual master DECERR-WR downstream isolation PASSED!(%0d cycles monitored)", monitor_cycle_count), UVM_LOW)
        else
            `uvm_error(get_type_name(), "dual master DECERR-WR downstream isolation FAILED!(illegal write leaked into downstream)")
    endtask

    local task dual_mst_rd_rd();
        bit downstream_leak = 0;
        bit monitor_enable  = 1;
        int unsigned monitor_cycle_count = 0;

        if(vif_mst00.arst === 1'b1) @(negedge vif_mst00.arst);
        wait_cycles(5);

        fork
            begin: dual_master_read_threads
                fork
                    do_decerr_read(
                                    .mst_idx(0),
                                    .addr(32'hDEAD_0000),
                                    .burst_len(BURST_LEN_4BEATS),
                                    .burst_type(INCR),
                                    .burst_size(BURST_SIZE_4BYTES),
                                    .tr_id(8'h01)
                    );
                    do_decerr_read(
                                    .mst_idx(1),
                                    .addr(32'hBEEF_0000),
                                    .burst_len(BURST_LEN_4BEATS),
                                    .burst_type(INCR),
                                    .burst_size(BURST_SIZE_4BYTES),
                                    .tr_id(8'h02)
                    );
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

        if(downstream_leak == 0)
            `uvm_info(get_type_name(), $sformatf("dual master DECERR-RD downstream isolation PASSED!(%0d cycles monitored)", monitor_cycle_count), UVM_LOW)
        else
            `uvm_error(get_type_name(), "dual master DECERR-RD downstream isolation FAILED!(illegal write leaked into downstream)")
    endtask

endclass

`endif 
