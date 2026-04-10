`ifndef AXI_SLAVE_AGENT_SV
`define AXI_SLAVE_AGENT_SV

class axi_slave_agent extends uvm_agent;
    `uvm_component_utils(axi_slave_agent)

    axi_configuration cfg;
    virtual axi_if vif;
    axi_slave_responder responder;
    axi_monitor monitor;

    uvm_analysis_port #(axi_transaction) item_collected_port;

    function new(string name = "axi_slave_agent", uvm_component parent = null);
        super.new(name, parent);
        item_collected_port = new("item_collected_port", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if(!uvm_config_db#(virtual axi_if)::get(this, "", "vif", vif))
            `uvm_fatal(get_type_name(), "Failed to get vif")

        if(!uvm_config_db#(axi_configuration)::get(this, "", "cfg", cfg))
            `uvm_fatal(get_type_name(), "Failed to get cfg")

        responder = axi_slave_responder::type_id::create("responder", this);
        monitor = axi_master_monitor::type_id::create("monitor", this);
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