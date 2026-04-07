`ifndef RKV_AXIRAM_SMOKE_VIRT_SEQ_SV
`define RKV_AXIRAM_SMOKE_VIRT_SEQ_SV

class rkv_axiram_smoke_virt_seq extends rkv_axiram_base_virtual_sequence;

  `uvm_object_utils(rkv_axiram_smoke_virt_seq)

  function new(string name = "rkv_axiram_smoke_virt_seq");
    super.new(name);
  endfunction

  virtual task body();
    bit [31:0] addr;
    bit [31:0] wr_data, rd_data;
    bit [31:0] burst_wr_data[];
    bit [31:0] burst_rd_data[];
    int burst_len;

    super.body();
    `uvm_info("body", "=== AXI RAM Smoke Test Started ===", UVM_LOW)

    // Test 1: Single Write and Read
    `uvm_info("body", "Test 1: Single Write/Read Test", UVM_LOW)
    addr = 32'h0000_0000;
    wr_data = 32'hDEAD_BEEF;
    
    axi_single_write(addr, wr_data);
    axi_single_read(addr, rd_data);
    compare_data(wr_data, rd_data);

    // Test 2: Multiple single accesses
    `uvm_info("body", "Test 2: Multiple Single Accesses", UVM_LOW)
    for(int i = 0; i < 4; i++) begin
      addr = i * 4;
      wr_data = $urandom();
      axi_single_write(addr, wr_data);
      axi_single_read(addr, rd_data);
      compare_data(wr_data, rd_data);
    end

    // Test 3: Burst Write and Read
    `uvm_info("body", "Test 3: Burst Write/Read Test", UVM_LOW)
    addr = 32'h0000_0100;
    burst_len = 4;
    burst_wr_data = new[burst_len];
    for(int i = 0; i < burst_len; i++)
      burst_wr_data[i] = $urandom();
    
    axi_burst_write(addr, burst_wr_data, burst_len);
    axi_burst_read(addr, burst_rd_data, burst_len);
    
    for(int i = 0; i < burst_len; i++)
      compare_data(burst_wr_data[i], burst_rd_data[i]);

    // Test 4: Random access pattern
    `uvm_info("body", "Test 4: Random Access Pattern", UVM_LOW)
    for(int i = 0; i < 10; i++) begin
      addr = ($urandom() % 256) * 4;  // Random aligned address
      wr_data = $urandom();
      axi_single_write(addr, wr_data);
      axi_single_read(addr, rd_data);
      compare_data(wr_data, rd_data);
    end

    `uvm_info("body", "=== AXI RAM Smoke Test Completed ===", UVM_LOW)
    `uvm_info("body", "Exiting...", UVM_LOW)
  endtask

endclass

`endif // RKV_AXIRAM_SMOKE_VIRT_SEQ_SV
