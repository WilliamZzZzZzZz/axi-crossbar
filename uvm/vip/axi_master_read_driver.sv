`ifndef AXI_READ_DRIVER_SV
`define AXI_READ_DRIVER_SV

class axi_master_read_driver extends uvm_object;
    `uvm_object_utils(axi_master_read_driver)

    virtual axi_if#(.ID_WIDTH(ID_WIDTH))    vif;
    axi_configuration                       cfg;

    mailbox #(axi_transaction) req_mbx;
    mailbox #(axi_transaction) ar2r_mbx;
    mailbox #(axi_transaction) rsp_mbx;  // response back to master_driver

    function new(string name = "axi_master_read_driver");
        super.new(name);
        req_mbx  = new();
        ar2r_mbx = new();
        rsp_mbx  = new();
    endfunction

    local function int unsigned get_handshake_timeout_cycles();
        if(cfg != null && cfg.handshake_timeout_cycles > 0) begin
            return cfg.handshake_timeout_cycles;
        end
        return 2000;
    endfunction

    local task automatic send_read_timeout_response(
        ref axi_transaction tr,
        input int beat_idx,
        input string timeout_stage,
        input string timeout_detail
    );
        tr.timed_out      = 1'b1;
        tr.timeout_stage  = timeout_stage;
        tr.timeout_detail = timeout_detail;
        tr.rid            = tr.arid;

        if(tr.rresp.size() == 0) begin
            tr.rdata = new[int'(tr.arlen) + 1];
            tr.rresp = new[int'(tr.arlen) + 1];
        end

        for(int j = beat_idx; j < tr.rresp.size(); j++) begin
            tr.rdata[j] = '0;
            tr.rresp[j] = DECERR;
        end

        `uvm_error(get_type_name(), $sformatf(
            "%s: %s", timeout_stage, timeout_detail))

        rsp_mbx.put(tr);
    endtask

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
        int unsigned wait_cycles;
        forever begin
            req_mbx.get(tr);
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
            wait_cycles = 0;
            do begin
                @(vif.master_cb);
                if(vif.master_cb.arready !== 1'b1) begin
                    wait_cycles++;
                    if(wait_cycles >= get_handshake_timeout_cycles()) begin
                        vif.master_cb.arvalid <= 1'b0;
                        send_read_timeout_response(
                            tr,
                            0,
                            "MASTER_AR_READY_TIMEOUT",
                            $sformatf("arready did not assert for araddr=0x%08h arid=0x%0h within %0d cycles",
                                      tr.araddr, tr.arid, get_handshake_timeout_cycles())
                        );
                        break;
                    end
                end
            end while(vif.master_cb.arready !== 1'b1);

            if(tr.timed_out) begin
                continue;
            end
            //finish handshake
            vif.master_cb.arvalid <= 1'b0;
            ar2r_mbx.put(tr);
        end
    endtask

    //read data channel
    virtual task drive_r_channel();
        axi_transaction tr;
        int beat_num;
        int i;
        int unsigned wait_cycles;
        forever begin
            ar2r_mbx.get(tr);
            beat_num = tr.arlen + 1;

            tr.rdata = new[beat_num];
            tr.rresp = new[beat_num];

            i = 0;

            //every forever loop only driven one beat
            forever begin
                bit rlast_snapshot;
                wait_cycles = 0;
                do begin
                    @(vif.master_cb);
                    if(vif.master_cb.rvalid !== 1'b1) begin
                        wait_cycles++;
                        if(wait_cycles >= get_handshake_timeout_cycles()) begin
                            vif.master_cb.rready <= 1'b0;
                            send_read_timeout_response(
                                tr,
                                i,
                                "MASTER_R_VALID_TIMEOUT",
                                $sformatf("rvalid did not assert for araddr=0x%08h beat %0d/%0d within %0d cycles",
                                          tr.araddr, i, beat_num - 1, get_handshake_timeout_cycles())
                            );
                            break;
                        end
                    end
                end while(vif.master_cb.rvalid !== 1'b1);

                if(tr.timed_out) begin
                    break;
                end

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
            if(!tr.timed_out) begin
                rsp_mbx.put(tr);
            end
        end
    endtask

    local function void flush_mailboxes();
        axi_transaction dummy;
        while (req_mbx.try_get(dummy));
        while (ar2r_mbx.try_get(dummy));
        while (rsp_mbx.try_get(dummy));
        `uvm_info(get_type_name(), "RESET ENABLE, KILL ALL THREADS", UVM_LOW)
    endfunction

endclass

`endif 
