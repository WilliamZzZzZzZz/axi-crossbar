`ifndef AXICB_DECERR_BURST_VSEQ_SV
`define AXICB_DECERR_BURST_VSEQ_SV

class axicb_decerr_burst_vseq extends axicb_decerr_base_vseq;

    `uvm_object_utils(axicb_decerr_burst_vseq)

    rand burst_len_enum burst_len[4];

    function new(string name = "axicb_decerr_burst_vseq");
        super.new(name);
    endfunction

    virtual task body();
        super.body();
        if(!std::randomize(burst_len) with {
            unique {burst_len};
        }) `uvm_fatal(get_type_name(), "burst_len, randomization FAILED!")

        `uvm_info(get_type_name(), "========== decerr_burst_test_start ==========", UVM_LOW)
        //decerr burst test
        decerr_burst_test(0, WRITE, burst_len[0]);
        decerr_burst_test(0, READ, burst_len[1]);
        decerr_burst_test(1, WRITE, burst_len[2]);
        decerr_burst_test(1, READ, burst_len[3]);

        //after decerr, assert legal address, test whether DUT recovery from DECERR status 
        after_decerr_test(1, 0);
        after_decerr_test(1, 1);
        after_decerr_test(0, 0);
        after_decerr_test(0, 1);
        `uvm_info(get_type_name(), "========== decerr_burst_test_end ============", UVM_LOW)
    endtask

    virtual task decerr_burst_test(int unsigned mst_idx,trans_type_enum txn_type, burst_len_enum burst_len);
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

        `uvm_info(get_type_name(), $sformatf("master%0d DECERR burst test, burst_len:%0s, txn_num: %0d transactions", mst_idx, burst_len.name(), txn_per_path), UVM_LOW)

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
                                                .burst_len(burst_len),
                                                .burst_type(INCR),
                                                .burst_size(BURST_SIZE_4BYTES),
                                                .tr_id('0)
                                );
                        READ:   do_decerr_read(
                                                .mst_idx(mst_idx),
                                                .addr(decerr_addr), 
                                                .burst_len(burst_len),
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

    local task after_decerr_test(int unsigned mst_idx, int unsigned slv_idx);
        bit [31:0] rand_addr, base_addr;
        int unsigned txn_per_path;
        int unsigned beat_num = int'(BURST_LEN_4BEATS) + 1;

        case(slv_idx)
            0: base_addr = 32'h0000_0000;
            1: base_addr = 32'h0001_0000;
            default: `uvm_fatal(get_type_name(), "indefined slave!")
        endcase

        if(vif_mst00.arst == 1'b1) @(negedge vif_mst00.arst);
        wait_cycles(5);

        //txn_per_path randomization
        if(!std::randomize(txn_per_path) with {
            txn_per_path inside {[2:10]};
        }) `uvm_fatal(get_type_name(), "'txn_per_path' randomization failed!")        

        `uvm_info(get_type_name(), $sformatf("master%0d -> slave%0d : %0d transactions", mst_idx, slv_idx, txn_per_path), UVM_LOW)

        for(int i = 0; i < txn_per_path; i++) begin
            //address randomization
            if(!std::randomize(rand_addr) with {
                rand_addr >= base_addr;
                rand_addr < base_addr + 32'h0001_0000;
                rand_addr[1:0] == 2'b00;
            })  `uvm_fatal(get_type_name(), "address randomization FAILED!")

            //============================= write ===============================//
            single_write = axicb_single_write_sequence::type_id::create("single_write");
            single_write.src_master_idx     = mst_idx;
            single_write.addr               = rand_addr;
            single_write.burst_len          = BURST_LEN_4BEATS;
            single_write.burst_type         = INCR;
            single_write.burst_size         = BURST_SIZE_4BYTES;
            single_write.wait_for_response  = 1;
            single_write.expect_decerr      = 0;

            randomize_write_data(single_write, beat_num);
            single_write.start(p_sequencer);

            //============================== read ================================//
            single_read = axicb_single_read_sequence::type_id::create("single_read");
            single_read.src_master_idx      = mst_idx;
            single_read.addr                = rand_addr;
            single_read.burst_len           = BURST_LEN_4BEATS;
            single_read.burst_type          = INCR;
            single_read.burst_size          = BURST_SIZE_4BYTES;
            single_read.wait_for_response   = 1;
            single_read.expect_decerr       = 0;
            single_read.start(p_sequencer);

            //============================= write check ===============================//
            //check DECERR bresp
            if(single_write.bresp == OKAY)
                `uvm_info(get_type_name(), $sformatf("after decerr write, master%0d -> ADDR: %08h, bresp PASSED!", mst_idx, rand_addr), UVM_LOW)
            else 
                `uvm_error(get_type_name(), $sformatf("expect return OKAY, but bresp: %02b, ADDR: %08h", single_write.bresp, rand_addr)) 
            //check DECERR awid === bid
            if(single_write.awid == single_write.bid)
                `uvm_info(get_type_name(), "after decerr write, dut return ID PASSED!", UVM_LOW)
            else
                `uvm_error(get_type_name(), $sformatf("dut return incorrect ID, awid = %08b, bid = %08b", single_write.awid, single_write.bid))
            //============================= read check ===============================//
            //chcek every beat rresp
            foreach(single_read.every_beat_rresp[i]) begin
                if(single_read.every_beat_rresp[i] == OKAY)
                    `uvm_info(get_type_name(), $sformatf("after decerr read, beat[%0d] rresp = %02b, every beat rresp PASSED!", i, single_read.every_beat_rresp[i]), UVM_LOW)
                else
                    `uvm_error(get_type_name(), $sformatf("expect OKAY on beat[%0d] but rresp %0s", i, single_read.every_beat_rresp[i]))
            end
            //check DECERR arid and rid, expect: arid = rid
            if(single_read.arid == single_read.rid)
                `uvm_info(get_type_name(), "after decerr read, dut return ID PASSED!", UVM_LOW)
            else
                `uvm_error(get_type_name(), $sformatf("dut return incorrect ID, arid = %08b, rid = %08b", single_read.arid, single_read.rid))
            //============================= data compare check ===============================//
            if(compare_data(single_write.every_beat_data, single_read.every_beat_data))
                `uvm_info(get_type_name(), $sformatf("mst %0d to slv %0d write and read PASSED!", mst_idx, slv_idx), UVM_MEDIUM)
            else
                `uvm_error(get_type_name(), $sformatf("mst %0d to slv %0d write and read FAILED!", mst_idx, slv_idx))
            
        end

    endtask

endclass

`endif 