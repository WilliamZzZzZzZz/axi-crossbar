`ifndef AXICB_BASE_VSEQ_SV
`define AXICB_BASE_VSEQ_SV

class axicb_base_vseq extends uvm_sequence;
    `uvm_object_utils(axicb_base_vseq)

    
    bit [31:0] wr_val[]; 
    bit [31:0] rd_val[];

    axicb_single_write_sequence single_write;
    axicb_single_read_sequence single_read;

    virtual axi_if#(.ID_WIDTH(ID_WIDTH))    vif_mst00;
    virtual axi_if#(.ID_WIDTH(ID_WIDTH))    vif_mst01;
    virtual axi_if#(.ID_WIDTH(M_ID_WIDTH))  vif_slv00;
    virtual axi_if#(.ID_WIDTH(M_ID_WIDTH))  vif_slv01;

    virtual axi_if#(.ID_WIDTH(ID_WIDTH)) vif;       //default

    `uvm_declare_p_sequencer(axicb_virtual_sequencer)

    function new(string name = "axicb_base_vseq");
        super.new(name);
    endfunction

    virtual task body();
        `uvm_info(get_type_name(), "entering...", UVM_LOW)

        if(p_sequencer == null)
            `uvm_fatal(get_type_name(), "p_sequencer is null")
        if(p_sequencer.axi_mst_sqr00 == null || p_sequencer.axi_mst_sqr01 == null)
            `uvm_fatal(get_type_name(), "master sequencer handles are null in virtual sequencer")

        //upstream VIF
        vif_mst00 = p_sequencer.axi_mst_sqr00.vif;
        vif_mst01 = p_sequencer.axi_mst_sqr01.vif;
        vif       = vif_mst00;                      //default
        if(vif_mst00 == null || vif_mst01 == null)
            `uvm_fatal(get_type_name(), "failed to get vif from master sequencers")
        //downstream VIF
        vif_slv00 = p_sequencer.vif_slv00;
        vif_slv01 = p_sequencer.vif_slv01;
        if(vif_slv00 == null || vif_slv01 == null)
            `uvm_fatal(get_type_name(), "failed to get downstream vif from virtual sequencer")

        `uvm_info(get_type_name(), "exiting...", UVM_LOW)
    endtask

    protected task automatic do_legal_write(
        int unsigned mst_idx,
        bit [ADDR_WIDTH - 1:0] addr,
        burst_len_enum burst_len,
        burst_type_enum burst_type,
        burst_size_enum burst_size,
        bit [ID_WIDTH - 1:0] tr_id
    );
        axicb_single_write_sequence wr_seq;
        int unsigned beat_num = int'(burst_len) + 1;
        bit [DATA_WIDTH - 1:0] rand_data;
        bit [DATA_WIDTH - 1:0] wr_data[];
        bit [1:0] bresp;
        bit [ID_WIDTH - 1:0] bid;        

        wr_seq = axicb_single_write_sequence::type_id::create("wr_seq");
        wr_seq.src_master_idx     = mst_idx;
        wr_seq.addr               = addr;
        wr_seq.burst_len          = burst_len;
        wr_seq.burst_type         = burst_type;
        wr_seq.burst_size         = burst_size;
        wr_seq.wait_for_response  = 1;
        wr_seq.expect_decerr      = 0;
        wr_seq.awid               = tr_id;

        wr_data = new[beat_num];
        wr_seq.every_beat_data  = new[beat_num];
        wr_seq.every_beat_wstrb = new[beat_num];
        foreach(wr_data[i]) begin
            if(!std::randomize(rand_data))
                `uvm_fatal(get_type_name(), "data randomization FAILED!")
            wr_data[i]                 = rand_data;
            wr_seq.every_beat_data[i]  = rand_data;
            wr_seq.every_beat_wstrb[i] = 4'hF;
        end
        wr_seq.data = wr_data[0];
        wr_seq.start(p_sequencer);

        bresp = wr_seq.bresp;
        bid   = wr_seq.bid;

        if(bresp == OKAY)
            `uvm_info(get_type_name(), $sformatf("legal write OKAY: master%0d addr=%08h id=%08b beats=%0d", mst_idx, addr, tr_id, beat_num), UVM_LOW)
        else
            `uvm_error(get_type_name(), $sformatf("legal write expected OKAY, got bresp=%02b addr=%08h id=%08h", bresp, addr, tr_id))

        if(wr_seq.awid != wr_seq.bid)
            `uvm_error(get_type_name(), $sformatf("legal write ID FAILED: awid=%08h bid=%08h", wr_seq.awid, wr_seq.bid))
    endtask

    protected task automatic do_legal_read(
        int unsigned mst_idx,
        bit [ADDR_WIDTH - 1:0] addr,
        burst_len_enum burst_len,
        burst_type_enum burst_type,
        burst_size_enum burst_size,
        bit [ID_WIDTH - 1:0] tr_id
    );
        axicb_single_read_sequence rd_seq;    
        int unsigned beat_num = int'(burst_len) + 1;
        bit resp_ok = 1;
        bit [DATA_WIDTH - 1:0] rd_data[];
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
        rd_seq.expect_decerr      = 0;
        rd_seq.arid               = tr_id;
        rd_seq.start(p_sequencer);

        rd_data = new[rd_seq.every_beat_data.size()];
        rresp   = new[rd_seq.every_beat_rresp.size()];
        foreach(rd_data[i]) rd_data[i] = rd_seq.every_beat_data[i];
        foreach(rresp[i])   rresp[i]   = rd_seq.every_beat_rresp[i];
        rid   = rd_seq.rid;
        rlast = rd_seq.rlast;

        if(rd_data.size() != beat_num)
            `uvm_error(get_type_name(), $sformatf("legal read beat count FAILED: exp=%0d act=%0d", beat_num, rd_data.size()))

        foreach(rresp[i]) begin
            if(rresp[i] != OKAY) begin
                resp_ok = 0;
                `uvm_error(get_type_name(), $sformatf("legal read expected OKAY on beat[%0d], got rresp=%02b", i, rresp[i]))
            end
        end

        if(resp_ok)
            `uvm_info(get_type_name(), $sformatf("legal read OKAY: master%0d addr=%08h id=%08b beats=%0d", mst_idx, addr, tr_id, beat_num), UVM_LOW)

        if(rd_seq.arid != rd_seq.rid)
            `uvm_error(get_type_name(), $sformatf("legal read ID FAILED: arid=%08h rid=%08h", rd_seq.arid, rd_seq.rid))

        if(rlast != 1'b1)
            `uvm_error(get_type_name(), $sformatf("legal read RLAST FAILED: rlast=%0b", rlast))
    endtask

    virtual function bit compare_single_data(bit[31:0] val1, bit[31:0] val2);
        if(val1 === val2) begin
            `uvm_info("CMP-SUCCESS", $sformatf("val1 'h%0x === val2 'h%0x", val1, val2), UVM_LOW)
            return 1;
        end
        else begin
            `uvm_error("CMP-ERROR", $sformatf("val1 'h%0x === val2 'h%0x", val1, val2))
            return 0;
        end
    endfunction  

    virtual function bit compare_data(bit[31:0] wr[], bit[31:0] rd[]);
        if(wr.size() != rd.size()) begin
            `uvm_error("CMP-SIZE", $sformatf("wr size(%0d) != rd size(%0d)", 
                        wr.size(), rd.size()))
            return 0;
        end
        foreach(wr[i]) begin
            if(wr[i] === rd[i])
                `uvm_info("CMP-PASS", $sformatf("beat[%0d] MATCH: wr=0x%08x rd=0x%08x", 
                        i, wr[i], rd[i]), UVM_LOW)
            else begin
                `uvm_error("CMP-FAIL", $sformatf("beat[%0d] MISMATCH: wr=0x%08x rd=0x%08x", 
                        i, wr[i], rd[i]))
                return 0;
            end
        end
        return 1;
    endfunction

    task wait_cycles(int n);
        repeat(n) @(posedge vif.aclk);
    endtask
endclass

`endif 
