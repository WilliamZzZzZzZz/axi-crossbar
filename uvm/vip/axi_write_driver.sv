`ifndef AXI_WRITE_DRIVER_SV
`define AXI_WRITE_DRIVER_SV

class axi_write_driver extends uvm_object;
    `uvm_object_utils(axi_write_driver)

    virtual axi_if      vif;
    axi_configuration   cfg;

    mailbox #(axi_transaction) req_mbx;
    mailbox #(axi_transaction) aw2w_mbx;
    mailbox #(axi_transaction) aw2b_mbx;
    mailbox #(axi_transaction) rsp_mbx;

    function new(string name = "axi_write_driver");
        super.new(name);
        req_mbx  = new();
        aw2w_mbx = new();
        aw2b_mbx = new();
        rsp_mbx  = new();
    endfunction

    virtual task run_write_channel();
        forever begin
            @(negedge vif.arst);
            fork
                drive_aw_channel();
                drive_w_channel();
                drive_b_channel();
            join_none
            @(posedge vif.arst);
            disable fork;
            flush_mailboxes();
        end
    endtask

    virtual task drive_aw_channel();
        axi_transaction tr;
        forever begin
            req_mbx.get(tr);
            aw2w_mbx.put(tr);

            @(vif.master_cb);
            vif.master_cb.awvalid <= 1'b1;
            vif.master_cb.awid    <= tr.awid;
            vif.master_cb.awaddr  <= tr.awaddr;
            vif.master_cb.awlen   <= tr.awlen;
            vif.master_cb.awsize  <= tr.awsize;
            vif.master_cb.awburst <= tr.awburst;
            vif.master_cb.awlock  <= tr.awlock;
            vif.master_cb.awcache <= tr.awcache;
            vif.master_cb.awprot  <= tr.awprot;
            vif.master_cb.awqos   <= tr.awqos;
            vif.master_cb.awuser  <= tr.awuser;

            do begin
                @(vif.master_cb);
            end while (vif.master_cb.awready === 1'b0);

            vif.master_cb.awvalid <= 1'b0;
            aw2b_mbx.put(tr);
        end
    endtask

    virtual task drive_w_channel();
        axi_transaction tr;
        int beat_num;
        int i;
        forever begin
            aw2w_mbx.get(tr);
            beat_num = tr.awlen + 1;
            i = 0;

            @(vif.master_cb);
            vif.master_cb.wvalid <= 1'b1;
            vif.master_cb.wdata  <= tr.wdata[0];
            vif.master_cb.wstrb  <= tr.wstrb[0];
            vif.master_cb.wuser  <= tr.wuser[0];
            vif.master_cb.wlast  <= (beat_num == 1);
            i = 1;

            forever begin
                @(vif.master_cb);
                if (vif.master_cb.wready === 1'b1) begin
                    if (i >= beat_num) begin
                        vif.master_cb.wvalid <= 1'b0;
                        vif.master_cb.wlast  <= 1'b0;
                        break;
                    end else begin
                        vif.master_cb.wdata <= tr.wdata[i];
                        vif.master_cb.wstrb <= tr.wstrb[i];
                        vif.master_cb.wuser <= tr.wuser[i];
                        vif.master_cb.wlast <= (i == beat_num - 1);
                        i++;
                    end
                end
            end
        end
    endtask

    virtual task drive_b_channel();
        axi_transaction tr;
        forever begin
            aw2b_mbx.get(tr);

            do begin
                @(vif.master_cb);
            end while (vif.master_cb.bvalid === 1'b0);

            if (vif.master_cb.bid != tr.awid) begin
                `uvm_error(get_type_name(),
                    $sformatf("B channel ID mismatch! Exp=%0h Act=%0h", tr.awid, vif.master_cb.bid))
            end

            tr.bid   = vif.master_cb.bid;
            tr.bresp = vif.master_cb.bresp;
            tr.buser = vif.master_cb.buser;

            @(vif.master_cb);
            vif.master_cb.bready <= 1'b1;

            @(vif.master_cb);
            vif.master_cb.bready <= 1'b0;

            rsp_mbx.put(tr);
        end
    endtask

    local function void flush_mailboxes();
        axi_transaction dummy;
        while (req_mbx.try_get(dummy));
        while (aw2w_mbx.try_get(dummy));
        while (aw2b_mbx.try_get(dummy));
        `uvm_info(get_type_name(), "RESET detected, write driver queues flushed", UVM_LOW)
    endfunction

endclass

`endif
