`ifndef LVC_AXI_AGENT_CONFIGURATION_SV
`define LVC_AXI_AGENT_CONFIGURATION_SV

class lvc_axi_agent_configuration extends uvm_object;

  // Agent mode: active or passive
  bit is_active = 1;

  // AXI interface parameters
  int addr_width = 32;
  int data_width = 32;
  int id_width   = 8;
  int strb_width = 4;

  // Timeout settings
  int response_timeout = 1000;  // Clock cycles
  int data_timeout     = 1000;

  // Enable response randomization
  bit enable_random_delay = 0;
  int min_delay = 0;
  int max_delay = 10;

  // Coverage and checks
  bit enable_coverage = 1;
  bit enable_protocol_check = 1;

  // Outstanding transactions
  int max_outstanding_transactions = 16;

  `uvm_object_utils_begin(lvc_axi_agent_configuration)
    `uvm_field_int(is_active, UVM_ALL_ON)
    `uvm_field_int(addr_width, UVM_ALL_ON)
    `uvm_field_int(data_width, UVM_ALL_ON)
    `uvm_field_int(id_width, UVM_ALL_ON)
    `uvm_field_int(strb_width, UVM_ALL_ON)
    `uvm_field_int(response_timeout, UVM_ALL_ON)
    `uvm_field_int(data_timeout, UVM_ALL_ON)
    `uvm_field_int(enable_random_delay, UVM_ALL_ON)
    `uvm_field_int(enable_coverage, UVM_ALL_ON)
    `uvm_field_int(enable_protocol_check, UVM_ALL_ON)
    `uvm_field_int(max_outstanding_transactions, UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "lvc_axi_agent_configuration");
    super.new(name);
    strb_width = data_width / 8;
  endfunction

  // Compute strobe width from data width
  function void set_data_width(int width);
    data_width = width;
    strb_width = width / 8;
  endfunction

endclass

`endif // LVC_AXI_AGENT_CONFIGURATION_SV
