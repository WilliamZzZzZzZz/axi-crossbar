`ifndef AXI_SLAVE_READ_RESPONDER_SV
`define AXI_SLAVE_READ_RESPONDER_SV

class axi_slave_read_responder extends uvm_object;

    `uvm_object_utils(axi_slave_read_responder)

    virtual axi_if vif;
    axi_configuration cfg;
    axi_slave_mem mem;

    mailbox #(axi_transaction) ar2r_mbx;

    function new(string name = "axi_slave_read_responder");
        super.new(name);
        ar2r_mbx = new();
    endfunction

    virtual task run_read_channels();
        forever begin
            @(negedge vif.arst)
            fork

            join_none
        end
    endtask

    virtual task accept_ar_channel();
        axi_transaction tr;
        forever begin
            tr = axi_transaction::type_id::create("tr");
            //pull up valid and wait for handshake
            vif.slave_cb.arready <= 1'b1;
            do begin
                @(vif.slave_cb)
            end while(vif.slave_cb.arvalid === 1'b0);
            //handshake success
            tr.arid     = vif.slave_cb.arid;
            tr.araddr   = vif.slave_cb.araddr;
            tr.arlen    = vif.slave_cb.arlen;
            tr.arsize   = vif.slave_cb.arsize;
            tr.arburst  = vif.slave_cb.arburst;
            tr.arlock   = vif.slave_cb.arlock;
            tr.arcache  = vif.slave_cb.arcache;
            tr.arprot   = vif.slave_cb.arprot;
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
        bit [ADDR_WIDTH - 1:0] beat_addr;
        bit [ADDR_WIDTH - 1:0] word_addr;
        bit [DATA_WIDTH - 1:0] word_data;

        forever begin
            ar2r_mbx.get(tr);
            beat_num = int'(tr.awlen) + 1;

            //deal with every single beat
            for(int i = 0; i < beat_num; i++) begin
                //got every beat's addr
                beat_addr = axi_slave_mem::calc_beat_addr(
                    tr.awaddr,
                    tr.awburst,
                    tr.awsize,
                    i
                );
                word_addr = {beat_addr[ADDR_WIDTH - 1:2], 2'b00};
                word_data = read_word(word_addr);
                //drive bus signals
                @(vif.slave_cb);
                vif.slave_cb.rid    <= tr.arid;
                vif.slave_cb.rdata  <= word_data;
                vif.slave_cb.rresp  <= 2'b00;
                vif.slave_cb.rlast  <= (i == beat_num - 1) ? 1'b1 : 1'b0;
                vif.slave_cb.ruser  <= tr.aruser;
                vif.slave_cb.rvalid <= 1'b1;    //axi protocol: after drive all signals on bus, then pull up valid

                do begin
                    @(vif.slave_cb);
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