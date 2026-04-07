`ifndef RKV_AXIRAM_REG_ADAPTER_SV
`define RKV_AXIRAM_REG_ADAPTER_SV

class rkv_axiram_reg_adapter extends uvm_reg_adapter;

  `uvm_object_utils(rkv_axiram_reg_adapter)

  function new(string name = "rkv_axiram_reg_adapter");
    super.new(name);
    provides_responses = 1;
  endfunction

  // Convert UVM register operation to AXI transaction
  function uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw);
    lvc_axi_master_transaction axi_tr;
    
    axi_tr = lvc_axi_master_transaction::type_id::create("axi_tr");
    
    axi_tr.addr = rw.addr;
    axi_tr.burst_length = 0;  // Single beat
    axi_tr.burst_size = AXI_SIZE_4BYTES;
    axi_tr.burst_type = AXI_BURST_INCR;
    axi_tr.id = 0;
    
    if(rw.kind == UVM_WRITE) begin
      axi_tr.trans_type = AXI_WRITE;
      axi_tr.data = new[1];
      axi_tr.strb = new[1];
      axi_tr.data[0] = rw.data;
      axi_tr.strb[0] = '1;
    end
    else begin
      axi_tr.trans_type = AXI_READ;
      axi_tr.data = new[1];
      axi_tr.strb = new[1];
    end
    
    return axi_tr;
  endfunction

  // Convert AXI transaction response to UVM register operation
  function void bus2reg(uvm_sequence_item bus_item, ref uvm_reg_bus_op rw);
    lvc_axi_transaction axi_tr;
    
    if(!$cast(axi_tr, bus_item)) begin
      `uvm_fatal(get_type_name(), "Failed to cast bus_item to lvc_axi_transaction")
      return;
    end
    
    rw.addr = axi_tr.addr;
    
    if(axi_tr.trans_type == AXI_WRITE) begin
      rw.kind = UVM_WRITE;
      if(axi_tr.data.size() > 0)
        rw.data = axi_tr.data[0];
      // Check write response
      rw.status = (axi_tr.bresp == AXI_RESP_OKAY) ? UVM_IS_OK : UVM_NOT_OK;
    end
    else begin
      rw.kind = UVM_READ;
      if(axi_tr.data.size() > 0)
        rw.data = axi_tr.data[0];
      // Check read response
      if(axi_tr.resp.size() > 0)
        rw.status = (axi_tr.resp[0] == AXI_RESP_OKAY) ? UVM_IS_OK : UVM_NOT_OK;
      else
        rw.status = UVM_IS_OK;
    end
  endfunction

endclass

`endif // RKV_AXIRAM_REG_ADAPTER_SV
