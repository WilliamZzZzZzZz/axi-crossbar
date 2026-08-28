`ifndef AXI_MONITOR_SV
`define AXI_MONITOR_SV

class axi_monitor #(int VIF_ID_WIDTH = ID_WIDTH, bit IS_DOWNSTREAM = 0) extends uvm_monitor;
    `uvm_component_param_utils(axi_monitor#(VIF_ID_WIDTH, IS_DOWNSTREAM))

    virtual axi_if#(.ID_WIDTH(VIF_ID_WIDTH))    vif;
    axi_configuration                           cfg;
    int unsigned                                port_idx;

    uvm_analysis_port #(axi_transaction) item_observed_port;
    uvm_analysis_port #(axi_channel_event) event_observed_port;

    //temporary store address and data before entire tr is loaded
    axi_transaction write_trans_queue[$];
    axi_transaction read_trans_queue[$];

    function new(string name = "axi_monitor", uvm_component parent);
        super.new(name, parent);
        item_observed_port = new("item_observed_port", this);
        event_observed_port = new("event_observed_port", this);
    endfunction

    local function void publish_event(axi_channel_event_kind kind);
        axi_channel_event ev;

        ev = axi_channel_event::type_id::create("ev");
        ev.kind          = kind;
        ev.is_downstream = IS_DOWNSTREAM;
        ev.port_idx      = port_idx;

        case (kind)
            AXI_EVT_AW: begin
                ev.id     = vif.monitor_cb.awid;
                ev.addr   = vif.monitor_cb.awaddr;
                ev.len    = vif.monitor_cb.awlen;
                ev.size   = vif.monitor_cb.awsize;
                ev.burst  = vif.monitor_cb.awburst;
                ev.lock   = vif.monitor_cb.awlock;
                ev.cache  = vif.monitor_cb.awcache;
                ev.prot   = vif.monitor_cb.awprot;
                ev.qos    = vif.monitor_cb.awqos;
                ev.region = vif.monitor_cb.awregion;
                ev.user   = vif.monitor_cb.awuser;
            end
            AXI_EVT_W: begin
                ev.data = vif.monitor_cb.wdata;
                ev.strb = vif.monitor_cb.wstrb;
                ev.last = vif.monitor_cb.wlast;
                ev.user = vif.monitor_cb.wuser;
            end
            AXI_EVT_B: begin
                ev.id   = vif.monitor_cb.bid;
                ev.resp = vif.monitor_cb.bresp;
                ev.user = vif.monitor_cb.buser;
            end
            AXI_EVT_AR: begin
                ev.id     = vif.monitor_cb.arid;
                ev.addr   = vif.monitor_cb.araddr;
                ev.len    = vif.monitor_cb.arlen;
                ev.size   = vif.monitor_cb.arsize;
                ev.burst  = vif.monitor_cb.arburst;
                ev.lock   = vif.monitor_cb.arlock;
                ev.cache  = vif.monitor_cb.arcache;
                ev.prot   = vif.monitor_cb.arprot;
                ev.qos    = vif.monitor_cb.arqos;
                ev.region = vif.monitor_cb.arregion;
                ev.user   = vif.monitor_cb.aruser;
            end
            AXI_EVT_R: begin
                ev.id   = vif.monitor_cb.rid;
                ev.data = vif.monitor_cb.rdata;
                ev.resp = vif.monitor_cb.rresp;
                ev.last = vif.monitor_cb.rlast;
                ev.user = vif.monitor_cb.ruser;
            end
            default: ;
        endcase

        event_observed_port.write(ev);
    endfunction

    virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);
        fork
            //monitor 5 channels WRITE and READ
            monitor_write_transaction();        //full beat transaction
            monitor_read_transaction();         //full beat transaction
            monitor_reset();                    //partial beat transaction
        join_none
    endtask

    virtual task monitor_write_transaction();
        axi_transaction tr, temp_tr;
        bit [VIF_ID_WIDTH - 1:0] current_id;
        int q_index[$];
        forever begin
            @(posedge vif.aclk);
            if(vif.arst) continue;      //doubt!
            //==================== AW channel====================
            if(vif.monitor_cb.awvalid && vif.monitor_cb.awready) begin
                publish_event(AXI_EVT_AW);
                tr = axi_transaction::type_id::create("tr", this);
                tr.trans_type = WRITE;

                if(IS_DOWNSTREAM) begin
                    tr.m_awid = vif.monitor_cb.awid;
                    tr.awid   = vif.monitor_cb.awid[ID_WIDTH - 1:0];
                end
                else begin
                    tr.awid   = vif.monitor_cb.awid;
                    tr.m_awid = '0;
                end

                //handshake success then sample signals
                tr.awaddr   = vif.monitor_cb.awaddr;
                tr.awlen    = burst_len_enum'(vif.monitor_cb.awlen);
                tr.awsize   = burst_size_enum'(vif.monitor_cb.awsize);
                tr.awburst  = burst_type_enum'(vif.monitor_cb.awburst);
                tr.awlock   = lock_type_enum'(vif.monitor_cb.awlock);
                tr.awcache  = cache_type_enum'(vif.monitor_cb.awcache);
                tr.awprot   = prot_type_enum'(vif.monitor_cb.awprot);
                tr.awqos    = vif.monitor_cb.awqos;
                tr.awregion = vif.monitor_cb.awregion;
                tr.awuser   = vif.monitor_cb.awuser;

                //after handshake success, initial arrays
                tr.wdata = new[tr.awlen + 1];
                tr.wstrb = new[tr.awlen + 1];
                tr.current_wbeat_count = 0;
                //flag set 0
                tr.wbeat_finish = 0;
                tr.b_finish     = 0;
                //push unfinish tr into queue temporarily
                write_trans_queue.push_back(tr);
            end
            //==================== B channel ====================
            if(vif.monitor_cb.bvalid && vif.monitor_cb.bready) begin
                publish_event(AXI_EVT_B);
                //store current id
                current_id = vif.monitor_cb.bid;

                //search for correct tr's index in queue
                if(IS_DOWNSTREAM) begin
                    q_index = write_trans_queue.find_index() with (
                        item.m_awid == current_id && !item.b_finish
                    );
                end
                else begin
                    q_index = write_trans_queue.find_index() with (
                        item.awid == current_id[ID_WIDTH - 1:0] && !item.b_finish
                    );                    
                end

                if(q_index.size() > 0) begin
                    int idx = q_index[0];
                    temp_tr = write_trans_queue[idx];

                    //AXI-PROTOCOL check
                    if(temp_tr.wbeat_finish == 0) begin
                        `uvm_error(get_type_name(), "AXI WRITE VIOLATION! B response arrived before final WLAST handshake!")
                    end

                    if(IS_DOWNSTREAM) begin
                        temp_tr.m_bid = vif.monitor_cb.bid;
                        temp_tr.bid   = vif.monitor_cb.bid[ID_WIDTH - 1:0];
                    end
                    else begin
                        temp_tr.bid   = vif.monitor_cb.bid;
                        temp_tr.m_bid = '0;
                    end

                    temp_tr.bresp     = vif.monitor_cb.bresp;
                    temp_tr.buser     = vif.monitor_cb.buser;
                    temp_tr.b_finish  = 1;
                    //a tran via 3 channels' write operations finally completed, full info now stroed in temp_tr
                    try_boardcast_txn(idx);
                end
                else begin
                    `uvm_error(get_type_name(), $sformatf(
                        "B channel: bid=0x%0h not found in queue", current_id))
                end
            end
            //==================== W channel ====================
            if(vif.monitor_cb.wvalid && vif.monitor_cb.wready) begin
                int w_idx[$];
                publish_event(AXI_EVT_W);
                w_idx = write_trans_queue.find_first_index() with (!item.wbeat_finish);
                //focus on single transaction
                if(w_idx.size() > 0) begin
                    int idx = w_idx[0];
                    bit expected_wlast;
                    temp_tr = write_trans_queue[w_idx[0]];

                    if(temp_tr.current_wbeat_count > int'(temp_tr.awlen)) begin
                        `uvm_error(get_type_name(), "W channel too many beats: beat number > awlen + 1")
                    end else begin
                        expected_wlast = (temp_tr.current_wbeat_count == int'(temp_tr.awlen));
                        if(vif.monitor_cb.wlast !== expected_wlast) begin
                            `uvm_error(get_type_name(), "WLAST mismatch!")
                        end
                        temp_tr.wdata[temp_tr.current_wbeat_count] = vif.monitor_cb.wdata;
                        temp_tr.wstrb[temp_tr.current_wbeat_count] = vif.monitor_cb.wstrb;
                        temp_tr.current_wbeat_count++;

                        if(vif.monitor_cb.wlast)
                            temp_tr.wbeat_finish = 1;

                        try_boardcast_txn(idx);
                    end
                end
                else begin
                    `uvm_error(get_type_name(), "W channel: W beat observed but no unfinished AW transaction exists")
                end
            end
        end
    endtask

    virtual task monitor_read_transaction();
        axi_transaction tr, temp_tr;
        bit [VIF_ID_WIDTH - 1:0] current_id;
        int q_index[$];
        forever begin
            @(posedge vif.aclk)
            if (vif.arst) continue;
            //==================== AR channel ====================
            if(vif.monitor_cb.arvalid && vif.monitor_cb.arready) begin
                publish_event(AXI_EVT_AR);
                tr = axi_transaction::type_id::create("tr", this);
                tr.trans_type = READ;

                if (IS_DOWNSTREAM) begin
                    tr.m_arid = vif.monitor_cb.arid;
                    tr.arid   = vif.monitor_cb.arid[ID_WIDTH-1:0];
                end
                else begin
                    tr.arid   = vif.monitor_cb.arid;
                    tr.m_arid = '0;
                end

                tr.araddr   = vif.monitor_cb.araddr;
                tr.arlen    = burst_len_enum'(vif.monitor_cb.arlen);
                tr.arsize   = burst_size_enum'(vif.monitor_cb.arsize);
                tr.arburst  = burst_type_enum'(vif.monitor_cb.arburst);
                tr.arlock   = lock_type_enum'(vif.monitor_cb.arlock);
                tr.arcache  = cache_type_enum'(vif.monitor_cb.arcache);
                tr.arprot   = prot_type_enum'(vif.monitor_cb.arprot);
                tr.arqos    = vif.monitor_cb.arqos;
                tr.arregion = vif.monitor_cb.arregion;
                tr.aruser   = vif.monitor_cb.aruser;

                tr.rdata = new[tr.arlen + 1];
                tr.rresp = new[tr.arlen + 1];
                tr.current_rbeat_count = 0;
                tr.rbeat_finish = 0;
                read_trans_queue.push_back(tr);
            end
            //==================== R channel ====================
            if(vif.monitor_cb.rvalid && vif.monitor_cb.rready) begin
                publish_event(AXI_EVT_R);
                if(read_trans_queue.size() > 0) begin
                    current_id = vif.monitor_cb.rid;
                    //sreach correct via ID and flag
                    if (IS_DOWNSTREAM) begin
                        q_index = read_trans_queue.find_index() with (
                            item.m_arid == current_id && !item.rbeat_finish
                        );
                    end
                    else begin
                        q_index = read_trans_queue.find_index() with (
                            item.arid == current_id[ID_WIDTH-1:0] && !item.rbeat_finish
                        );
                    end
                    //this loop focus on tr
                    if(q_index.size() > 0) begin
                        int idx = q_index[0];
                        temp_tr = read_trans_queue[idx];
                        //this loop focus on every single beat
                        if(temp_tr.current_rbeat_count <= temp_tr.arlen) begin

                            if (IS_DOWNSTREAM) begin
                                temp_tr.m_rid = vif.monitor_cb.rid;
                                temp_tr.rid   = vif.monitor_cb.rid[ID_WIDTH-1:0];
                            end
                            else begin
                                temp_tr.rid   = vif.monitor_cb.rid;
                                temp_tr.m_rid = '0;
                            end
                            
                            temp_tr.rdata[temp_tr.current_rbeat_count] = vif.monitor_cb.rdata;
                            temp_tr.rresp[temp_tr.current_rbeat_count] = vif.monitor_cb.rresp;
                            temp_tr.current_rbeat_count++;
                            //every single beat need to check rlast
                            if(vif.monitor_cb.rlast) begin
                                temp_tr.ruser = vif.monitor_cb.ruser;
                                temp_tr.rbeat_finish = 1;
                                item_observed_port.write(temp_tr);
                                read_trans_queue.delete(idx);
                            end
                        end                                                
                    end else begin
                        `uvm_error(get_type_name(),$sformatf("R channel: ID = %0h not found", current_id))
                    end
                end else begin
                    `uvm_error(get_type_name(), "R channel: queue size < 0")
                end
            end
        end
    endtask

    local function void try_boardcast_txn(int idx);
        axi_transaction done_tr;
        if(idx < 0 || idx >= write_trans_queue.size()) begin
            `uvm_error(get_type_name(), $sformatf("try_emit_write_transaction invalid idx=%0d queue_size=%0d", idx, write_trans_queue.size()))
            return;
        end
        done_tr = write_trans_queue[idx];
        if(done_tr.wbeat_finish && done_tr.b_finish) begin
            item_observed_port.write(done_tr);
            write_trans_queue.delete(idx);
        end
    endfunction

    //reset signal assert, boardcast partial transaction
    virtual task monitor_reset();
        forever begin
            @(posedge vif.arst)     //monitor reset signals
            publish_event(AXI_EVT_RESET);
            foreach (write_trans_queue[i]) begin
                axi_transaction partial = write_trans_queue[i];
                if (partial.current_wbeat_count > 0) begin
                    partial.awlen = burst_len_enum'(partial.current_wbeat_count - 1);
                    partial.wdata = new[partial.current_wbeat_count](partial.wdata);
                    partial.wstrb = new[partial.current_wbeat_count](partial.wstrb);
                    item_observed_port.write(partial);
                end
            end
            write_trans_queue.delete();
            read_trans_queue.delete();
        end
    endtask

endclass

`endif
