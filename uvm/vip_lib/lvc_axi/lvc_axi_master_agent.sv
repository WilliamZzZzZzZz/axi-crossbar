`ifndef LVC_AXI_MASTER_AGENT_SV
`define LVC_AXI_MASTER_AGENT_SV

class lvc_axi_master_agent extends uvm_agent;
  
  lvc_axi_agent_configuration cfg;
  
  lvc_axi_master_driver    driver;
  lvc_axi_master_monitor   monitor;
  lvc_axi_master_sequencer sequencer;
  
  virtual lvc_axi_if vif;

  `uvm_component_utils(lvc_axi_master_agent)

  function new(string name = "lvc_axi_master_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    
    // Get configuration
    if(!uvm_config_db#(lvc_axi_agent_configuration)::get(this, "", "cfg", cfg)) begin
      `uvm_fatal("GETCFG", "Cannot get AXI agent configuration from config DB")
    end
    
    // Get virtual interface
    if(!uvm_config_db#(virtual lvc_axi_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("GETVIF", "Cannot get AXI virtual interface from config DB")
    end
    
    // Create monitor (always present)
    monitor = lvc_axi_master_monitor::type_id::create("monitor", this);
    
    // Create driver and sequencer if active
    if(cfg.is_active) begin
      driver    = lvc_axi_master_driver::type_id::create("driver", this);
      sequencer = lvc_axi_master_sequencer::type_id::create("sequencer", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    
    // Connect monitor to interface
    monitor.vif = vif;
    monitor.cfg = cfg;
    
    // Connect driver and sequencer if active
    if(cfg.is_active) begin
      driver.seq_item_port.connect(sequencer.seq_item_export);
      driver.vif = vif;
      driver.cfg = cfg;
      sequencer.vif = vif;
      sequencer.cfg = cfg;
    end
  endfunction

  task run_phase(uvm_phase phase);
    super.run_phase(phase);
  endtask

endclass

`endif // LVC_AXI_MASTER_AGENT_SV
