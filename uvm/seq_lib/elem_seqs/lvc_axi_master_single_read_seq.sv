`ifndef LVC_AXI_MASTER_SINGLE_READ_SEQ_SV
`define LVC_AXI_MASTER_SINGLE_READ_SEQ_SV

class lvc_axi_master_single_read_seq extends uvm_sequence #(lvc_axi_master_transaction);

  rand bit [31:0] addr;
  rand bit [7:0]  id;
  
  // Output data
  bit [31:0] rdata;
  lvc_axi_resp_type_e resp;

  `uvm_object_utils_begin(lvc_axi_master_single_read_seq)
    `uvm_field_int(addr, UVM_ALL_ON)
    `uvm_field_int(id, UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "lvc_axi_master_single_read_seq");
    super.new(name);
  endfunction

  virtual task body();
    lvc_axi_master_transaction tr;
    
    `uvm_do_with(tr, {
      trans_type == AXI_READ;
      addr == local::addr;
      burst_length == 0;
      burst_size == AXI_SIZE_4BYTES;
      burst_type == AXI_BURST_INCR;
      id == local::id;
    })
    
    // Capture response
    if(tr.data.size() > 0)
      rdata = tr.data[0];
    if(tr.resp.size() > 0)
      resp = tr.resp[0];
  endtask

endclass

`endif // LVC_AXI_MASTER_SINGLE_READ_SEQ_SV
