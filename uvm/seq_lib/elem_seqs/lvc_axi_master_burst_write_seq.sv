`ifndef LVC_AXI_MASTER_BURST_WRITE_SEQ_SV
`define LVC_AXI_MASTER_BURST_WRITE_SEQ_SV

class lvc_axi_master_burst_write_seq extends uvm_sequence #(lvc_axi_master_transaction);

  rand bit [31:0] addr;
  rand bit [7:0]  burst_len;  // 0-255, actual length = burst_len + 1
  rand bit [7:0]  id;
  rand lvc_axi_burst_type_e burst_type;
  rand lvc_axi_size_e burst_size;
  
  bit [31:0] data_q[$];  // Queue of data to write

  constraint c_default {
    burst_len inside {[0:15]};
    burst_type == AXI_BURST_INCR;
    burst_size == AXI_SIZE_4BYTES;
  }

  `uvm_object_utils_begin(lvc_axi_master_burst_write_seq)
    `uvm_field_int(addr, UVM_ALL_ON)
    `uvm_field_int(burst_len, UVM_ALL_ON)
    `uvm_field_int(id, UVM_ALL_ON)
    `uvm_field_enum(lvc_axi_burst_type_e, burst_type, UVM_ALL_ON)
    `uvm_field_enum(lvc_axi_size_e, burst_size, UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "lvc_axi_master_burst_write_seq");
    super.new(name);
  endfunction

  virtual task body();
    lvc_axi_master_transaction tr;
    
    tr = lvc_axi_master_transaction::type_id::create("tr");
    
    start_item(tr);
    
    if(!tr.randomize() with {
      trans_type == AXI_WRITE;
      addr == local::addr;
      burst_length == local::burst_len;
      burst_size == local::burst_size;
      burst_type == local::burst_type;
      id == local::id;
    }) begin
      `uvm_error(get_type_name(), "Randomization failed")
    end
    
    // Fill data array
    if(data_q.size() > 0) begin
      tr.data = new[burst_len + 1];
      tr.strb = new[burst_len + 1];
      for(int i = 0; i <= burst_len; i++) begin
        tr.data[i] = (i < data_q.size()) ? data_q[i] : $urandom();
        tr.strb[i] = '1;
      end
    end
    
    finish_item(tr);
  endtask

endclass

`endif // LVC_AXI_MASTER_BURST_WRITE_SEQ_SV
