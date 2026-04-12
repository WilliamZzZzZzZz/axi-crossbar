`ifndef AXI_MASTER_DRIVER_SV
`define AXI_MASTER_DRIVER_SV

class axi_master_driver extends uvm_driver#(axi_transaction);
    `uvm_component_utils(axi_master_driver)

    axi_configuration                       cfg;
    virtual axi_if#(.ID_WIDTH(ID_WIDTH))    vif;

    axi_master_write_driver    write_drv;
    axi_master_read_driver     read_drv;

    function new(string name = "axi_master_driver", uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        write_drv = axi_master_write_driver::type_id::create("write_drv");
        read_drv  = axi_master_read_driver::type_id::create("read_drv");
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        write_drv.cfg = cfg;
        write_drv.vif = vif;
        read_drv.cfg  = cfg;
        read_drv.vif  = vif;
    endfunction

    //start 6 Threads
    task run_phase(uvm_phase phase);
        super.run_phase(phase);
        // assign vif/cfg to sub-drivers here (run_phase guarantees they are set)
        write_drv.vif = vif;
        write_drv.cfg = cfg;
        read_drv.vif  = vif;
        read_drv.cfg  = cfg;

        fork
            //thread 1: get req from thread 6, via 3 channels drive info to dut
            write_drv.run_write_channel();
            //thread 2：get req from thread 6, via 2 channels drive info to dut
            read_drv.run_read_channel();
            //thread 3: reset signal monitor task
            forever begin
                reset_listener();
            end
            //thread 4: collect write rsp and send back to sequencer
            forever begin
                axi_transaction wr_rsp;
                write_drv.rsp_mbx.get(wr_rsp);
                if(wr_rsp.response_requested)
                    seq_item_port.put_response(wr_rsp);
            end
            //thread 5: collect read rsp and send back to sequencer
            forever begin
                axi_transaction rd_rsp;
                read_drv.rsp_mbx.get(rd_rsp);
                if(rd_rsp.response_requested)
                    seq_item_port.put_response(rd_rsp);
            end
        join_none

        //thread 6: get req from sequence, and put it into write/read driver
        forever begin
            seq_item_port.get_next_item(req);
            //WRITE or READ
            if(req.trans_type == WRITE) begin
                write_drv.req_mbx.put(req);
            end
            else begin  //READ
                read_drv.req_mbx.put(req);
            end
            seq_item_port.item_done();
        end
    endtask

    //AXI4 protocol：reset assert, 5 channels' VAILD should be 0  
    virtual task reset_listener();
        forever begin
            @(posedge vif.arst);
            //protocol regulation: MASTER pull down 3 channels' VAILD
            vif.master_cb.awvalid   <= '0;
            vif.master_cb.wvalid    <= '0;
            vif.master_cb.arvalid   <= '0;
            //pull down other signals are better
            //AW
            vif.master_cb.awid      <= '0;
            vif.master_cb.awaddr    <= '0;
            vif.master_cb.awsize    <= '0;
            vif.master_cb.awburst   <= '0;
            vif.master_cb.awlock    <= '0;
            vif.master_cb.awcache   <= '0;
            vif.master_cb.awprot    <= '0;
            vif.master_cb.awqos     <= '0;
            vif.master_cb.awregion  <= '0;
            vif.master_cb.awuser    <= '0;
            //W
            vif.master_cb.wdata     <= '0;
            vif.master_cb.wstrb     <= '0;
            vif.master_cb.wlast     <= '0;
            vif.master_cb.wuser     <= '0;
            //AR
            vif.master_cb.arid      <= '0;
            vif.master_cb.araddr    <= '0;
            vif.master_cb.arsize    <= '0;
            vif.master_cb.arburst   <= '0;
            vif.master_cb.arlock    <= '0;
            vif.master_cb.arcache   <= '0;
            vif.master_cb.arprot    <= '0;
            vif.master_cb.arqos     <= '0;
            vif.master_cb.arregion  <= '0;
            vif.master_cb.aruser    <= '0;
        end
    endtask

endclass

`endif 