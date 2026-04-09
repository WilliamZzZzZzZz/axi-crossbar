`ifndef AXI_WRITE_DRIVER_SV
`define AXI_WRITE_DRIVER_SV

class axi_write_driver extends uvm_object;
    `uvm_object_utils(axi_write_driver)

    virtual axi_if      vif;
    axi_configuration   cfg;

    mailbox #(axi_transaction) req_mbx;
    mailbox #(axi_transaction) aw2w_mbx;
    mailbox #(axi_transaction) aw2b_mbx;
    mailbox #(axi_transaction) rsp_mbx;  // response back to master_driver

    function new(string name = "axi_write_driver");
        super.new(name);
        req_mbx  = new();
        aw2w_mbx = new();
        aw2b_mbx = new();
        rsp_mbx  = new();
    endfunction

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
        forever begin
            req_mbx.get(tr);    //get response from master driver
            aw2w_mbx.put(tr);   //copy tr to W and B channel
            // aw2b_mbx.put(tr);

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
            
            //hanshake polling
            do begin
                @(vif.master_cb);
            end while(vif.master_cb.awready === 1'b0);

            //jump out DO loop means handshake success
            vif.master_cb.awvalid <= 1'b0;

            //after handshake finish, then give mail to B channel
            aw2b_mbx.put(tr);
        end
    endtask

    //write data channel
    virtual task drive_w_channel();
        axi_transaction tr;
        int beat_num;
        int i;
        forever begin
            aw2w_mbx.get(tr);
            beat_num = int'(tr.awlen) + 1;
            i = 0;

            @(vif.master_cb);
            vif.master_cb.wvalid <= 1'b1;
            vif.master_cb.wdata  <= tr.wdata[0];
            vif.master_cb.wstrb  <= tr.wstrb[0];
            vif.master_cb.wlast  <= (beat_num == 1) ? 1'b1 : 1'b0;
            i = 1;

            //every forever loop only driven one beat
            forever begin
                @(vif.master_cb);
                if(vif.master_cb.wready === 1'b1) begin
                    if(i >= beat_num) begin
                        vif.master_cb.wvalid <= 1'b0;
                        vif.master_cb.wlast  <= 1'b0;
                        break;
                    end else begin
                        vif.master_cb.wdata <= tr.wdata[i];
                        vif.master_cb.wstrb <= tr.wstrb[i];
                        vif.master_cb.wlast <= (i == beat_num - 1) ? 1'b1 : 1'b0;
                        i++;
                    end
                end
            end
        end
    endtask

    //write response channel
    virtual task drive_b_channel();
        axi_transaction tr;
        forever begin
            aw2b_mbx.get(tr);

            //wait for bvalid:0->1, while keep bready = 0
            do begin
                @(vif.master_cb);
            end while(vif.master_cb.bvalid === 1'b0);

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
        `uvm_info(get_type_name(), "RESET ENABLE, KILL ALL THREADS", UVM_LOW)
    endfunction

endclass 

`endif 