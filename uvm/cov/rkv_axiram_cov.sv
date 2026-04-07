`ifndef RKV_AXIRAM_COV_SV
`define RKV_AXIRAM_COV_SV

class rkv_axiram_cov extends rkv_axiram_subscriber;

  `uvm_component_utils(rkv_axiram_cov)

  // Coverage groups
  covergroup axi_trans_cg with function sample(lvc_axi_transaction tr);
    option.per_instance = 1;
    
    // Transaction type coverage
    trans_type_cp: coverpoint tr.trans_type {
      bins read  = {AXI_READ};
      bins write = {AXI_WRITE};
    }
    
    // Burst type coverage
    burst_type_cp: coverpoint tr.burst_type {
      bins fixed = {AXI_BURST_FIXED};
      bins incr  = {AXI_BURST_INCR};
      bins wrap  = {AXI_BURST_WRAP};
    }
    
    // Burst size coverage
    burst_size_cp: coverpoint tr.burst_size {
      bins size_1B   = {AXI_SIZE_1BYTE};
      bins size_2B   = {AXI_SIZE_2BYTES};
      bins size_4B   = {AXI_SIZE_4BYTES};
    }
    
    // Burst length coverage
    burst_length_cp: coverpoint tr.burst_length {
      bins single = {0};
      bins short_burst = {[1:7]};
      bins medium_burst = {[8:31]};
      bins long_burst = {[32:255]};
    }
    
    // Address alignment coverage
    addr_align_cp: coverpoint tr.addr[1:0] {
      bins aligned = {0};
      bins unaligned = {[1:3]};
    }
    
    // Cross coverage
    trans_x_burst_type: cross trans_type_cp, burst_type_cp;
    trans_x_burst_size: cross trans_type_cp, burst_size_cp;
    trans_x_burst_len:  cross trans_type_cp, burst_length_cp;
  endgroup

  covergroup axi_resp_cg with function sample(lvc_axi_transaction tr);
    option.per_instance = 1;
    
    // Write response coverage
    write_resp_cp: coverpoint tr.bresp iff (tr.trans_type == AXI_WRITE) {
      bins okay   = {AXI_RESP_OKAY};
      bins exokay = {AXI_RESP_EXOKAY};
      bins slverr = {AXI_RESP_SLVERR};
      bins decerr = {AXI_RESP_DECERR};
    }
  endgroup

  function new(string name = "rkv_axiram_cov", uvm_component parent);
    super.new(name, parent);
    axi_trans_cg = new();
    axi_resp_cg  = new();
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  // Override write to sample coverage
  virtual function void write(lvc_axi_transaction tr);
    super.write(tr);
    if(cfg.enable_cov) begin
      axi_trans_cg.sample(tr);
      axi_resp_cg.sample(tr);
    end
  endfunction

  task do_listen_events();
    // Can add event-based coverage sampling here
  endtask

endclass

`endif // RKV_AXIRAM_COV_SV
