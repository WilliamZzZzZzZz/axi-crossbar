`ifndef AXI_MASTER_MONITOR_SV
`define AXI_MASTER_MONITOR_SV

class axi_master_monitor extends uvm_monitor;
    `uvm_component_utils(axi_master_monitor)

    virtual axi_if vif;
    axi_configuration cfg;

    uvm_analysis_port #(axi_transaction) item_observed_port;

    //temporary store address and data before entire tr is loaded
    axi_transaction write_trans_queue[$];
    axi_transaction read_trans_queue[$];

    function new(string name = "axi_master_monitor", uvm_component parent);
        super.new(name, parent);
        item_observed_port = new("item_observed_port", this);
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
        bit [7:0] current_id;
        int q_index[$];
        forever begin
            @(posedge vif.aclk);
            if(vif.arst) continue;      //doubt!
            //AW channel
            if(vif.monitor_cb.awvalid && vif.monitor_cb.awready) begin
                tr = axi_transaction::type_id::create("tr", this);
                //handshake success then sample signals
                tr.trans_type = WRITE;
                tr.awid     = vif.monitor_cb.awid;
                tr.awaddr   = vif.monitor_cb.awaddr;
                tr.awlen    = vif.monitor_cb.awlen;
                tr.awsize   = vif.monitor_cb.awsize;
                tr.awburst  = vif.monitor_cb.awburst;
                tr.awlock   = vif.monitor_cb.awlock;
                tr.awcache  = vif.monitor_cb.awcache;
                tr.awprot   = vif.monitor_cb.awprot;

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
            //W channel
            if(vif.monitor_cb.wvalid && vif.monitor_cb.wready) begin
                int w_idx[$];
                w_idx = write_trans_queue.find_first_index() with (!item.wbeat_finish);
                //focus on single transaction
                if(w_idx.size() > 0) begin
                    temp_tr = write_trans_queue[w_idx[0]];
                    //this loop focus on single beat
                    if(temp_tr.current_wbeat_count <= temp_tr.awlen) begin
                        temp_tr.wdata[temp_tr.current_wbeat_count] = vif.monitor_cb.wdata;
                        temp_tr.wstrb[temp_tr.current_wbeat_count] = vif.monitor_cb.wstrb;
                        temp_tr.current_wbeat_count++;                        
                        //check WLAST
                        if(vif.monitor_cb.wlast) begin
                            temp_tr.wbeat_finish = 1;
                        end
                    end
                end
                else begin
                    `uvm_error(get_type_name(), "W channel: queue size < 0")
                end
            end
            //B channel
            if(vif.monitor_cb.bvalid && vif.monitor_cb.bready) begin
                //store current id
                current_id = vif.monitor_cb.bid;
                //search for correct tr's index in queue
                q_index = write_trans_queue.find_index() with (
                    item.awid == current_id && item.wbeat_finish && !item.b_finish
                );
                if(q_index.size() > 0) begin
                    int idx = q_index[0];
                    temp_tr = write_trans_queue[idx];

                    temp_tr.bid       = vif.monitor_cb.bid;
                    temp_tr.bresp     = vif.monitor_cb.bresp;
                    temp_tr.b_finish  = 1;
                    //a tran via 3 channels' write operations finally completed, full info now stroed in temp_tr
                    item_observed_port.write(temp_tr);
                    write_trans_queue.delete(idx);
                end
                else begin
                    `uvm_error(get_type_name(), "B channel: queue size < 0")
                end
            end
        end
    endtask

    virtual task monitor_read_transaction();
        axi_transaction tr, temp_tr;
        bit [7:0] current_id;
        int q_index[$];
        forever begin
            @(posedge vif.aclk)
            if (vif.arst) continue;
            //AR channel
            if(vif.monitor_cb.arvalid && vif.monitor_cb.arready) begin
                tr = axi_transaction::type_id::create("tr", this);
                tr.trans_type = READ;
                tr.arid     = vif.monitor_cb.arid;
                tr.araddr   = vif.monitor_cb.araddr;
                tr.arlen    = vif.monitor_cb.arlen;
                tr.arsize   = vif.monitor_cb.arsize;
                tr.arburst  = vif.monitor_cb.arburst;
                tr.arlock   = vif.monitor_cb.arlock;
                tr.arcache  = vif.monitor_cb.arcache;
                tr.arprot   = vif.monitor_cb.arprot;

                tr.rdata = new[tr.arlen + 1];
                tr.rresp = new[tr.arlen + 1];
                tr.current_rbeat_count = 0;
                tr.rbeat_finish = 0;
                read_trans_queue.push_back(tr);
            end
            //R channel
            if(vif.monitor_cb.rvalid && vif.monitor_cb.rready) begin
                if(read_trans_queue.size() > 0) begin
                    current_id = vif.monitor_cb.rid;
                    //sreach correct via ID and flag
                    q_index = read_trans_queue.find_index() with (
                        item.arid == current_id && !item.rbeat_finish
                    );
                    //this loop focus on tr
                    if(q_index.size() > 0) begin
                        int idx = q_index[0];
                        temp_tr = read_trans_queue[idx];
                        //this loop focus on every single beat
                        if(temp_tr.current_rbeat_count <= temp_tr.arlen) begin
                            temp_tr.rdata[temp_tr.current_rbeat_count] = vif.monitor_cb.rdata;
                            temp_tr.rresp[temp_tr.current_rbeat_count] = vif.monitor_cb.rresp;
                            temp_tr.current_rbeat_count++;
                            //every single beat need to check rlast
                            if(vif.monitor_cb.rlast) begin
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

    //reset signal assert, boardcast partial transaction
    virtual task monitor_reset();
        forever begin
            @(posedge vif.arst)     //monitor reset signals
            foreach (write_trans_queue[i]) begin
                axi_transaction partial = write_trans_queue[i];
                if (partial.current_wbeat_count > 0) begin
                    partial.awlen = partial.current_wbeat_count - 1;
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