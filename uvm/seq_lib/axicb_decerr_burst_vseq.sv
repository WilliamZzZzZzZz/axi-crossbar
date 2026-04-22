`ifndef AXICB_DECERR_BURST_VSEQ_SV
`define AXICB_DECERR_BURST_VSEQ_SV

class axicb_decerr_burst_vseq extends axicb_base_virtual_sequence;

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

        `uvm_info(get_type_name(), "========== decerr_test_start ==========", UVM_LOW)
        decerr_burst_test(0, WRITE, burst_len[0]);
        decerr_burst_test(0, READ, burst_len[1]);
        decerr_burst_test(1, WRITE, burst_len[2]);
        decerr_burst_test(1, READ, burst_len[3]);
        `uvm_info(get_type_name(), "========== decerr_test_end ============", UVM_LOW)
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
                        WRITE:  decerr_burst_write(mst_idx, decerr_addr, burst_len);
                        READ:   decerr_burst_read(mst_idx, decerr_addr, burst_len);
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

    local task decerr_burst_write(int unsigned mst_idx, bit [ADDR_WIDTH - 1:0] addr, burst_len_enum burst_len);
        int unsigned beat_num = int'(burst_len) + 1;  

        single_write = axicb_single_write_sequence::type_id::create("single_write");
        single_write.src_master_idx     = mst_idx;
        single_write.addr               = addr;
        single_write.burst_len          = burst_len;
        single_write.burst_type         = INCR;
        single_write.burst_size         = BURST_SIZE_4BYTES;
        single_write.wait_for_response  = 1;
        single_write.expect_decerr      = 1;

        randomize_write_data(single_write, beat_num);
        single_write.start(p_sequencer);   

        //check DECERR bresp
        if(single_write.bresp == DECERR)
            `uvm_info(get_type_name(), $sformatf("expected decerr write, master%0d -> DECERR_ADDR: %08h, bresp PASSED!", mst_idx, addr), UVM_LOW)
        else 
            `uvm_error(get_type_name(), $sformatf("expect return DECERR, but bresp: %02b, DECERR_ADDR: %08h", single_write.bresp, addr)) 
        //check DECERR awid === bid
        if(single_write.awid == single_write.bid)
            `uvm_info(get_type_name(), "expected decerr write, dut return ID PASSED!", UVM_LOW)
        else
            `uvm_error(get_type_name(), $sformatf("dut return incorrect ID, awid = %08b, bid = %08b", single_write.awid, single_write.bid))
    endtask

    local task randomize_write_data(axicb_single_write_sequence seq, int unsigned beat_num);
        bit [DATA_WIDTH - 1:0] rand_data;
        seq.every_beat_data  = new[beat_num];
        seq.every_beat_wstrb = new[beat_num];

        foreach(seq.every_beat_data[i]) begin
            if(!std::randomize(rand_data))
                `uvm_fatal(get_type_name(), "data randomization FAILED!")
                
            seq.every_beat_data[i]  = rand_data;
            seq.every_beat_wstrb[i] = 4'hF;
        end
        seq.data = seq.every_beat_data[0];
    endtask

    local task decerr_burst_read(int unsigned mst_idx, bit [ADDR_WIDTH - 1:0] addr, burst_len_enum burst_len);
        resp_type_enum beat_rresp;

        single_read = axicb_single_read_sequence::type_id::create("single_read");
        single_read.src_master_idx     = mst_idx;
        single_read.addr               = addr;
        single_read.burst_len          = burst_len;
        single_read.burst_type         = INCR;
        single_read.burst_size         = BURST_SIZE_4BYTES;
        single_read.wait_for_response  = 1;
        single_read.expect_decerr      = 1;
        single_read.start(p_sequencer); 

        //chcek DECERR rresp
        foreach(single_read.every_beat_rresp[i]) begin
            beat_rresp = resp_type_enum'(single_read.every_beat_rresp[i]);
            if(single_read.every_beat_rresp[i] == DECERR)
                `uvm_info(get_type_name(), $sformatf("expected decerr read, beat[%0d] rresp = %0s, every beat rresp PASSED!", i, beat_rresp.name()), UVM_LOW)
            else
                `uvm_error(get_type_name(), $sformatf("expect DECERR on beat[%0d] but rresp %0s", i, beat_rresp.name()))
        end
        //check DECERR arid and rid, expect: arid = rid
        if(single_read.arid == single_read.rid)
            `uvm_info(get_type_name(), "expected decerr read, dut return ID PASSED!", UVM_LOW)
        else
            `uvm_error(get_type_name(), $sformatf("dut return incorrect ID, arid = %08b, rid = %08b", single_read.arid, single_read.rid))
    endtask

    local task automatic check_downstream_port(
        trans_type_enum txn_type,
        virtual axi_if#(.ID_WIDTH(M_ID_WIDTH)) vif_slv,
        ref bit downstream_leak
    );
        if(txn_type == WRITE) begin     //WRITE
            //AWVALID check
            if(vif_slv.awvalid === 1'b1) begin
                `uvm_error(get_type_name(), $sformatf("downstream LEAK when decerr_write! awvalid=1, awaddr: %08h, awid: %09h", vif_slv.awaddr, vif_slv.awid))
                downstream_leak = 1;
            end
            //WVALID check
            if(vif_slv.wvalid === 1'b1) begin
                `uvm_error(get_type_name(), $sformatf("downstream LEAK when decerr_write! wvalid=1, wdata: %08h", vif_slv.wdata))
                downstream_leak = 1;
            end
        end
        else begin      //READ
            //ARVALID
            if(vif_slv.arvalid === 1'b1) begin
                `uvm_error(get_type_name(), $sformatf("downstream LEAK when decerr_read! arvalid=1, araddr: %08h, arid: %09h", vif_slv.araddr, vif_slv.arid))
                downstream_leak = 1;
            end
        end
    endtask

endclass

`endif 