`ifndef AXI_SLAVE_AGENT_SV
`define AXI_SLAVE_AGENT_SV

class axi_slave_agent extends uvm_agent;
    `uvm_component_utils(axi_slave_agent)

    axi_configuration cfg;
    axi_slave_driver  driver;
    axi_master_monitor monitor;

    uvm_analysis_port #(axi_transaction) item_collected_port;

    virtual axi_if vif;

    function new(string name = "axi_slave_agent", uvm_component parent = null);
        super.new(name, parent);
        item_collected_port = new("item_collected_port", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (vif == null) begin
            if (!uvm_config_db#(virtual axi_if)::get(this, "", "vif", vif)) begin
                `uvm_fatal(get_type_name(), "Failed to get vif from config_db")
            end
        end

        if (cfg == null) begin
            if (!uvm_config_db#(axi_configuration)::get(this, "", "cfg", cfg)) begin
                `uvm_fatal(get_type_name(), "Failed to get cfg from config_db")
            end
        end

        driver  = axi_slave_driver::type_id::create("driver", this);
        monitor = axi_master_monitor::type_id::create("monitor", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        driver.vif = vif;
        driver.cfg = cfg;

        monitor.vif = vif;
        monitor.cfg = cfg;

        monitor.item_observed_port.connect(item_collected_port);
    endfunction

endclass

`endif
