`ifndef AXI_READ_DRIVER_SV
`define AXI_READ_DRIVER_SV

class axi_master_read_driver extends uvm_object;
    `uvm_object_utils(axi_master_read_driver)

    virtual axi_if vif;
    axi_configuration cfg;

    mailbox #(axi_transaction) req_mbx;
    mailbox #(axi_transaction) ar2r_mbx;
    mailbox #(axi_transaction) rsp_mbx;  // response back to master_driver

    function new(string name = "axi_master_read_driver");
        super.new(name);
        req_mbx  = new();
        ar2r_mbx = new();
        rsp_mbx  = new();
    endfunction

    virtual task run_read_channel();
        forever begin
            @(negedge vif.arst);
            fork
                //two read channel threads
                drive_ar_channel();
                drive_r_channel();
            join_none
            @(posedge vif.arst);
            disable fork;
            flush_mailboxes();
        end
    endtask

    //read address channel
    virtual task drive_ar_channel();
        axi_transaction tr;
        forever begin
            req_mbx.get(tr);
            ar2r_mbx.put(tr);
            //drive AR signals
            @(vif.master_cb);
            vif.master_cb.arvalid   <= 1'b1;
            vif.master_cb.arid      <= tr.arid;
            vif.master_cb.araddr    <= tr.araddr;
            vif.master_cb.arlen     <= tr.arlen;
            vif.master_cb.arsize    <= tr.arsize;
            vif.master_cb.arburst   <= tr.arburst;
            vif.master_cb.arlock    <= tr.arlock;
            vif.master_cb.arcache   <= tr.arcache;
            vif.master_cb.arprot    <= tr.arprot;
            vif.master_cb.arqos     <= tr.arqos;
            vif.master_cb.arregion  <= tr.arregion;
            vif.master_cb.aruser    <= tr.aruser;
            //handshake polling
            do begin
                @(vif.master_cb);
            end while(vif.master_cb.arready === 1'b0);
            //finish handshake
            vif.master_cb.arvalid <= 1'b0;
        end
    endtask

    //read data channel
    virtual task drive_r_channel();
        axi_transaction tr;
        int beat_num;
        int i;
        forever begin
            ar2r_mbx.get(tr);
            beat_num = tr.arlen + 1;

            tr.rdata = new[beat_num];
            tr.rresp = new[beat_num];

            i = 0;

            //every forever loop only driven one beat
            forever begin
                bit rlast_snapshot;
                do begin
                    @(vif.master_cb);
                end while(vif.master_cb.rvalid === 1'b0);

                tr.rdata[i] = vif.master_cb.rdata;
                tr.rresp[i] = vif.master_cb.rresp;
                rlast_snapshot = vif.master_cb.rlast;   //before handshake, task a snapshot of rlast, record rlast status

                //handshake success
                @(vif.master_cb);
                vif.master_cb.rready <= 1'b1;

                //after handshake, slave all signals would turn 0, so snapshot of rlast before handshake is important
                @(vif.master_cb);
                vif.master_cb.rready <= 1'b0;

                i++;
                if(rlast_snapshot || i >= beat_num) begin
                    break;
                end
            end
            rsp_mbx.put(tr);
        end
    endtask

    local function void flush_mailboxes();
        axi_transaction dummy;
        while (req_mbx.try_get(dummy));
        while (ar2r_mbx.try_get(dummy));
        `uvm_info(get_type_name(), "RESET ENABLE, KILL ALL THREADS", UVM_LOW)
    endfunction

endclass

`endif 