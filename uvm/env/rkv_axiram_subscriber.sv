`ifndef RKV_AXIRAM_SUBSCRIBER_SV
`define RKV_AXIRAM_SUBSCRIBER_SV

class rkv_axiram_subscriber extends uvm_component;

  // Analysis import for AXI transactions
  uvm_analysis_imp #(lvc_axi_transaction, rkv_axiram_subscriber) axi_trans_observed_imp;

  // Event pool
  protected uvm_event_pool _ep;
  
  // Configuration and interface
  rkv_axiram_config cfg;
  virtual rkv_axiram_if vif;

  `uvm_component_utils(rkv_axiram_subscriber)

  function new(string name = "rkv_axiram_subscriber", uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    axi_trans_observed_imp = new("axi_trans_observed_imp", this);
    
    // Get configuration
    if(!uvm_config_db#(rkv_axiram_config)::get(this, "", "cfg", cfg)) begin
      `uvm_fatal("GETCFG", "Cannot get config object from config DB")
    end
    vif = cfg.vif;
    
    // Create local event pool
    _ep = new("_ep");
  endfunction

  task run_phase(uvm_phase phase);
    super.run_phase(phase);
    do_events_trigger();
    do_listen_events();
  endtask

  // Called when a transaction is observed
  virtual function void write(lvc_axi_transaction tr);
    `uvm_info(get_type_name(), $sformatf("Transaction observed: %s", tr.convert2string()), UVM_HIGH)
  endfunction

  // Override in derived classes to trigger events
  virtual task do_events_trigger();
  endtask

  // Override in derived classes to listen for events
  virtual task do_listen_events();
  endtask

endclass

`endif // RKV_AXIRAM_SUBSCRIBER_SV
