`ifndef AXI_MASTER_WRITE_DRIVER_SV
`define AXI_MASTER_WRITE_DRIVER_SV

class axi_master_write_driver extends uvm_object;
    `uvm_object_utils(axi_master_write_driver)

    virtual axi_if#(.ID_WIDTH(ID_WIDTH))    vif;
    axi_configuration                       cfg;

    mailbox #(axi_transaction) req_mbx;
    mailbox #(axi_transaction) aw2w_mbx;
    mailbox #(axi_transaction) aw2b_mbx;
    mailbox #(axi_transaction) rsp_mbx;  // response back to master_driver

    function new(string name = "axi_master_write_driver");
        super.new(name);
        req_mbx  = new();
        aw2w_mbx = new();
        aw2b_mbx = new();
        rsp_mbx  = new();
    endfunction

    local function int unsigned get_handshake_timeout_cycles();
        if(cfg != null && cfg.handshake_timeout_cycles > 0) begin
            return cfg.handshake_timeout_cycles;
        end
        return 2000;
    endfunction

    local task automatic send_write_timeout_response(
        ref axi_transaction tr,
        input string timeout_stage,
        input string timeout_detail
    );
        tr.timed_out      = 1'b1;
        tr.timeout_stage  = timeout_stage;
        tr.timeout_detail = timeout_detail;
        tr.bid            = tr.awid;
        tr.bresp          = DECERR;

        `uvm_error(get_type_name(), $sformatf(
            "%s: %s", timeout_stage, timeout_detail))

        rsp_mbx.put(tr);
    endtask

    virtual task run_write_channel();
        forever begin
            @(negedge vif.arst);        //wait release arst
            fork
                //start three threads
                drive_aw_channel();
                drive_w_channel();
                drive_b_channel();
            join_none   
            @(posedge vif.arst);        //assert reset, kill all threads
            disable fork;
            flush_mailboxes();          //clear all mailboxes
        end
    endtask

    //write address channel
    virtual task drive_aw_channel();
        axi_transaction tr;
        int unsigned wait_cycles;
        forever begin
            req_mbx.get(tr);    //get response from master driver

            //drive AW signals
            @(vif.master_cb);
            vif.master_cb.awvalid   <= 1'b1;
            vif.master_cb.awid      <= tr.awid;
            vif.master_cb.awaddr    <= tr.awaddr;
            vif.master_cb.awlen     <= tr.awlen;
            vif.master_cb.awsize    <= tr.awsize;
            vif.master_cb.awburst   <= tr.awburst;
            vif.master_cb.awlock    <= tr.awlock;
            vif.master_cb.awcache   <= tr.awcache;
            vif.master_cb.awprot    <= tr.awprot;
            vif.master_cb.awqos     <= tr.awqos;
            vif.master_cb.awregion  <= tr.awregion;
            vif.master_cb.awuser    <= tr.awuser;            
            //hanshake polling
            wait_cycles = 0;
            do begin
                @(vif.master_cb);
                if(vif.master_cb.awready !== 1'b1) begin
                    wait_cycles++;
                    if(wait_cycles >= get_handshake_timeout_cycles()) begin
                        vif.master_cb.awvalid <= 1'b0;
                        send_write_timeout_response(
                            tr,
                            "MASTER_AW_READY_TIMEOUT",
                            $sformatf("awready did not assert for awaddr=0x%08h awid=0x%0h within %0d cycles",
                                      tr.awaddr, tr.awid, get_handshake_timeout_cycles())
                        );
                        break;
                    end
                end
            end while(vif.master_cb.awready !== 1'b1);

            if(tr.timed_out) begin
                continue;
            end

            //jump out DO loop means handshake success
            vif.master_cb.awvalid <= 1'b0;

            //after AW handshake finish, then give mail to W channel
            aw2w_mbx.put(tr);
        end
    endtask

    //write data channel
    virtual task drive_w_channel();
        axi_transaction tr;
        int beat_num;
        int i;
        int unsigned wait_cycles;
        forever begin
            aw2w_mbx.get(tr);
            beat_num = int'(tr.awlen) + 1;
            i = 0;

            @(vif.master_cb);
            vif.master_cb.wvalid <= 1'b1;
            vif.master_cb.wdata  <= tr.wdata[0];
            vif.master_cb.wstrb  <= tr.wstrb[0];
            vif.master_cb.wlast  <= (beat_num == 1) ? 1'b1 : 1'b0;

            //every forever loop only driven one beat
            wait_cycles = 0;
            forever begin
                @(vif.master_cb);
                if(vif.master_cb.wready === 1'b1) begin
                    wait_cycles = 0;
                    if(i >= beat_num - 1) begin
                        vif.master_cb.wvalid <= 1'b0;
                        vif.master_cb.wlast  <= 1'b0;
                        vif.master_cb.wdata  <= '0;
                        vif.master_cb.wstrb  <= '0;
                        aw2b_mbx.put(tr);
                        break;
                    end else begin
                        i++;
                        vif.master_cb.wdata <= tr.wdata[i];
                        vif.master_cb.wstrb <= tr.wstrb[i];
                        vif.master_cb.wlast <= (i == beat_num - 1) ? 1'b1 : 1'b0;
                    end
                end
                else begin
                    wait_cycles++;
                    if(wait_cycles >= get_handshake_timeout_cycles()) begin
                        vif.master_cb.wvalid <= 1'b0;
                        vif.master_cb.wlast  <= 1'b0;
                        vif.master_cb.wdata  <= '0;
                        vif.master_cb.wstrb  <= '0;
                        send_write_timeout_response(
                            tr,
                            "MASTER_W_READY_TIMEOUT",
                            $sformatf("wready stalled on beat %0d/%0d for awaddr=0x%08h within %0d cycles",
                                      i, beat_num - 1, tr.awaddr, get_handshake_timeout_cycles())
                        );
                        break;
                    end
                end
            end
        end
    endtask

    //write response channel
    virtual task drive_b_channel();
        axi_transaction tr;
        int unsigned wait_cycles;
        forever begin
            aw2b_mbx.get(tr);

            //wait for bvalid:0->1, while keep bready = 0
            wait_cycles = 0;
            do begin
                @(vif.master_cb);
                if(vif.master_cb.bvalid !== 1'b1) begin
                    wait_cycles++;
                    if(wait_cycles >= get_handshake_timeout_cycles()) begin
                        send_write_timeout_response(
                            tr,
                            "MASTER_B_VALID_TIMEOUT",
                            $sformatf("bvalid did not assert for awaddr=0x%08h awid=0x%0h within %0d cycles",
                                      tr.awaddr, tr.awid, get_handshake_timeout_cycles())
                        );
                        break;
                    end
                end
            end while(vif.master_cb.bvalid !== 1'b1);

            if(tr.timed_out) begin
                continue;
            end

            //check id
            if(vif.master_cb.bid != tr.awid) begin
                `uvm_error(get_type_name(), $sformatf("B Channel ID Mismatch! Expt: %0h, Act: %0h", tr.awid, vif.master_cb.bid))
            end
            else begin
                `uvm_info(get_type_name(), "ID Check PASS!", UVM_LOW)
            end

            //store response info
            tr.bid   = vif.master_cb.bid;
            tr.bresp = vif.master_cb.bresp;

            //after bvalid hold 1 cycle, then handshake
            @(vif.master_cb);
            vif.master_cb.bready <= 1'b1;

            //wait for the hanshake take effect
            @(vif.master_cb);
            vif.master_cb.bready <= 1'b0; 

            //send response back
            rsp_mbx.put(tr);
        end
    endtask

    //clear all mailbox
    //non-blocking, keep trying get mails from mailbox until it empty
    local function void flush_mailboxes();
        axi_transaction dummy;
        while (req_mbx.try_get(dummy));
        while (aw2w_mbx.try_get(dummy));
        while (aw2b_mbx.try_get(dummy));
        while (rsp_mbx.try_get(dummy));
        `uvm_info(get_type_name(), "RESET ENABLE, KILL ALL THREADS", UVM_LOW)
    endfunction

endclass 

`endif 
