`ifndef AXI_CROSSBAR_ENV_SV
`define AXI_CROSSBAR_ENV_SV

class axi_crossbar_env extends uvm_env;
    `uvm_component_utils(axi_crossbar_env)

    axi_configuration           cfg;
    axi_master_agent            mst_agent00;
    axi_master_agent            mst_agent01;
    axi_slave_agent             slv_agent00;
    axi_slave_agent             slv_agent01;
    axicb_virtual_sequencer     virt_sqr;
    axicb_scoreboard            scb;
    axicb_coverage              cov;

    function new(string name = "axi_crossbar_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        cfg = axi_configuration::type_id::create("cfg");
        uvm_root::get().set_timeout(cfg.sim_timeout, 1);
        uvm_config_db#(axi_configuration)::set(this, "mst_agent00", "cfg", cfg);
        uvm_config_db#(axi_configuration)::set(this, "mst_agent01", "cfg", cfg);
        uvm_config_db#(axi_configuration)::set(this, "slv_agent00", "cfg", cfg);
        uvm_config_db#(axi_configuration)::set(this, "slv_agent01", "cfg", cfg);

        mst_agent00 = axi_master_agent::type_id::create("mst_agent00", this);
        mst_agent01 = axi_master_agent::type_id::create("mst_agent01", this);
        slv_agent00 = axi_slave_agent::type_id::create("slv_agent00", this);
        slv_agent01 = axi_slave_agent::type_id::create("slv_agent01", this);
        
        virt_sqr = axicb_virtual_sequencer::type_id::create("virt_sqr", this);
        scb = axicb_scoreboard::type_id::create("scb", this);
        cov = axicb_coverage::type_id::create("cov", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        virt_sqr.cfg = cfg;
        virt_sqr.axi_mst_sqr00 = mst_agent00.sequencer;
        virt_sqr.axi_mst_sqr01 = mst_agent01.sequencer;
        mst_agent00.item_collected_port.connect(scb.analysis_export);
        mst_agent00.item_collected_port.connect(cov.analysis_export);
        mst_agent01.item_collected_port.connect(scb.analysis_export);
        mst_agent01.item_collected_port.connect(cov.analysis_export);
        slv_agent00.item_collected_port.connect(scb.analysis_export);
        slv_agent00.item_collected_port.connect(cov.analysis_export);
        slv_agent01.item_collected_port.connect(scb.analysis_export);
        slv_agent01.item_collected_port.connect(cov.analysis_export);
    endfunction

endclass

`endif 
