`ifndef AXI_SLAVE_READ_RESPONDER_SV
`define AXI_SLAVE_READ_RESPONDER_SV

class axi_slave_read_responder extends uvm_object;

    `uvm_object_utils(axi_slave_read_responder)

    virtual axi_if#(.ID_WIDTH(M_ID_WIDTH))  vif;
    axi_configuration                       cfg;
    axi_slave_mem                           mem;

    mailbox #(axi_transaction) ar2r_mbx;

    function new(string name = "axi_slave_read_responder");
        super.new(name);
        ar2r_mbx = new();
    endfunction

    virtual task run_read_channels();
        forever begin
            @(negedge vif.arst);
            fork
                accept_ar_channel();
                drive_r_channel();
            join_none
            @(posedge vif.arst);
            disable fork;   //over reset, unfinished threads all should be killed
        end
    endtask

    virtual task accept_ar_channel();
        axi_transaction tr;
        int timeout_cnt;
        forever begin
            tr = axi_transaction::type_id::create("tr");
            //pull up ready and wait for handshake
            vif.slave_cb.arready <= 1'b1;
            timeout_cnt = 0;
            do begin
                @(vif.slave_cb);
                //TIMEOUT_CHECK(slave allow to wait more time)
                timeout_cnt++;
                if(timeout_cnt >= cfg.handshake_timeout_cycles*5) begin
                    `uvm_error(get_type_name(), $sformatf(
                        "AR channel(slave) timeout %0d cycles.", timeout_cnt))
                    timeout_cnt = 0;
                end
            end while(vif.slave_cb.arvalid === 1'b0);
            //handshake success
            tr.m_arid   = vif.slave_cb.arid;
            tr.arid     = vif.slave_cb.arid[ID_WIDTH - 1:0];
            tr.araddr   = vif.slave_cb.araddr;
            tr.arlen    = burst_len_enum'(vif.slave_cb.arlen);
            tr.arsize   = burst_size_enum'(vif.slave_cb.arsize);
            tr.arburst  = burst_type_enum'(vif.slave_cb.arburst);
            tr.arlock   = lock_type_enum'(vif.slave_cb.arlock);
            tr.arcache  = cache_type_enum'(vif.slave_cb.arcache);
            tr.arprot   = prot_type_enum'(vif.slave_cb.arprot);
            tr.arqos    = vif.slave_cb.arqos;
            tr.arregion = vif.slave_cb.arregion;
            tr.aruser   = vif.slave_cb.aruser;
            //after handshake, deassert ready signal
            @(vif.slave_cb);
            vif.slave_cb.arready <= 1'b0;
            ar2r_mbx.put(tr);
        end
    endtask

    virtual task drive_r_channel();
        axi_transaction tr;
        int beat_num;
        int timeout_cnt;
        bit [ADDR_WIDTH - 1:0] beat_addr;
        bit [ADDR_WIDTH - 1:0] word_addr;
        bit [DATA_WIDTH - 1:0] word_data;

        forever begin
            ar2r_mbx.get(tr);
            beat_num = int'(tr.arlen) + 1;

            //deal with every single beat
            for(int i = 0; i < beat_num; i++) begin
                //got every beat's addr
                beat_addr = axi_slave_mem#()::calc_beat_addr(
                    tr.araddr,
                    tr.arburst,
                    tr.arsize,
                    i
                );
                word_addr = {beat_addr[ADDR_WIDTH - 1:2], 2'b00};
                word_data = mem.read_word(word_addr);

                tr.m_rid = tr.m_arid;
                tr.rid   = tr.arid;

                //drive bus signals
                @(vif.slave_cb);
                vif.slave_cb.rid    <= tr.m_rid;
                vif.slave_cb.rdata  <= word_data;
                vif.slave_cb.rresp  <= 2'b00;
                vif.slave_cb.rlast  <= (i == beat_num - 1) ? 1'b1 : 1'b0;
                vif.slave_cb.ruser  <= tr.aruser;
                vif.slave_cb.rvalid <= 1'b1;    //axi protocol: after drive all signals on bus, then pull up valid

                timeout_cnt = 0;
                do begin
                    @(vif.slave_cb);
                    //TIMEOUT_CHECK
                    timeout_cnt++;
                    if(timeout_cnt >= cfg.handshake_timeout_cycles) begin
                        `uvm_fatal(get_type_name(), $sformatf(
                            "R channel(slave) timeout %0d cycles. beat=%0d/%0d rid=0x%08h",
                            cfg.handshake_timeout_cycles, i, beat_num, tr.m_rid
                        ))
                    end
                end while(vif.slave_cb.rready === 1'b0);
                //handshake success

                @(vif.slave_cb);
                vif.slave_cb.rid    <= '0;
                vif.slave_cb.rdata  <= '0;
                vif.slave_cb.rresp  <= '0;
                vif.slave_cb.rlast  <= '0;
                vif.slave_cb.ruser  <= '0;
                vif.slave_cb.rvalid <= '0;

            end
        end

    endtask

endclass

`endif 