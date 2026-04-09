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

    virtual task drive_ar_channel();
        axi_transaction tr;
        forever begin
            tr = axi_transaction::type_id::create("tr");
            //pull up valid and wait for handshake
            vif.slave_cb.arvalid <= 1'b1;
            do begin
                @(vif.slave_cb)
            end while(vif.slave_cb.arready === 1'b0);
            //handshake success
        end
    endtask

endclass

`endif 