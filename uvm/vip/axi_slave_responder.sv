`ifndef AXI_SLAVE_RESPONDER_SV
`define AXI_SLAVE_RESPONDER_SV

class axi_slave_responder extends uvm_component;
    `uvm_component_utils(axi_slave_responder)

    virtual axi_if#(.ID_WIDTH(M_ID_WIDTH))  vif;
    axi_configuration                       cfg;
    axi_slave_write_responder               write_rpd;
    axi_slave_read_responder                read_rpd;
    axi_slave_mem                           mem;

    function new(string name = "axi_slave_responder", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        mem = new("mem");
        write_rpd = axi_slave_write_responder::type_id::create("write_rpd");
        read_rpd  = axi_slave_read_responder::type_id::create("read_rpd");
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        write_rpd.vif = vif;
        write_rpd.cfg = cfg;
        write_rpd.mem = mem;
        read_rpd.vif = vif;
        read_rpd.cfg = cfg;
        read_rpd.mem = mem;
    endfunction

    task run_phase(uvm_phase phase);
        super.run_phase(phase);
        write_rpd.vif = vif;
        write_rpd.cfg = cfg;
        write_rpd.mem = mem;
        read_rpd.vif = vif;
        read_rpd.cfg = cfg;
        read_rpd.mem = mem;
                
        fork
            write_rpd.run_write_channels();
            read_rpd.run_read_channels();
            reset_listener();
        join_none
    endtask

    virtual task reset_listener();
        forever begin
            @(posedge vif.arst);
            //protocol regulation: SLAVE pull down 2 channels' VAILD
            vif.slave_cb.bvalid <= '0;
            vif.slave_cb.rvalid <= '0;
            //pull down other signals are better
            //B
            vif.slave_cb.bid    <= '0;
            vif.slave_cb.bresp  <= '0;
            vif.slave_cb.buser  <= '0;
            //R
            vif.slave_cb.rid    <= '0;
            vif.slave_cb.rdata  <= '0;
            vif.slave_cb.rresp  <= '0;
            vif.slave_cb.rlast  <= '0;
            vif.slave_cb.ruser  <= '0;
            //clear memory
            mem.clear();
        end
    endtask

endclass

`endif  