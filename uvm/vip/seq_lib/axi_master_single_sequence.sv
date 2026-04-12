`ifndef AXI_MASTER_SINGLE_SEQUENCE_SV
`define AXI_MASTER_SINGLE_SEQUENCE_SV

class axi_master_single_sequence extends axi_base_sequence;
    `uvm_object_utils(axi_master_single_sequence)

    rand bit [ADDR_WIDTH - 1:0] addr;
    rand bit [DATA_WIDTH - 1:0] data;
    rand trans_type_enum trans_type;
    rand burst_len_enum burst_len;
    rand burst_type_enum burst_type;
    rand burst_size_enum burst_size = BURST_SIZE_4BYTES;

    //tr_varibles are only use for tranasction's transfermation
    //no present any real signals
    rand bit [ID_WIDTH - 1:0]       tr_id = '0;
    rand bit [QOS_WIDTH - 1:0]      tr_qos = '0;
    rand bit [REGION_WIDTH - 1:0]   tr_region = '0;
    rand bit [AWUSER_WIDTH - 1:0]   tr_awuser = '0;
    rand bit [ARUSER_WIDTH - 1:0]   tr_aruser = '0;

    bit [DATA_WIDTH - 1:0] every_beat_data[];   //store every beat's data
    bit [STRB_WIDTH - 1:0] every_beat_wstrb[];

    //control sequence whether blocking wait for driver's response
    //default-mode:  1(blocking)
    //pipeline-mode: 0(non-blocking)
    bit wait_for_response = 1;

    constraint single_trans_type_cstr {
        trans_type inside {READ, WRITE};
    }

    function new(string name = "axi_master_single_sequence");
        super.new(name);
    endfunction
    
    virtual task body();
        `uvm_info(get_type_name(), "started sequence", UVM_LOW)
        //under pipeline-mode
        if(!wait_for_response) begin
            set_response_queue_error_report_disabled(1);
        end
        if(trans_type == WRITE) begin
            do_write();
        end else begin
            do_read();
        end
    endtask

    virtual task do_write();
        int actual_beats = burst_len + 1;

        if(every_beat_data.size() != actual_beats) begin
            every_beat_data = new[actual_beats];
            every_beat_data[0] = data;
            for(int i = 1; i < actual_beats; i ++) begin
                every_beat_data[i] = 0;
            end
        end

        req = axi_transaction::type_id::create("req");
        start_item(req);

        if(!req.randomize() with {
            trans_type      == WRITE;
            awid            == local::tr_id;                  //smoke test only
            awaddr          == local::addr;
            awlen           == local::burst_len;
            awsize          == local::burst_size;
            awburst         == local::burst_type;
            awlock          == NORMAL;
            awcache         == NONBUFFER;
            awprot          == NPRI_SEC_DATA;
            awqos           == local::tr_qos;
            awregion        == local::tr_region;
            awuser          == local::tr_awuser;
            wdata.size()    == local::actual_beats;
            wstrb.size()    == local::actual_beats;            
        }) begin
            `uvm_fatal(get_type_name(), "randomize failed in vip-write-transaction")
        end

        foreach(every_beat_data[i]) begin
            req.wdata[i] = every_beat_data[i];
            //use custom value if have defined, otherwise use 4'hF
            req.wstrb[i] = (every_beat_wstrb.size() > i) ? every_beat_wstrb[i] : 4'hF;
        end
        
        req.response_requested = wait_for_response;
        finish_item(req);

        //blocking
        if(wait_for_response) begin
            get_response(rsp);

            //id set 0 in smoke test, so no need to check id temporarily
            //check response
            if(rsp.bresp == OKAY) begin
                `uvm_info(get_type_name(), $sformatf("write complete: ADDR=%0h DATA=%0h", addr, data), UVM_MEDIUM)
            end else begin
                `uvm_error(get_type_name(), $sformatf("write error: ADDR=%0h DATA=%0h", addr, data))
            end
        end
        //non-blocking, finish_item return and immediately finish
        //sequence dont wait B channel finish, and send next transaction immediately
    endtask

    virtual task do_read();
        int actual_beats = burst_len + 1;

        req = axi_transaction::type_id::create("req");
        start_item(req);

        if(!req.randomize() with {
            trans_type  == READ;
            arid        == local::tr_id;
            araddr      == local::addr;
            arlen       == local::burst_len;
            arsize      == local::burst_size;
            arburst     == local::burst_type;
            arlock      == NORMAL;
            arcache     == NONBUFFER;
            arprot      == NPRI_SEC_DATA;
            arqos       == local::tr_qos;
            arregion    == local::tr_region;
            aruser      == local::tr_aruser;
        }) begin
            `uvm_fatal(get_type_name(), "randomize failed in vip-write-transaction")
        end
        
        req.response_requested = wait_for_response;
        finish_item(req);

        //blocking
        if(wait_for_response) begin
            get_response(rsp);

            every_beat_data = new[actual_beats];
            foreach(every_beat_data[i]) begin
                every_beat_data[i] = rsp.rdata[i];
            end

            data = every_beat_data[0];

            //id set 0 in smoke test, so no need to check id temporarily
            //check response
            if(rsp.rresp[0] == OKAY) begin
                data =rsp.rdata[0];
                `uvm_info(get_type_name(), $sformatf("read complete: ADDR=%0h DATA=%0h", addr, data), UVM_MEDIUM)
            end else begin
                `uvm_error(get_type_name(), $sformatf("read error: ADDR=%0h DATA=%0h", addr, data))
            end
        end
    endtask
endclass

`endif 