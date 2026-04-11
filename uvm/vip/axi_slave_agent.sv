`ifndef AXI_SLAVE_AGENT_SV
`define AXI_SLAVE_AGENT_SV

class axi_slave_agent extends uvm_agent;
    `uvm_component_utils(axi_slave_agent)

    axi_configuration                       cfg;
    axi_slave_responder                     responder;
    axi_monitor#(M_ID_WIDTH)                monitor;
    virtual axi_if#(.ID_WIDTH(M_ID_WIDTH))  vif;

    uvm_analysis_port #(axi_transaction) item_collected_port;

    function new(string name = "axi_slave_agent", uvm_component parent = null);
        super.new(name, parent);
        item_collected_port = new("item_collected_port", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if(!uvm_config_db#(axi_configuration)::get(this, "", "cfg", cfg)) begin
            `uvm_fatal(get_type_name(), "failed to get cfg in axi_slave_agent")
        end
        if(!uvm_config_db#(virtual axi_if#(.ID_WIDTH(M_ID_WIDTH)))::get(this, "", "vif", vif)) begin
            `uvm_fatal(get_type_name(), "failed to get vif in axi_slave_agent")
        end

        responder = axi_slave_responder::type_id::create("responder", this);
        monitor = axi_monitor#(M_ID_WIDTH)::type_id::create("monitor", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        responder.vif = vif;
        responder.cfg = cfg;          
        monitor.vif = vif;
        monitor.cfg = cfg;

        monitor.item_observed_port.connect(item_collected_port);
    endfunction

    virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);
    endtask

endclass

`endif