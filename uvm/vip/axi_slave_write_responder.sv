`ifndef AXI_SLAVE_WRITE_RESPONDER_SV
`define AXI_SLAVE_WRITE_RESPONDER_SV

class axi_slave_write_responder extends uvm_object;
    `uvm_object_utils(axi_slave_write_responder)

    virtual axi_if#(.ID_WIDTH(M_ID_WIDTH))  vif;
    axi_configuration                       cfg;
    axi_slave_mem                           mem;

    mailbox #(axi_transaction) aw2w_mbx;
    mailbox #(axi_transaction) w2b_mbx;

    function new(string name = "axi_slave_write_responder");
        super.new(name);
        aw2w_mbx = new();
        w2b_mbx = new();    
    endfunction

    local function int unsigned get_handshake_timeout_cycles();
        if(cfg != null && cfg.handshake_timeout_cycles > 0) begin
            return cfg.handshake_timeout_cycles;
        end
        return 2000;
    endfunction

    local function void flush_mailboxes();
        axi_transaction dummy;
        while (aw2w_mbx.try_get(dummy));
        while (w2b_mbx.try_get(dummy));
        `uvm_info(get_type_name(), "RESET ENABLE, CLEAR SLAVE WRITE MAILBOXES", UVM_LOW)
    endfunction

    virtual task run_write_channels();
        forever begin
            @(negedge vif.arst);
            fork
                accept_aw_channel();
                accept_w_channel();
                drive_b_channel();
            join_none
            @(posedge vif.arst);
            disable fork;   //over reset, unfinished threads all should be killed
            flush_mailboxes();
        end
    endtask

    virtual task accept_aw_channel();
        axi_transaction tr;    
        forever begin
            tr = axi_transaction::type_id::create("tr");
            //pull up ready signal and wait for handshake
            vif.slave_cb.awready <= 1'b1;
            do begin
                @(vif.slave_cb);
            end while(vif.slave_cb.awvalid === 1'b0);
            //handshake success

            tr.trans_type = WRITE;
            tr.m_awid     = vif.slave_cb.awid;
            tr.awid       = vif.slave_cb.awid[ID_WIDTH - 1:0];
            tr.awaddr     = vif.slave_cb.awaddr;
            tr.awlen      = burst_len_enum'(vif.slave_cb.awlen);
            tr.awsize     = burst_size_enum'(vif.slave_cb.awsize);
            tr.awburst    = burst_type_enum'(vif.slave_cb.awburst);
            tr.awlock     = lock_type_enum'(vif.slave_cb.awlock);
            tr.awcache    = cache_type_enum'(vif.slave_cb.awcache);
            tr.awprot     = prot_type_enum'(vif.slave_cb.awprot);
            tr.awqos      = vif.slave_cb.awqos;
            tr.awregion   = vif.slave_cb.awregion;
            tr.awuser     = vif.slave_cb.awuser;

            //after handshake pull down ready
            vif.slave_cb.awready <= 1'b0;
            //put unfinished tr into mailbox
            aw2w_mbx.put(tr); 

            `uvm_info(get_type_name(), $sformatf(
                "AW accepted: id = 0x%0h addr = 0x%0h len = %0d size = %0d burst = %0d",
                tr.awid, tr.awaddr, tr.awlen, tr.awsize, tr.awburst
            ), UVM_MEDIUM)
        end
    endtask

    virtual task accept_w_channel();
        axi_transaction tr;
        int beat_num;
        int i = 0;
        int unsigned wait_cycles;
        forever begin
            aw2w_mbx.get(tr);
            beat_num = int'(tr.awlen) + 1;

            tr.wdata = new[beat_num];
            tr.wstrb = new[beat_num];
            tr.current_wbeat_count = 0;
            tr.wbeat_finish        = 0;

            //pull up ready and wait for handshake
            vif.slave_cb.wready <= 1'b1;

            //deal with every single beat 
            for(i = 0; i < beat_num; i++) begin
                wait_cycles = 0;
                do begin
                    @(vif.slave_cb);
                    if(vif.slave_cb.wvalid !== 1'b1) begin
                        wait_cycles++;
                        if(wait_cycles >= get_handshake_timeout_cycles()) begin
                            vif.slave_cb.wready <= 1'b0;
                            `uvm_error(get_type_name(), $sformatf(
                                "SLAVE_W_VALID_TIMEOUT: wvalid did not assert on beat %0d/%0d for awaddr=0x%08h within %0d cycles",
                                i, beat_num - 1, tr.awaddr, get_handshake_timeout_cycles()
                            ))
                            break;
                        end
                    end
                end while(vif.slave_cb.wvalid !== 1'b1);

                if(vif.slave_cb.wvalid !== 1'b1) begin
                    break;
                end
                //handshake success

                //sample every beat data and strb into tr
                tr.wdata[i] = vif.slave_cb.wdata;
                tr.wstrb[i] = vif.slave_cb.wstrb;
                tr.current_wbeat_count++;

                //check every beat's wlast signal
                if(i < beat_num - 1) begin
                    //wlast too early
                    if(vif.slave_cb.wlast === 1'b1) begin
                        `uvm_error(get_type_name(), $sformatf(
                            "WLAST set 1 before the last beat: current beat: %0d, expected last beat: %0d",
                            i, beat_num - 1
                        ))
                    end
                end
                else begin  //it's the last beat and into this loop, check wlast whether is 1
                    if(vif.slave_cb.wlast !== 1'b1) begin
                        `uvm_error(get_type_name(), $sformatf("WLAST set 0 in the last beat!"))
                    end
                    tr.wbeat_finish = 1;
                end        
                `uvm_info(get_type_name(), $sformatf(
                    "W beat [%0d/%0d] accepted: wdata = 0x%0h wstrb = 0x%0h wlast = %0b",
                    i, beat_num - 1, tr.wdata[i], tr.wstrb[i], vif.slave_cb.wlast
                ), UVM_MEDIUM)
            end

            if(tr.current_wbeat_count != beat_num) begin
                continue;
            end
            
            //after handshake, pull down ready
            vif.slave_cb.wready <= 1'b0;
            w2b_mbx.put(tr);

            `uvm_info(get_type_name(), $sformatf(
                "W all burst accepted: awid = 0x%0h awaddr = 0x%0h beats = %0d",
                tr.awid, tr.awaddr, beat_num
            ), UVM_MEDIUM)
        end
    endtask

    virtual task drive_b_channel();
        axi_transaction tr;
        int beat_num;
        bit [ADDR_WIDTH - 1:0] beat_addr;
        bit [ADDR_WIDTH - 1:0] word_addr;
        int unsigned wait_cycles;
        bit timeout_hit;

        forever begin
            w2b_mbx.get(tr);
            beat_num = int'(tr.awlen) + 1;

            //deal with every single beat
            for(int i = 0; i < beat_num; i++) begin
                //got every beat's actual addr
                beat_addr = axi_slave_mem#()::calc_beat_addr(
                    tr.awaddr,
                    tr.awburst,
                    tr.awsize,
                    i
                );
                //align to 4-byte word boundary
                word_addr = {beat_addr[ADDR_WIDTH - 1:2], 2'b00};
                //store data into mem word-by-word
                mem.write_word_with_strb(word_addr, tr.wdata[i], tr.wstrb[i]);
                //print info
                `uvm_info(get_type_name(), $sformatf(
                    "one beat is stored in MEM, beat[%0d]: beat_addr=0x%08h word_addr=0x%08h wdata=0x%08h wstrb=0x%01h -> word=0x%08h",
                    i, beat_addr, word_addr, tr.wdata[i], tr.wstrb[i], mem.read_word(word_addr)
                ), UVM_MEDIUM)
            end

            tr.m_bid = tr.m_awid;
            tr.bid   = tr.awid;
            //drive signals on bus before pull up valid
            @(vif.slave_cb);
            vif.slave_cb.bid    <= tr.m_bid;
            vif.slave_cb.bresp  <= 2'b00;     //default is OKAY
            vif.slave_cb.buser  <= tr.awuser;
            vif.slave_cb.bvalid <= 1'b1;      //pull up valid and wait for handshake

            wait_cycles = 0;
            timeout_hit = 0;
            do begin
                @(vif.slave_cb);
                if(vif.slave_cb.bready !== 1'b1) begin
                    wait_cycles++;
                    if(wait_cycles >= get_handshake_timeout_cycles()) begin
                        timeout_hit = 1;
                        `uvm_error(get_type_name(), $sformatf(
                            "SLAVE_B_READY_TIMEOUT: bready did not assert for awaddr=0x%08h awid=0x%0h within %0d cycles",
                            tr.awaddr, tr.awid, get_handshake_timeout_cycles()
                        ))
                        break;
                    end
                end
            end while(vif.slave_cb.bready !== 1'b1);

            vif.slave_cb.bvalid <= 1'b0;
            vif.slave_cb.bid    <= '0;
            vif.slave_cb.bresp  <= '0;
            vif.slave_cb.buser  <= '0;

            if(timeout_hit) begin
                continue;
            end

            `uvm_info(get_type_name(), $sformatf(
                "B drived response back: bid = 0x%0h bresp = %0b",
                tr.m_bid, 2'b00
            ), UVM_MEDIUM)
        end
    endtask

endclass 


`endif 
