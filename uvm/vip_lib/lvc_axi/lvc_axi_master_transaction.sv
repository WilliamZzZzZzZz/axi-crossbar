`ifndef LVC_AXI_MASTER_TRANSACTION_SV
`define LVC_AXI_MASTER_TRANSACTION_SV

class lvc_axi_master_transaction extends lvc_axi_transaction;

  // Additional master-specific fields
  rand int unsigned addr_valid_delay;   // Delay before asserting valid
  rand int unsigned data_valid_delay[]; // Delay between data beats
  rand int unsigned resp_ready_delay;   // Delay before asserting ready for response

  // Constraint for delays
  constraint c_delays {
    addr_valid_delay inside {[0:5]};
    resp_ready_delay inside {[0:5]};
    data_valid_delay.size() == burst_length + 1;
    foreach(data_valid_delay[i]) {
      data_valid_delay[i] inside {[0:5]};
    }
  }

  `uvm_object_utils_begin(lvc_axi_master_transaction)
    `uvm_field_int(addr_valid_delay, UVM_ALL_ON)
    `uvm_field_array_int(data_valid_delay, UVM_ALL_ON)
    `uvm_field_int(resp_ready_delay, UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "lvc_axi_master_transaction");
    super.new(name);
    data_valid_delay = new[1];
  endfunction

  function void post_randomize();
    // Ensure data_valid_delay array matches burst length
    if(data_valid_delay.size() != burst_length + 1) begin
      data_valid_delay = new[burst_length + 1];
      foreach(data_valid_delay[i])
        data_valid_delay[i] = $urandom_range(0, 5);
    end
  endfunction

endclass

`endif // LVC_AXI_MASTER_TRANSACTION_SV
