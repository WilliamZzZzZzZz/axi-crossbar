`ifndef LVC_AXI_MASTER_SINGLE_WRITE_SEQ_SV
`define LVC_AXI_MASTER_SINGLE_WRITE_SEQ_SV

class lvc_axi_master_single_write_seq extends uvm_sequence #(lvc_axi_master_transaction);

  rand bit [31:0] addr;
  rand bit [31:0] data;
  rand bit [3:0]  strb;
  rand bit [7:0]  id;

  constraint c_default {
    strb == 4'hF;
  }

  `uvm_object_utils_begin(lvc_axi_master_single_write_seq)
    `uvm_field_int(addr, UVM_ALL_ON)
    `uvm_field_int(data, UVM_ALL_ON)
    `uvm_field_int(strb, UVM_ALL_ON)
    `uvm_field_int(id, UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "lvc_axi_master_single_write_seq");
    super.new(name);
  endfunction

  virtual task body();
    lvc_axi_master_transaction tr;
    
    `uvm_do_with(tr, {
      trans_type == AXI_WRITE;
      addr == local::addr;
      burst_length == 0;
      burst_size == AXI_SIZE_4BYTES;
      burst_type == AXI_BURST_INCR;
      id == local::id;
      data.size() == 1;
      data[0] == local::data;
      strb.size() == 1;
      strb[0] == local::strb;
    })
  endtask

endclass

`endif // LVC_AXI_MASTER_SINGLE_WRITE_SEQ_SV
