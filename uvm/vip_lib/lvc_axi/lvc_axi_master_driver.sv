`ifndef LVC_AXI_MASTER_DRIVER_SV
`define LVC_AXI_MASTER_DRIVER_SV

class lvc_axi_master_driver extends uvm_driver #(lvc_axi_master_transaction);

  lvc_axi_agent_configuration cfg;
  virtual lvc_axi_if vif;

  // Internal state
  protected bit reset_asserted;

  `uvm_component_utils(lvc_axi_master_driver)

  function new(string name = "lvc_axi_master_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
  endfunction

  task run_phase(uvm_phase phase);
    super.run_phase(phase);
    
    // Initialize signals
    reset_signals();
    
    // Wait for reset to complete
    @(negedge vif.rst);
    
    forever begin
      fork
        // Monitor reset
        begin
          @(posedge vif.rst);
          reset_asserted = 1;
          reset_signals();
          @(negedge vif.rst);
          reset_asserted = 0;
        end
        // Main driver loop
        begin
          while(!reset_asserted) begin
            seq_item_port.get_next_item(req);
            drive_transaction(req);
            seq_item_port.item_done();
          end
        end
      join_any
      disable fork;
    end
  endtask

  // Reset all signals to default state
  task reset_signals();
    @(posedge vif.clk);
    // Write Address Channel
    vif.awid    <= '0;
    vif.awaddr  <= '0;
    vif.awlen   <= '0;
    vif.awsize  <= '0;
    vif.awburst <= '0;
    vif.awlock  <= '0;
    vif.awcache <= '0;
    vif.awprot  <= '0;
    vif.awvalid <= '0;
    // Write Data Channel
    vif.wdata   <= '0;
    vif.wstrb   <= '0;
    vif.wlast   <= '0;
    vif.wvalid  <= '0;
    // Write Response Channel
    vif.bready  <= '0;
    // Read Address Channel
    vif.arid    <= '0;
    vif.araddr  <= '0;
    vif.arlen   <= '0;
    vif.arsize  <= '0;
    vif.arburst <= '0;
    vif.arlock  <= '0;
    vif.arcache <= '0;
    vif.arprot  <= '0;
    vif.arvalid <= '0;
    // Read Data Channel
    vif.rready  <= '0;
  endtask

  // Main transaction driver
  task drive_transaction(lvc_axi_master_transaction tr);
    `uvm_info(get_type_name(), $sformatf("Driving transaction: %s", tr.convert2string()), UVM_HIGH)
    
    case(tr.trans_type)
      AXI_WRITE: drive_write_transaction(tr);
      AXI_READ:  drive_read_transaction(tr);
    endcase
  endtask

  // Drive write transaction (AW + W channels, then B channel)
  task drive_write_transaction(lvc_axi_master_transaction tr);
    fork
      // Write Address Channel
      drive_write_addr(tr);
      // Write Data Channel (can overlap with address)
      drive_write_data(tr);
    join
    
    // Wait for Write Response
    wait_write_response(tr);
  endtask

  // Drive write address channel
  task drive_write_addr(lvc_axi_master_transaction tr);
    // Apply address valid delay
    repeat(tr.addr_valid_delay) @(posedge vif.clk);
    
    @(posedge vif.clk);
    vif.awid    <= tr.id;
    vif.awaddr  <= tr.addr;
    vif.awlen   <= tr.burst_length;
    vif.awsize  <= tr.burst_size;
    vif.awburst <= tr.burst_type;
    vif.awlock  <= tr.lock;
    vif.awcache <= tr.cache;
    vif.awprot  <= tr.prot;
    vif.awvalid <= 1'b1;
    
    // Wait for ready
    do @(posedge vif.clk);
    while(!vif.awready);
    
    vif.awvalid <= 1'b0;
    `uvm_info(get_type_name(), "Write address phase completed", UVM_HIGH)
  endtask

  // Drive write data channel (all beats)
  task drive_write_data(lvc_axi_master_transaction tr);
    for(int i = 0; i <= tr.burst_length; i++) begin
      // Apply data valid delay
      if(i < tr.data_valid_delay.size())
        repeat(tr.data_valid_delay[i]) @(posedge vif.clk);
      
      @(posedge vif.clk);
      vif.wdata  <= tr.data[i];
      vif.wstrb  <= tr.strb[i];
      vif.wlast  <= (i == tr.burst_length);
      vif.wvalid <= 1'b1;
      
      // Wait for ready
      do @(posedge vif.clk);
      while(!vif.wready);
      
      `uvm_info(get_type_name(), $sformatf("Write data beat %0d completed", i), UVM_HIGH)
    end
    
    vif.wvalid <= 1'b0;
    vif.wlast  <= 1'b0;
    `uvm_info(get_type_name(), "Write data phase completed", UVM_HIGH)
  endtask

  // Wait for write response
  task wait_write_response(lvc_axi_master_transaction tr);
    int timeout_cnt = 0;
    
    // Apply response ready delay
    repeat(tr.resp_ready_delay) @(posedge vif.clk);
    
    @(posedge vif.clk);
    vif.bready <= 1'b1;
    
    // Wait for valid response
    while(!vif.bvalid && timeout_cnt < cfg.response_timeout) begin
      @(posedge vif.clk);
      timeout_cnt++;
    end
    
    if(timeout_cnt >= cfg.response_timeout)
      `uvm_error(get_type_name(), "Write response timeout!")
    else begin
      tr.bresp = lvc_axi_resp_type_e'(vif.bresp);
      `uvm_info(get_type_name(), $sformatf("Write response received: %s", tr.bresp.name()), UVM_HIGH)
    end
    
    @(posedge vif.clk);
    vif.bready <= 1'b0;
  endtask

  // Drive read transaction (AR channel, then R channel)
  task drive_read_transaction(lvc_axi_master_transaction tr);
    // Drive Read Address
    drive_read_addr(tr);
    
    // Receive Read Data
    receive_read_data(tr);
  endtask

  // Drive read address channel
  task drive_read_addr(lvc_axi_master_transaction tr);
    // Apply address valid delay
    repeat(tr.addr_valid_delay) @(posedge vif.clk);
    
    @(posedge vif.clk);
    vif.arid    <= tr.id;
    vif.araddr  <= tr.addr;
    vif.arlen   <= tr.burst_length;
    vif.arsize  <= tr.burst_size;
    vif.arburst <= tr.burst_type;
    vif.arlock  <= tr.lock;
    vif.arcache <= tr.cache;
    vif.arprot  <= tr.prot;
    vif.arvalid <= 1'b1;
    
    // Wait for ready
    do @(posedge vif.clk);
    while(!vif.arready);
    
    vif.arvalid <= 1'b0;
    `uvm_info(get_type_name(), "Read address phase completed", UVM_HIGH)
  endtask

  // Receive read data (all beats)
  task receive_read_data(lvc_axi_master_transaction tr);
    int beat_cnt = 0;
    int timeout_cnt = 0;
    
    // Prepare response array
    tr.resp = new[tr.burst_length + 1];
    
    @(posedge vif.clk);
    vif.rready <= 1'b1;
    
    while(beat_cnt <= tr.burst_length) begin
      if(vif.rvalid) begin
        tr.data[beat_cnt] = vif.rdata;
        tr.resp[beat_cnt] = lvc_axi_resp_type_e'(vif.rresp);
        
        `uvm_info(get_type_name(), $sformatf("Read data beat %0d: data=0x%0h, resp=%s, last=%0b", 
                  beat_cnt, tr.data[beat_cnt], tr.resp[beat_cnt].name(), vif.rlast), UVM_HIGH)
        
        // Check for last beat
        if(vif.rlast && beat_cnt != tr.burst_length)
          `uvm_warning(get_type_name(), $sformatf("Unexpected RLAST at beat %0d, expected at %0d", beat_cnt, tr.burst_length))
        
        beat_cnt++;
        timeout_cnt = 0;
      end
      else begin
        timeout_cnt++;
        if(timeout_cnt >= cfg.data_timeout) begin
          `uvm_error(get_type_name(), $sformatf("Read data timeout at beat %0d!", beat_cnt))
          break;
        end
      end
      @(posedge vif.clk);
    end
    
    vif.rready <= 1'b0;
    `uvm_info(get_type_name(), "Read data phase completed", UVM_HIGH)
  endtask

endclass

`endif // LVC_AXI_MASTER_DRIVER_SV
