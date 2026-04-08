`ifndef AXIRAM_ENV_SV
`define AXIRAM_ENV_SV

class axiram_env extends uvm_env;
    `uvm_component_utils(axiram_env)

    axi_configuration           mst_cfg[2];
    axi_configuration           slv_cfg[2];

    axi_master_agent            mst_agent[2];
    axi_slave_agent             slv_agent[2];

    axiram_virtual_sequencer    virt_sqr;
    axiram_scoreboard           scb;
    axiram_coverage             cov;

    virtual axi_if s_vif[2];
    virtual axi_if m_vif[2];

    function new(string name = "axiram_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(virtual axi_if)::get(this, "", "s00_vif", s_vif[0]))
            `uvm_fatal(get_type_name(), "Failed to get s00_vif")
        if (!uvm_config_db#(virtual axi_if)::get(this, "", "s01_vif", s_vif[1]))
            `uvm_fatal(get_type_name(), "Failed to get s01_vif")

        if (!uvm_config_db#(virtual axi_if)::get(this, "", "m00_vif", m_vif[0]))
            `uvm_fatal(get_type_name(), "Failed to get m00_vif")
        if (!uvm_config_db#(virtual axi_if)::get(this, "", "m01_vif", m_vif[1]))
            `uvm_fatal(get_type_name(), "Failed to get m01_vif")

        for (int i = 0; i < 2; i++) begin
            mst_cfg[i] = axi_configuration::type_id::create($sformatf("mst_cfg%0d", i));
            mst_cfg[i].agent_port_idx = i;
            mst_cfg[i].is_slave_agent = 0;

            mst_agent[i] = axi_master_agent::type_id::create($sformatf("mst_agent%0d", i), this);
            mst_agent[i].cfg = mst_cfg[i];
            mst_agent[i].vif = s_vif[i];

            slv_cfg[i] = axi_configuration::type_id::create($sformatf("slv_cfg%0d", i));
            slv_cfg[i].agent_port_idx = i;
            slv_cfg[i].is_slave_agent = 1;

            slv_agent[i] = axi_slave_agent::type_id::create($sformatf("slv_agent%0d", i), this);
            slv_agent[i].cfg = slv_cfg[i];
            slv_agent[i].vif = m_vif[i];
        end

        virt_sqr = axiram_virtual_sequencer::type_id::create("virt_sqr", this);
        scb      = axiram_scoreboard::type_id::create("scb", this);
        cov      = axiram_coverage::type_id::create("cov", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        for (int i = 0; i < 2; i++) begin
            virt_sqr.axi_mst_sqr[i] = mst_agent[i].sequencer;

            // Data/model checks are based on master-observed transactions.
            mst_agent[i].item_collected_port.connect(scb.analysis_export);
            mst_agent[i].item_collected_port.connect(cov.analysis_export);

            // Route checks use m-side observations.
            slv_agent[i].item_collected_port.connect(scb.analysis_export);
        end
    endfunction

endclass

`endif
