`ifndef AXICB_DECERR_SINGLE_VSEQ_SV
`define AXICB_DECERR_SINGLE_VSEQ_SV

class axicb_decerr_single_vseq extends axicb_decerr_base_vseq;

    `uvm_object_utils(axicb_decerr_single_vseq)

    function new(string name = "axicb_decerr_single_vseq");
        super.new(name);
    endfunction

    virtual task body();
        super.body();
        `uvm_info(get_type_name(), "========== decerr_test_start ==========", UVM_LOW)
        decerr_test(0, WRITE);
        decerr_test(0, READ);
        decerr_test(1, WRITE);
        decerr_test(1, READ);
        `uvm_info(get_type_name(), "========== decerr_test_end ============", UVM_LOW)
    endtask

    virtual task decerr_test(int unsigned mst_idx,trans_type_enum txn_type);
        bit [31:0] decerr_addr;
        bit downstream_leak = 0;
        bit monitor_enable  = 1;
        int unsigned monitor_cycle_count = 0; 
        int unsigned txn_per_path;     //txn number of every specific path

        if(vif_mst00.arst === 1'b1) @(negedge vif_mst00.arst);
        wait_cycles(5);

        //txn_per_path randomization
        if(!std::randomize(txn_per_path) with {
            txn_per_path inside {[2:10]};
        }) `uvm_fatal(get_type_name(), "'txn_per_path' randomization FAILED!")

        `uvm_info(get_type_name(), $sformatf("master%0d DECERR test, txn_num: %0d transactions", mst_idx, txn_per_path), UVM_LOW)

        fork
            begin: decerr_thread
                for(int i = 0; i < txn_per_path; i++) begin
                    //decerr addr randomization
                    if(!std::randomize(decerr_addr) with {
                        decerr_addr >= 32'h0002_0000;
                        decerr_addr <= 32'hFFFF_FFFF;
                    }) `uvm_fatal(get_type_name(), "decerr addr randomization FAILED!")
                    case(txn_type)
                        WRITE:  do_decerr_write(
                                                .mst_idx(mst_idx), 
                                                .addr(decerr_addr), 
                                                .burst_len(BURST_LEN_SINGLE), 
                                                .burst_type(INCR), 
                                                .burst_size(BURST_SIZE_4BYTES),
                                                .tr_id('0)
                        );
                        READ:   do_decerr_read(
                                                .mst_idx(mst_idx), 
                                                .addr(decerr_addr),
                                                .burst_len(BURST_LEN_SINGLE),
                                                .burst_type(INCR),
                                                .burst_size(BURST_SIZE_4BYTES),
                                                .tr_id('0)
                        );
                        default: `uvm_fatal(get_type_name(),"no WRITE or READ option")
                    endcase
                end
                monitor_enable = 0;     //when decerr_thread END, monitor_thread also END! 
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
        //downstream_leak check
        if(downstream_leak == 0)
            `uvm_info(get_type_name(), $sformatf("master%0d DECERR-%0s, downstream isolation PASSED!(%0d cycles monitored)", mst_idx, txn_type.name(), monitor_cycle_count), UVM_LOW)
        else
            `uvm_error(get_type_name(), $sformatf("master%0d DECERR-%0s, downstream isolation FAILED!(illegal data and addr leak into downstream)", mst_idx, txn_type.name()))

    endtask

endclass

`endif 