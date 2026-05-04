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
    bit [1:0] write_bresp;
    bit [ID_WIDTH - 1:0] write_bid;
    bit [1:0] read_rresp;
    bit [ID_WIDTH - 1:0] read_rid;
    bit read_rlast;

    //tr_varibles are only use for tranasction's transfermation
    //no present any real signals
    rand bit [ID_WIDTH - 1:0]       tr_id = '0;
    rand bit [QOS_WIDTH - 1:0]      tr_qos = '0;
    rand bit [REGION_WIDTH - 1:0]   tr_region = '0;
    rand bit [AWUSER_WIDTH - 1:0]   tr_awuser = '0;
    rand bit [ARUSER_WIDTH - 1:0]   tr_aruser = '0;

    bit [DATA_WIDTH - 1:0] every_beat_data[];   //store every beat's data
    bit [STRB_WIDTH - 1:0] every_beat_wstrb[];
    bit [ADDR_WIDTH - 1:0] every_beat_addr[];
    bit [1:0]              every_beat_rresp[];

    //control sequence whether blocking wait for driver's response
    //default-mode:  1(blocking)
    //pipeline-mode: 0(non-blocking)
    bit wait_for_response = 1;

    //1: this illegal addr is inserted by decerr_test intentionally, dont print error
    //0: no illegal addr insert, if DUT return DECERR, print error
    bit expect_decerr = 0; 

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
        if(trans_type == WRITE)
            do_write();
        else
            do_read();
    endtask

    virtual task do_write();
        int actual_beats = burst_len + 1;
        every_beat_addr = new[actual_beats];
        
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

        //generate every beat's data and wtrsb
        foreach(every_beat_data[i]) begin
            req.wdata[i] = every_beat_data[i];
            //use custom value if have defined, otherwise use 4'hF
            every_beat_addr[i] = calculate_beat_addr(
                .base_addr(addr),
                .burst_len(burst_len),
                .burst_type(burst_type),
                .burst_size(burst_size),
                .beat_idx(i)
            );
            req.wstrb[i] = calc_strb_by_size(burst_size, every_beat_addr[i]);
            // req.wstrb[i] = (every_beat_wstrb.size() > i) ? every_beat_wstrb[i] : 4'hF;
        end
        
        req.response_requested = wait_for_response;
        finish_item(req);

        //blocking
        if(wait_for_response) begin
            get_response(rsp);
            write_bresp = rsp.bresp;
            write_bid   = rsp.bid;
            //BRESP_CHECK
            if(write_bresp == OKAY)
                `uvm_info(get_type_name(), $sformatf("write complete: ADDR:%0h, DATA:%0h", addr, data), UVM_LOW)
            else if(write_bresp == DECERR && expect_decerr == 1)
                `uvm_info(get_type_name(), $sformatf("write DECERR(expected): ADDR:%0h, DATA:%0h, bresp:%0b", addr, data, write_bresp), UVM_LOW)
            else
                `uvm_error(get_type_name(), $sformatf("write error: ADDR:%0h, DATA:%0h, bresp:%0b",addr, data, write_bresp))
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
            read_rresp = rsp.rresp[0];
            read_rid   = rsp.rid;
            read_rlast = rsp.rlast;

            every_beat_data = new[actual_beats];
            every_beat_rresp = new[actual_beats];
            foreach(every_beat_data[i]) begin
                every_beat_data[i] = rsp.rdata[i];
                every_beat_rresp[i] = rsp.rresp[i];
            end
            data = every_beat_data[0];
            //RRESP_CHECK
            if(read_rresp == OKAY)
                `uvm_info(get_type_name(), $sformatf("read complete: ADDR:%0h, DATA:%0h", addr, data), UVM_LOW)
            else if(read_rresp == DECERR && expect_decerr == 1)
                `uvm_info(get_type_name(), $sformatf("read DECERR(expected): ADDR:%0h, DATA:%0h, rresp:%0b", addr, data, read_rresp), UVM_LOW)
            else
                `uvm_error(get_type_name(), $sformatf("read error: ADDR:%0h, DATA:%0h, rresp:%0b",addr, data, read_rresp))
        end
    endtask

    local function bit [ADDR_WIDTH - 1:0] calculate_beat_addr(
        bit [ADDR_WIDTH - 1:0] base_addr,
        burst_len_enum burst_len,
        burst_type_enum burst_type,
        burst_size_enum burst_size,
        int beat_idx
    );
        int unsigned stride;
        int unsigned total_bytes;
        bit [ADDR_WIDTH-1:0] aligned_start;
        bit [ADDR_WIDTH-1:0] wrap_low;
        bit [ADDR_WIDTH-1:0] offset;
        bit [ADDR_WIDTH-1:0] beat_addr;

        stride = 1 << int'(burst_size);
        aligned_start = (base_addr / stride) * stride;

        case (burst_type)
            FIXED: beat_addr = base_addr;
            INCR:  beat_addr = (beat_idx == 0) ? base_addr : aligned_start + beat_idx * stride;
            WRAP: begin
                total_bytes = (int'(burst_len) + 1) * stride;
                wrap_low = (base_addr / total_bytes) * total_bytes;
                offset = base_addr - wrap_low;
                beat_addr = wrap_low + ((offset + beat_idx * stride) % total_bytes);
            end
            default: begin
                `uvm_error(get_type_name(), $sformatf("illegal burst_type=%0b", burst_type))
                beat_addr = base_addr;
            end
        endcase

        return beat_addr;        
    endfunction

    local function bit [STRB_WIDTH - 1:0] calc_strb_by_size(
        burst_size_enum burst_size,
        bit [ADDR_WIDTH - 1:0] addr
    ); 
        bit [1:0] addr_offset = addr[1:0];
        bit [STRB_WIDTH - 1:0] wstrb;
        case(burst_size)
            BURST_SIZE_1BYTE:
                case(addr_offset)
                    2'b00: wstrb = 4'b0001;
                    2'b01: wstrb = 4'b0010;
                    2'b10: wstrb = 4'b0100;
                    2'b11: wstrb = 4'b1000;
                    default: `uvm_fatal(get_type_name(), "illegal addr_offset!")
                endcase
            BURST_SIZE_2BYTES:
                case(addr_offset)
                    2'b00: wstrb = 4'b0011;
                    2'b10: wstrb = 4'b1100;
                    default: `uvm_fatal(get_type_name(), "illegal addr_offset!")
                endcase
            BURST_SIZE_4BYTES:
                wstrb = 4'b1111;
            default: `uvm_fatal(get_type_name(), "undefined burst_size!")
        endcase
        return wstrb;
    endfunction
endclass

`endif 