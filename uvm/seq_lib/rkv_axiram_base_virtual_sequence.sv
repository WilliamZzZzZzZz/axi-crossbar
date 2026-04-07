`ifndef RKV_AXIRAM_BASE_VIRTUAL_SEQUENCE_SV
`define RKV_AXIRAM_BASE_VIRTUAL_SEQUENCE_SV

class rkv_axiram_base_virtual_sequence extends uvm_sequence;

  rkv_axiram_config cfg;
  virtual rkv_axiram_if vif;
  rkv_axiram_rgm rgm;
  
  bit [31:0] wr_val, rd_val;
  uvm_status_e status;

  `uvm_object_utils(rkv_axiram_base_virtual_sequence)
  `uvm_declare_p_sequencer(rkv_axiram_virtual_sequencer)

  function new(string name = "rkv_axiram_base_virtual_sequence");
    super.new(name);
  endfunction

  virtual task body();
    `uvm_info("body", "Entered...", UVM_LOW)
    // Get cfg from p_sequencer
    cfg = p_sequencer.cfg;
    vif = cfg.vif;
    rgm = cfg.rgm;
    // TODO in sub-class
    `uvm_info("body", "Exiting...", UVM_LOW)
  endtask

  // Compare data utility
  virtual function void compare_data(logic [31:0] val1, logic [31:0] val2);
    cfg.seq_check_count++;
    if(val1 === val2)
      `uvm_info("CMPSUC", $sformatf("val1 'h%0x === val2 'h%0x", val1, val2), UVM_LOW)
    else begin
      cfg.seq_check_error++;
      `uvm_error("CMPERR", $sformatf("val1 'h%0x !== val2 'h%0x", val1, val2))
    end
  endfunction

  // Wait for reset assertion
  task wait_reset_signal_asserted();
    @(posedge vif.rst);
  endtask

  // Wait for reset release
  task wait_reset_signal_released();
    @(negedge vif.rst);
  endtask

  // Helper task: Single write transaction
  task axi_single_write(input bit [31:0] addr, input bit [31:0] data, input bit [3:0] strb = 4'hF);
    lvc_axi_master_transaction tr;
    tr = lvc_axi_master_transaction::type_id::create("wr_tr");
    tr.trans_type = AXI_WRITE;
    tr.addr = addr;
    tr.burst_length = 0;
    tr.burst_size = AXI_SIZE_4BYTES;
    tr.burst_type = AXI_BURST_INCR;
    tr.data = new[1];
    tr.strb = new[1];
    tr.data[0] = data;
    tr.strb[0] = strb;
    tr.id = $urandom_range(0, 255);
    `uvm_send(tr)
  endtask

  // Helper task: Single read transaction
  task axi_single_read(input bit [31:0] addr, output bit [31:0] data);
    lvc_axi_master_transaction tr;
    tr = lvc_axi_master_transaction::type_id::create("rd_tr");
    tr.trans_type = AXI_READ;
    tr.addr = addr;
    tr.burst_length = 0;
    tr.burst_size = AXI_SIZE_4BYTES;
    tr.burst_type = AXI_BURST_INCR;
    tr.data = new[1];
    tr.strb = new[1];
    tr.id = $urandom_range(0, 255);
    `uvm_send(tr)
    data = tr.data[0];
  endtask

  // Helper task: Burst write transaction
  task axi_burst_write(input bit [31:0] addr, input bit [31:0] data[], input int burst_len);
    lvc_axi_master_transaction tr;
    tr = lvc_axi_master_transaction::type_id::create("burst_wr_tr");
    tr.trans_type = AXI_WRITE;
    tr.addr = addr;
    tr.burst_length = burst_len - 1;
    tr.burst_size = AXI_SIZE_4BYTES;
    tr.burst_type = AXI_BURST_INCR;
    tr.data = new[burst_len];
    tr.strb = new[burst_len];
    for(int i = 0; i < burst_len; i++) begin
      tr.data[i] = data[i];
      tr.strb[i] = 4'hF;
    end
    tr.id = $urandom_range(0, 255);
    `uvm_send(tr)
  endtask

  // Helper task: Burst read transaction
  task axi_burst_read(input bit [31:0] addr, output bit [31:0] data[], input int burst_len);
    lvc_axi_master_transaction tr;
    tr = lvc_axi_master_transaction::type_id::create("burst_rd_tr");
    tr.trans_type = AXI_READ;
    tr.addr = addr;
    tr.burst_length = burst_len - 1;
    tr.burst_size = AXI_SIZE_4BYTES;
    tr.burst_type = AXI_BURST_INCR;
    tr.data = new[burst_len];
    tr.strb = new[burst_len];
    tr.id = $urandom_range(0, 255);
    `uvm_send(tr)
    data = tr.data;
  endtask

endclass

`endif // RKV_AXIRAM_BASE_VIRTUAL_SEQUENCE_SV
