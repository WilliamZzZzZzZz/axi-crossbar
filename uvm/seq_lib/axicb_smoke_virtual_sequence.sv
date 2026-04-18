`ifndef AXICB_SMOKE_VIRTUAL_SEQUENCE_SV
`define AXICB_SMOKE_VIRTUAL_SEQUENCE_SV

class axicb_smoke_virtual_sequence extends axicb_base_virtual_sequence;

    `uvm_object_utils(axicb_smoke_virtual_sequence)

    function new(string name = "axicb_smoke_virtual_sequence");
        super.new(name);
    endfunction

    virtual task body();
        super.body();
        `uvm_info(get_type_name(), "========== smoke_test_start ==========", UVM_LOW)
        //every path test
        for(int n = 0; n < 2; n++) begin
            for(int m = 0; m < 2; m++) begin
                write_and_read_test(n,m);
            end
        end
        `uvm_info(get_type_name(), "========== smoke_test_end ============", UVM_LOW)
    endtask

    virtual task write_and_read_test(int unsigned mst_idx, int unsigned slv_idx);
        bit [31:0] rand_addr, base_addr;
        bit [31:0] wr_data;
        bit [31:0] wr_data_arr[];
        bit [3:0]  wr_strb_arr[];
        int unsigned txn_per_path;     //txn number of every specific path

        case(slv_idx)
            0: base_addr = 32'h0000_0000;
            1: base_addr = 32'h0001_0000;
            default: `uvm_fatal(get_type_name(), "undefined slave!")
        endcase

        if(vif_mst00.arst === 1'b1) @(negedge vif_mst00.arst);
        wait_cycles(5);

        //boundary test
        boundary_addr_test(mst_idx, slv_idx, base_addr);
        boundary_addr_test(mst_idx, slv_idx, base_addr + 32'h0000_FFFC);

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
            }) `uvm_fatal(get_type_name(), "address randomization failed!")

            //data randomization
            if(!std::randomize(wr_data)) 
                `uvm_fatal(get_type_name(), "data randomization failed!")          
        
            wr_data_arr     = new[1];
            wr_strb_arr     = new[1];
            wr_data_arr[0]  = wr_data;
            wr_strb_arr[0]  = 4'hF;   

            //============= write ===============//
            single_write = axicb_single_write_sequence::type_id::create("single_write");
            single_write.src_master_idx     = mst_idx;
            single_write.addr               = rand_addr;
            single_write.data               = wr_data;
            single_write.burst_len          = BURST_LEN_SINGLE;
            single_write.burst_type         = INCR;
            single_write.burst_size         = BURST_SIZE_4BYTES;
            single_write.every_beat_data    = wr_data_arr;
            single_write.every_beat_wstrb   = wr_strb_arr;
            single_write.wait_for_response  = 1;
            single_write.start(p_sequencer);      

            //============= read ===============//
            single_read = axicb_single_read_sequence::type_id::create("single_read");
            single_read.src_master_idx      = mst_idx;
            single_read.addr                = rand_addr;
            single_read.burst_len           = BURST_LEN_SINGLE;
            single_read.burst_type          = INCR;
            single_read.burst_size          = BURST_SIZE_4BYTES;
            single_read.wait_for_response   = 1;
            single_read.start(p_sequencer);
            
            //============= compare and check ===============//
            if(compare_single_data(wr_data, single_read.data))
                `uvm_info(get_type_name(), $sformatf("mst %0d to slv %0d write and read PASSED!", mst_idx, slv_idx), UVM_MEDIUM)
            else
                `uvm_error(get_type_name(), $sformatf("mst %0d to slv %0d write and read FAILED!", mst_idx, slv_idx))
            if(single_read.rresp != OKAY)
                `uvm_error(get_type_name(), $sformatf("mst%0d -> slv%0d, txn No.%0d rresp not OKAY: %0b", mst_idx, slv_idx, i, single_read.rresp))                  
            if(single_write.bresp != OKAY)
                `uvm_error(get_type_name(), $sformatf("mst%0d -> slv%0d, txn No.%0d bresp not OKAY: %0b", mst_idx, slv_idx, i, single_write.bresp))                  

        end
    endtask

    virtual task boundary_addr_test(int unsigned mst_idx, int unsigned slv_idx, bit [31:0] boundary_addr);
        bit [31:0] wr_data;
        bit [31:0] wr_data_arr[];
        bit [3:0]  wr_strb_arr[];

        //data randomization
        if(!std::randomize(wr_data))
            `uvm_fatal(get_type_name(), "data randomization failed!")

        wr_data_arr    = new[1];
        wr_strb_arr    = new[1];
        wr_data_arr[0] = wr_data;
        wr_strb_arr[0] = 4'hF;

        //========= write =========//
        single_write = axicb_single_write_sequence::type_id::create("single_write");
        single_write.src_master_idx     = mst_idx;
        single_write.addr               = boundary_addr;
        single_write.data               = wr_data;
        single_write.burst_len          = BURST_LEN_SINGLE;
        single_write.burst_type         = INCR;
        single_write.burst_size         = BURST_SIZE_4BYTES;
        single_write.every_beat_data    = wr_data_arr;
        single_write.every_beat_wstrb   = wr_strb_arr;
        single_write.wait_for_response  = 1;
        single_write.start(p_sequencer);

        //========= read =========//
        single_read = axicb_single_read_sequence::type_id::create("single_read");
        single_read.src_master_idx      = mst_idx;
        single_read.addr                = boundary_addr;
        single_read.burst_len           = BURST_LEN_SINGLE;
        single_read.burst_type          = INCR;
        single_read.burst_size          = BURST_SIZE_4BYTES; 
        single_read.wait_for_response   = 1;
        single_read.start(p_sequencer);

        if(compare_single_data(wr_data, single_read.data))
            `uvm_info(get_type_name(), $sformatf("mst%0d -> slv%0d boundary test PASSED!, addr: %08h", mst_idx, slv_idx, boundary_addr), UVM_LOW)
        else
            `uvm_error(get_type_name(), $sformatf("mst%0d -> slv%0d boundary test FAILED!, addr: %08h", mst_idx, slv_idx, boundary_addr))
    endtask
endclass

`endif 