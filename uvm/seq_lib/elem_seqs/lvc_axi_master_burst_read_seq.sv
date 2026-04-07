`ifndef LVC_AXI_MASTER_BURST_READ_SEQ_SV
`define LVC_AXI_MASTER_BURST_READ_SEQ_SV

class lvc_axi_master_burst_read_seq extends uvm_sequence #(lvc_axi_master_transaction);

  rand bit [31:0] addr;
  rand bit [7:0]  burst_len;  // 0-255, actual length = burst_len + 1
  rand bit [7:0]  id;
  rand lvc_axi_burst_type_e burst_type;
  rand lvc_axi_size_e burst_size;
  
  // Output data
  bit [31:0] rdata_q[$];
  lvc_axi_resp_type_e resp_q[$];

  constraint c_default {
    burst_len inside {[0:15]};
    burst_type == AXI_BURST_INCR;
    burst_size == AXI_SIZE_4BYTES;
  }

  `uvm_object_utils_begin(lvc_axi_master_burst_read_seq)
    `uvm_field_int(addr, UVM_ALL_ON)
    `uvm_field_int(burst_len, UVM_ALL_ON)
    `uvm_field_int(id, UVM_ALL_ON)
    `uvm_field_enum(lvc_axi_burst_type_e, burst_type, UVM_ALL_ON)
    `uvm_field_enum(lvc_axi_size_e, burst_size, UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "lvc_axi_master_burst_read_seq");
    super.new(name);
  endfunction

  virtual task body();
    lvc_axi_master_transaction tr;
    
    `uvm_do_with(tr, {
      trans_type == AXI_READ;
      addr == local::addr;
      burst_length == local::burst_len;
      burst_size == local::burst_size;
      burst_type == local::burst_type;
      id == local::id;
    })
    
    // Capture response data
    rdata_q.delete();
    resp_q.delete();
    foreach(tr.data[i]) begin
      rdata_q.push_back(tr.data[i]);
    end
    foreach(tr.resp[i]) begin
      resp_q.push_back(tr.resp[i]);
    end
  endtask

endclass

`endif // LVC_AXI_MASTER_BURST_READ_SEQ_SV
