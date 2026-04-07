`ifndef RKV_AXIRAM_BASE_TEST_SV
`define RKV_AXIRAM_BASE_TEST_SV

virtual class rkv_axiram_base_test extends uvm_test;

  rkv_axiram_config cfg;
  rkv_axiram_env env;
  rkv_axiram_rgm rgm;

  function new(string name = "rkv_axiram_base_test", uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    
    // Create and build register model
    rgm = rkv_axiram_rgm::type_id::create("rgm");
    rgm.build();
    uvm_config_db#(rkv_axiram_rgm)::set(this, "env", "rgm", rgm);
    
    // Create configuration
    cfg = rkv_axiram_config::type_id::create("cfg");
    cfg.rgm = rgm;
    
    // Get virtual interface
    if(!uvm_config_db#(virtual rkv_axiram_if)::get(this, "", "vif", cfg.vif))
      `uvm_fatal("GETCFG", "Cannot get virtual interface from config DB")
    
    // Set configuration for environment
    uvm_config_db#(rkv_axiram_config)::set(this, "env", "cfg", cfg);
    
    // Create environment
    env = rkv_axiram_env::type_id::create("env", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
  endfunction

  task run_phase(uvm_phase phase);
    super.run_phase(phase);
    phase.phase_done.set_drain_time(this, 1us);
    phase.raise_objection(this);
    phase.drop_objection(this);
  endtask

endclass

`endif // RKV_AXIRAM_BASE_TEST_SV
