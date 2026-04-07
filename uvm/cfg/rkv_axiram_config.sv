`ifndef RKV_AXIRAM_CONFIG_SV
`define RKV_AXIRAM_CONFIG_SV

class rkv_axiram_config extends uvm_object;

  // Sequence check statistics
  int seq_check_count;
  int seq_check_error;

  // Scoreboard check statistics
  int scb_check_count;
  int scb_check_error;

  // Enable flags
  bit enable_cov = 1;
  bit enable_scb = 1;

  // AXI agent configuration
  lvc_axi_agent_configuration axi_cfg;
  
  // Virtual interface
  virtual rkv_axiram_if vif;
  
  // Register model
  rkv_axiram_rgm rgm;

  // DUT parameters (matching axi_ram.v defaults)
  int data_width = 32;
  int addr_width = 16;
  int id_width   = 8;
  int strb_width = 4;

  `uvm_object_utils(rkv_axiram_config)

  function new(string name = "rkv_axiram_config");
    super.new(name);
    axi_cfg = lvc_axi_agent_configuration::type_id::create("axi_cfg");
    // Configure AXI agent parameters to match DUT
    axi_cfg.addr_width = addr_width;
    axi_cfg.data_width = data_width;
    axi_cfg.id_width   = id_width;
    axi_cfg.strb_width = strb_width;
  endfunction

  // Update AXI configuration when DUT parameters change
  function void update_axi_cfg();
    axi_cfg.addr_width = addr_width;
    axi_cfg.data_width = data_width;
    axi_cfg.id_width   = id_width;
    axi_cfg.strb_width = strb_width;
  endfunction

endclass

`endif // RKV_AXIRAM_CONFIG_SV
