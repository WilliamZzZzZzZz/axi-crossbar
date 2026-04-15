`ifndef AXI_MASTER_AGENT_SV
`define AXI_MASTER_AGENT_SV

class axi_master_agent extends uvm_agent;
    `uvm_component_utils(axi_master_agent)

    axi_configuration                       cfg;
    axi_master_sequencer                    sequencer;
    axi_master_driver                       driver;
    axi_monitor#(ID_WIDTH, 0)                  monitor;
    virtual axi_if#(.ID_WIDTH(ID_WIDTH))    vif;

    uvm_analysis_port #(axi_transaction) item_collected_port;

    function new(string name = "axi_master_agent", uvm_component parent = null);
        super.new(name, parent);
        item_collected_port = new("item_collected_port", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if(!uvm_config_db#(axi_configuration)::get(this, "", "cfg", cfg)) begin
            `uvm_fatal(get_type_name(), "failed to get cfg in axi_master_agent")
        end
        if(!uvm_config_db#(virtual axi_if#(.ID_WIDTH(ID_WIDTH)))::get(this, "", "vif", vif)) begin
            `uvm_fatal(get_type_name(), "failed to get vif in axi_master_agent")
        end

        sequencer = axi_master_sequencer::type_id::create("sequencer", this);
        driver = axi_master_driver::type_id::create("driver", this);
        monitor = axi_monitor#(ID_WIDTH, 0)::type_id::create("monitor", this); 
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        monitor.vif = vif;
        monitor.cfg = cfg;
        driver.vif = vif;
        driver.cfg = cfg;
        sequencer.vif = vif;
        sequencer.cfg = cfg;

        driver.seq_item_port.connect(sequencer.seq_item_export);
        monitor.item_observed_port.connect(item_collected_port);
    endfunction

    task run_phase(uvm_phase phase);
        super.run_phase(phase);
    endtask
endclass

`endif 
