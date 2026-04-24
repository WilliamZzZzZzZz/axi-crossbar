`ifndef AXICB_DECERR_BASE_VSEQ_SV
`define AXICB_DECERR_BASE_VSEQ_SV

class axicb_decerr_base_vseq extends axicb_base_vseq;

    `uvm_object_utils(axicb_decerr_base_vseq)

    function new(string name = "axicb_decerr_base_vseq");
        super.new(name);
    endfunction

    protected task automatic randomize_write_data(axicb_single_write_sequence seq, int unsigned beat_num);
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

    protected task automatic do_decerr_write(
        int unsigned mst_idx,
        bit [ADDR_WIDTH - 1:0] addr,
        burst_len_enum burst_len,
        burst_type_enum burst_type,
        burst_size_enum burst_size,
        bit [ID_WIDTH - 1:0] tr_id = '0
    );
        axicb_single_write_sequence wr_seq;
        int unsigned beat_num = int'(burst_len) + 1;
        bit [1:0] bresp;
        bit [ID_WIDTH - 1:0] bid;

        wr_seq = axicb_single_write_sequence::type_id::create("wr_seq");
        wr_seq.src_master_idx     = mst_idx;
        wr_seq.addr               = addr;
        wr_seq.burst_len          = burst_len;
        wr_seq.burst_type         = burst_type;
        wr_seq.burst_size         = burst_size;
        wr_seq.wait_for_response  = 1;
        wr_seq.expect_decerr      = 1;
        wr_seq.awid               = tr_id;
        randomize_write_data(wr_seq, beat_num);
        wr_seq.start(p_sequencer);

        bresp = wr_seq.bresp;
        bid   = wr_seq.bid;

        if(bresp == DECERR)
            `uvm_info(get_type_name(), $sformatf("expected DECERR write: master%0d addr=%08h id=%08h beats=%0d", mst_idx, addr, tr_id, beat_num), UVM_LOW)
        else
            `uvm_error(get_type_name(), $sformatf("expected DECERR write, got bresp=%02b addr=%08h id=%08h", bresp, addr, tr_id))

        if(wr_seq.awid != wr_seq.bid)
            `uvm_error(get_type_name(), $sformatf("expected DECERR write ID FAILED: awid=%08h bid=%08h", wr_seq.awid, wr_seq.bid))
    endtask

    protected task automatic do_decerr_read(
        int unsigned mst_idx,
        bit [ADDR_WIDTH - 1:0] addr,
        burst_len_enum burst_len,
        burst_type_enum burst_type,
        burst_size_enum burst_size,
        bit [ID_WIDTH - 1:0] tr_id = '0
    );
        axicb_single_read_sequence rd_seq;    
        int unsigned beat_num = int'(burst_len) + 1;
        bit resp_ok = 1;
        bit [1:0] rresp[];
        bit [ID_WIDTH - 1:0] rid;
        bit rlast;

        rd_seq = axicb_single_read_sequence::type_id::create("rd_seq");
        rd_seq.src_master_idx     = mst_idx;
        rd_seq.addr               = addr;
        rd_seq.burst_len          = burst_len;
        rd_seq.burst_type         = burst_type;
        rd_seq.burst_size         = burst_size;
        rd_seq.wait_for_response  = 1;
        rd_seq.expect_decerr      = 1;
        rd_seq.arid               = tr_id;
        rd_seq.start(p_sequencer);

        rresp = new[rd_seq.every_beat_rresp.size()];
        foreach(rresp[i]) rresp[i] = rd_seq.every_beat_rresp[i];
        rid   = rd_seq.rid;
        rlast = rd_seq.rlast;

        if(rresp.size() != beat_num)
            `uvm_error(get_type_name(), $sformatf("expected DECERR read beat count FAILED: exp=%0d act=%0d", beat_num, rresp.size()))

        foreach(rresp[i]) begin
            if(rresp[i] != DECERR) begin
                resp_ok = 0;
                `uvm_error(get_type_name(), $sformatf("expected DECERR read beat[%0d], got rresp=%02b", i, rresp[i]))
            end
        end

        if(resp_ok)
            `uvm_info(get_type_name(), $sformatf("expected DECERR read: master%0d addr=%08h id=%08h beats=%0d", mst_idx, addr, tr_id, beat_num), UVM_LOW)

        if(rd_seq.arid != rd_seq.rid)
            `uvm_error(get_type_name(), $sformatf("expected DECERR read ID FAILED: arid=%08h rid=%08h", rd_seq.arid, rd_seq.rid))

        if(rlast != 1'b1)
            `uvm_error(get_type_name(), $sformatf("expected DECERR read RLAST FAILED: rlast=%0b", rlast))
    endtask

    protected task automatic check_downstream_port(
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
