`ifndef RKV_AXIRAM_SCOREBOARD_SV
`define RKV_AXIRAM_SCOREBOARD_SV

class rkv_axiram_scoreboard extends rkv_axiram_subscriber;

  // Memory model for scoreboard checking
  protected bit [31:0] mem_model[bit[31:0]];

  `uvm_component_utils(rkv_axiram_scoreboard)

  function new(string name = "rkv_axiram_scoreboard", uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  task run_phase(uvm_phase phase);
    super.run_phase(phase);
    do_data_check();
  endtask

  // Override write to perform checking
  virtual function void write(lvc_axi_transaction tr);
    super.write(tr);
    if(cfg.enable_scb) begin
      check_transaction(tr);
    end
  endfunction

  // Check transaction against memory model
  protected function void check_transaction(lvc_axi_transaction tr);
    bit [31:0] addr;
    bit [31:0] exp_data, act_data;
    int bytes_per_beat;
    
    bytes_per_beat = tr.get_bytes_per_beat();
    
    if(tr.trans_type == AXI_WRITE) begin
      // Update memory model with write data
      for(int i = 0; i <= tr.burst_length && i < tr.data.size(); i++) begin
        addr = tr.get_next_addr(i);
        // Apply strobe mask
        if(i < tr.strb.size()) begin
          for(int b = 0; b < bytes_per_beat && b < 4; b++) begin
            if(tr.strb[i][b]) begin
              mem_model[addr][b*8 +: 8] = tr.data[i][b*8 +: 8];
            end
          end
        end
        else begin
          mem_model[addr] = tr.data[i];
        end
        cfg.scb_check_count++;
        `uvm_info(get_type_name(), $sformatf("Memory model updated: addr=0x%0h, data=0x%0h", addr, mem_model[addr]), UVM_HIGH)
      end
    end
    else begin
      // Verify read data against memory model
      for(int i = 0; i <= tr.burst_length && i < tr.data.size(); i++) begin
        addr = tr.get_next_addr(i);
        cfg.scb_check_count++;
        
        if(mem_model.exists(addr)) begin
          exp_data = mem_model[addr];
          act_data = tr.data[i];
          
          if(exp_data !== act_data) begin
            cfg.scb_check_error++;
            `uvm_error(get_type_name(), $sformatf("Data mismatch at addr=0x%0h: expected=0x%0h, actual=0x%0h", 
                       addr, exp_data, act_data))
          end
          else begin
            `uvm_info(get_type_name(), $sformatf("Data match at addr=0x%0h: data=0x%0h", addr, act_data), UVM_HIGH)
          end
        end
        else begin
          // First read to this address, store the value
          mem_model[addr] = tr.data[i];
          `uvm_info(get_type_name(), $sformatf("First read at addr=0x%0h: data=0x%0h (stored)", addr, tr.data[i]), UVM_HIGH)
        end
      end
    end
  endfunction

  task do_listen_events();
    // Can add event-based checking here
  endtask

  virtual task do_data_check();
    // Additional checking logic can be added here
  endtask

  // Report phase - print summary
  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info(get_type_name(), $sformatf("Scoreboard Summary: checks=%0d, errors=%0d", 
              cfg.scb_check_count, cfg.scb_check_error), UVM_LOW)
  endfunction

endclass

`endif // RKV_AXIRAM_SCOREBOARD_SV
