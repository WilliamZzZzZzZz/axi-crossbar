`ifndef AXIRAM_ENV_SV
`define AXIRAM_ENV_SV

class axiram_env extends uvm_env;
    `uvm_component_utils(axiram_env)

    axi_configuration           cfg;
    axi_master_agent            mst_agent;
    axiram_virtual_sequencer    virt_sqr;
    axiram_scoreboard           scb;
    axiram_coverage             cov;

    virtual axi_if vif;

    function new(string name = "axiram_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if(!uvm_config_db#(virtual axi_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal(get_type_name(), "Failed to get virtual interface 'vif' from config_db")
        end
        cfg = axi_configuration::type_id::create("cfg");

        uvm_config_db#(virtual axi_if)::set(this, "*", "vif", vif);
        uvm_config_db#(axi_configuration)::set(this, "*", "cfg", cfg);
        
        mst_agent = axi_master_agent::type_id::create("mst_agent", this);
        mst_agent.cfg = cfg;
        mst_agent.vif = vif;
        virt_sqr = axiram_virtual_sequencer::type_id::create("virt_sqr", this);
        scb = axiram_scoreboard::type_id::create("scb", this);
        cov = axiram_coverage::type_id::create("cov", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        virt_sqr.axi_mst_sqr = mst_agent.sequencer;
        mst_agent.item_collected_port.connect(scb.analysis_export);
        mst_agent.item_collected_port.connect(cov.analysis_export);
    endfunction

endclass

`endif 