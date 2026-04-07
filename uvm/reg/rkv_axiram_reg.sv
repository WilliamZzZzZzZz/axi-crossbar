`ifndef RKV_AXIRAM_REG_SV
`define RKV_AXIRAM_REG_SV

class rkv_axiram_rgm extends uvm_reg_block;

  `uvm_object_utils(rkv_axiram_rgm)

  uvm_reg_map map;
  
  function new(string name = "rkv_axiram_rgm");
    super.new(name, UVM_NO_COVERAGE);
  endfunction

  virtual function build();
    map = create_map("map", 'h0, 4, UVM_LITTLE_ENDIAN);
    // AXI RAM is a memory block, no specific registers defined
    // Users can extend this to add memory regions or specific registers
  endfunction

endclass

`endif // RKV_AXIRAM_REG_SV
