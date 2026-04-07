`ifndef RKV_AXIRAM_ENV_SV
`define RKV_AXIRAM_ENV_SV

class rkv_axiram_env extends uvm_env;

  // Components
  lvc_axi_master_agent axi_mst;
  rkv_axiram_config cfg;
  rkv_axiram_virtual_sequencer virt_sqr;
  rkv_axiram_rgm rgm;
  rkv_axiram_reg_adapter adapter;
  uvm_reg_predictor #(lvc_axi_transaction) predictor;
  rkv_axiram_cov cov;
  rkv_axiram_scoreboard scb;

  `uvm_component_utils(rkv_axiram_env)

  function new(string name = "rkv_axiram_env", uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    
    // Get configuration from test layer
    if(!uvm_config_db#(rkv_axiram_config)::get(this, "", "cfg", cfg)) begin
      `uvm_fatal("GETCFG", "Cannot get config object from config DB")
    end
    
    // Set configuration for sub-components
    uvm_config_db#(rkv_axiram_config)::set(this, "virt_sqr", "cfg", cfg);
    uvm_config_db#(rkv_axiram_config)::set(this, "cov", "cfg", cfg);
    uvm_config_db#(rkv_axiram_config)::set(this, "scb", "cfg", cfg);
    uvm_config_db#(lvc_axi_agent_configuration)::set(this, "axi_mst", "cfg", cfg.axi_cfg);
    
    // Create AXI master agent
    axi_mst = lvc_axi_master_agent::type_id::create("axi_mst", this);
    
    // Create virtual sequencer
    virt_sqr = rkv_axiram_virtual_sequencer::type_id::create("virt_sqr", this);
    
    // Get or create register model
    if(!uvm_config_db#(rkv_axiram_rgm)::get(this, "", "rgm", rgm)) begin
      rgm = rkv_axiram_rgm::type_id::create("rgm", this);
      rgm.build();
    end
    uvm_config_db#(rkv_axiram_rgm)::set(this, "*", "rgm", rgm);
    
    // Create register adapter and predictor
    adapter = rkv_axiram_reg_adapter::type_id::create("adapter", this);
    predictor = uvm_reg_predictor#(lvc_axi_transaction)::type_id::create("predictor", this);
    
    // Create coverage collector and scoreboard
    cov = rkv_axiram_cov::type_id::create("cov", this);
    scb = rkv_axiram_scoreboard::type_id::create("scb", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    
    // Connect virtual sequencer to agent sequencer
    virt_sqr.axi_mst_sqr = axi_mst.sequencer;
    
    // Connect register model
    rgm.map.set_sequencer(axi_mst.sequencer, adapter);
    
    // Connect predictor
    axi_mst.monitor.item_observed_port.connect(predictor.bus_in);
    predictor.map = rgm.map;
    predictor.adapter = adapter;
    
    // Connect coverage and scoreboard
    axi_mst.monitor.item_observed_port.connect(cov.axi_trans_observed_imp);
    axi_mst.monitor.item_observed_port.connect(scb.axi_trans_observed_imp);
  endfunction

  function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
  endfunction

  function void report_phase(uvm_phase phase);
    string reports = "\n";
    super.report_phase(phase);
    reports = {reports, $sformatf("=============================================== \n")};
    reports = {reports, $sformatf("CURRENT TEST SUMMARY \n")};
    reports = {reports, $sformatf("SEQUENCE CHECK COUNT : %0d \n", cfg.seq_check_count)};
    reports = {reports, $sformatf("SEQUENCE CHECK ERROR : %0d \n", cfg.seq_check_error)};
    reports = {reports, $sformatf("SCOREBOARD CHECK COUNT : %0d \n", cfg.scb_check_count)};
    reports = {reports, $sformatf("SCOREBOARD CHECK ERROR : %0d \n", cfg.scb_check_error)};
    reports = {reports, $sformatf("=============================================== \n")};
    `uvm_info("TEST_SUMMARY", reports, UVM_LOW)
  endfunction

endclass

`endif // RKV_AXIRAM_ENV_SV
