`ifndef AXI_MASTER_DRIVER_SV
`define AXI_MASTER_DRIVER_SV

class axi_master_driver extends uvm_driver #(axi_transaction);
    `uvm_component_utils(axi_master_driver)

    axi_configuration cfg;
    virtual axi_if vif;

    axi_write_driver write_drv;
    axi_read_driver  read_drv;

    function new(string name = "axi_master_driver", uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        write_drv = axi_write_driver::type_id::create("write_drv");
        read_drv  = axi_read_driver::type_id::create("read_drv");
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        write_drv.cfg = cfg;
        write_drv.vif = vif;
        read_drv.cfg  = cfg;
        read_drv.vif  = vif;
    endfunction

    task run_phase(uvm_phase phase);
        axi_transaction req;
        super.run_phase(phase);

        write_drv.vif = vif;
        write_drv.cfg = cfg;
        read_drv.vif  = vif;
        read_drv.cfg  = cfg;

        fork
            write_drv.run_write_channel();
            read_drv.run_read_channel();

            forever begin
                reset_listener();
            end

            forever begin
                axi_transaction wr_rsp;
                write_drv.rsp_mbx.get(wr_rsp);
                if (wr_rsp.response_requested)
                    seq_item_port.put_response(wr_rsp);
            end

            forever begin
                axi_transaction rd_rsp;
                read_drv.rsp_mbx.get(rd_rsp);
                if (rd_rsp.response_requested)
                    seq_item_port.put_response(rd_rsp);
            end
        join_none

        forever begin
            seq_item_port.get_next_item(req);
            if (req.trans_type == WRITE) begin
                write_drv.req_mbx.put(req);
            end else begin
                read_drv.req_mbx.put(req);
            end
            seq_item_port.item_done();
        end
    endtask

    virtual task reset_listener();
        @(posedge vif.arst);
        vif.master_cb.awvalid <= 1'b0;
        vif.master_cb.wvalid  <= 1'b0;
        vif.master_cb.arvalid <= 1'b0;
        vif.master_cb.bready  <= 1'b0;
        vif.master_cb.rready  <= 1'b0;
    endtask

endclass

`endif
