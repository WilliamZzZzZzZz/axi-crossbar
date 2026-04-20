`ifndef AXICB_DECERR_VIRT_SEQ_SV
`define AXICB_DECERR_VIRT_SEQ_SV

class axicb_decerr_virt_seq extends axicb_base_virtual_sequence;

    `uvm_object_utils(axicb_decerr_virt_seq)

    function new(string name = "axicb_decerr_virt_seq");
        super.new(name);
    endfunction

    virtual task body();
        super.body();
        `uvm_info(get_type_name(), "========== decerr_test_start ==========", UVM_LOW)
        decerr_write_test(0);
        decerr_write_test(1);
        `uvm_info(get_type_name(), "========== decerr_test_end ============", UVM_LOW)
    endtask

    virtual task decerr_write_test(int unsigned mst_idx);
        bit [31:0] decerr_addr;
        bit [31:0] wr_data;
        bit [31:0] wr_data_arr[];
        bit [3:0]  wr_strb_arr[];
        int unsigned txn_per_path;     //txn number of every specific path

        bit downstream_leak = 0;
        bit monitor_enable  = 1;
        int unsigned monitor_cycle_count = 0; 

        if(vif_mst00.arst === 1'b1) @(negedge vif_mst00.arst);
        wait_cycles(5);

        //txn_per_path randomization
        if(!std::randomize(txn_per_path) with {
            txn_per_path inside {[2:10]};
        }) `uvm_fatal(get_type_name(), "'txn_per_path' randomization FAILED!")

        `uvm_info(get_type_name(), $sformatf("master%0d DECERR test, txn_num: %0d transactions", mst_idx, txn_per_path), UVM_LOW)

        fork
            begin: decerr_write_thread
                for(int i = 0; i < txn_per_path; i++) begin
                    //decerr addr randomization
                    if(!std::randomize(decerr_addr) with {
                        decerr_addr >= 32'h0002_0000;
                        decerr_addr <= 32'hFFFF_FFFF;
                    }) `uvm_fatal(get_type_name(), "decerr addr randomization FAILED!")
                    //data randomization
                    if(!std::randomize(wr_data)) 
                        `uvm_fatal(get_type_name(), "data randomization FAILED!")          
                
                    wr_data_arr     = new[1];
                    wr_strb_arr     = new[1];
                    wr_data_arr[0]  = wr_data;
                    wr_strb_arr[0]  = 4'hF;   

                    //============= write ===============//
                    single_write = axicb_single_write_sequence::type_id::create("single_write");
                    single_write.src_master_idx     = mst_idx;
                    single_write.addr               = decerr_addr;
                    single_write.data               = wr_data;
                    single_write.burst_len          = BURST_LEN_SINGLE;
                    single_write.burst_type         = INCR;
                    single_write.burst_size         = BURST_SIZE_4BYTES;
                    single_write.every_beat_data    = wr_data_arr;
                    single_write.every_beat_wstrb   = wr_strb_arr;
                    single_write.wait_for_response  = 1;
                    single_write.expect_decerr      = 1;
                    single_write.start(p_sequencer);      

                    //check DECERR bresp
                    if(single_write.bresp == DECERR)
                        `uvm_info(get_type_name(), $sformatf("master%0d -> DECERR_ADDR: %08h, resp PASSED!", mst_idx, decerr_addr), UVM_LOW)
                    else 
                        `uvm_error(get_type_name(), $sformatf("expect return DECERR, but bresp: %02b, DECERR_ADDR: %08h", single_write.bresp, decerr_addr))                 
                end
                monitor_enable = 0;     //when write_decerr thread END, monitor thread also END! 
            end
            begin: leak_monitor_thread
                while(monitor_enable) begin
                    @(posedge vif_slv00.aclk);
                    monitor_cycle_count++;
                    if(monitor_enable == 0) break;
                    if(vif_slv00.arst === 1'b1) continue;
                    check_one_ds_write_port(vif_slv00, downstream_leak);
                    check_one_ds_write_port(vif_slv01, downstream_leak);
                end
            end
        join

        //downstream_leak check
        if(downstream_leak == 0)
            `uvm_info(get_type_name(), $sformatf("master%0d DECERR-write, downstream isolation PASSED!(%0d cycles monitored)", mst_idx, monitor_cycle_count), UVM_LOW)
        else
            `uvm_error(get_type_name(), $sformatf("master%0d DECERR-write, downstream isolation FAILED!(illegal data and addr leak into downstream)", mst_idx))

    endtask

    local task automatic check_one_ds_write_port(
        virtual axi_if#(.ID_WIDTH(M_ID_WIDTH)) vif_slv,
        ref bit downstream_leak
    );
        //AWVALID check
        if(vif_slv.awvalid === 1'b1) begin
            `uvm_error(get_type_name(), $sformatf("downstream LEAK when decerr! awvalid=1, awaddr: %08h, awid: %09h", vif_slv.awaddr, vif_slv.awid))
            downstream_leak = 1;
        end
        //WVALID check
        if(vif_slv.wvalid === 1'b1) begin
            `uvm_error(get_type_name(), $sformatf("downstream LEAK when decerr! wvalid=1, wdata: %08h", vif_slv.wdata))
            downstream_leak = 1;
        end
    endtask
    

endclass

`endif 