`ifndef AXI_CROSSBAR_ENV_SV
`define AXI_CROSSBAR_ENV_SV

class axi_crossbar_env extends uvm_env;
    `uvm_component_utils(axiram_env)

    axi_configuration           cfg;
    axi_master_agent            mst_agent00;
    axi_master_agent            mst_agent01;
    axi_slave_agent             slv_agent00;
    axi_slave_agent             slv_agent01;
    axiram_virtual_sequencer    virt_sqr;
    axiram_scoreboard           scb;
    axiram_coverage             cov;

    virtual axi_if m00_vif;
    virtual axi_if m01_vif;
    virtual axi_if s00_vif;
    virtual axi_if s01_vif;

    function new(string name = "axi_crossbar_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        if(!uvm_config_db#(virtual axi_if)::get(this, "", "m00_vif", m00_vif)) begin
            `uvm_fatal(get_type_name(), "Failed to get virtual interface 's00_vif' from config_db")
        end
        if(!uvm_config_db#(virtual axi_if)::get(this, "", "m01_vif", m01_vif)) begin
            `uvm_fatal(get_type_name(), "Failed to get virtual interface 's00_vif' from config_db")
        end
        if(!uvm_config_db#(virtual axi_if)::get(this, "", "s00_vif", s00_vif)) begin
            `uvm_fatal(get_type_name(), "Failed to get virtual interface 's00_vif' from config_db")
        end
        if(!uvm_config_db#(virtual axi_if)::get(this, "", "s01_vif", s01_vif)) begin
            `uvm_fatal(get_type_name(), "Failed to get virtual interface 's00_vif' from config_db")
        end

        cfg = axi_configuration::type_id::create("cfg");
        
        mst_agent00 = axi_master_agent::type_id::create("mst_agent00", this);
        mst_agent01 = axi_master_agent::type_id::create("mst_agent01", this);
        slv_agent00 = axi_slave_agent::type_id::create("slv_agent00", this);
        slv_agent01 = axi_slave_agent::type_id::create("slv_agent01", this);

        mst_agent00.cfg = cfg;
        mst_agent01.cfg = cfg;
        slv_agent00.cfg = cfg;
        slv_agent01.cfg = cfg;

        mst_agent00.vif = s00_vif;
        mst_agent01.vif = s01_vif;
        slv_agent00.vif = m00_vif;
        slv_agent01.vif = m01_vif;
        
        virt_sqr = axiram_virtual_sequencer::type_id::create("virt_sqr", this);
        scb = axiram_scoreboard::type_id::create("scb", this);
        cov = axiram_coverage::type_id::create("cov", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        virt_sqr.axi_mst_sqr = mst_agent.sequencer;
        mst_agent00.item_collected_port.connect(scb.analysis_export);
        mst_agent01.item_collected_port.connect(cov.analysis_export);
        slv_agent00.item_collected_port.connect(scb.analysis_export);
        slv_agent01.item_collected_port.connect(cov.analysis_export);
    endfunction

endclass

`endif 