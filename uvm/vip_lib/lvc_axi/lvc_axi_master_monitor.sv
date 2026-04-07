`ifndef LVC_AXI_MASTER_MONITOR_SV
`define LVC_AXI_MASTER_MONITOR_SV

class lvc_axi_master_monitor extends lvc_axi_monitor;

  lvc_axi_agent_configuration cfg;
  virtual lvc_axi_if vif;

  // Internal queues for tracking outstanding transactions
  protected lvc_axi_transaction write_addr_queue[$];
  protected lvc_axi_transaction read_addr_queue[$];
  protected bit [7:0] write_data_queue[bit[`LVC_AXI_MAX_ID_WIDTH-1:0]][$];
  protected bit [`LVC_AXI_MAX_DATA_WIDTH-1:0] write_data_storage[bit[`LVC_AXI_MAX_ID_WIDTH-1:0]][$];
  protected bit [`LVC_AXI_MAX_STRB_WIDTH-1:0] write_strb_storage[bit[`LVC_AXI_MAX_ID_WIDTH-1:0]][$];

  `uvm_component_utils(lvc_axi_master_monitor)

  function new(string name = "lvc_axi_master_monitor", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
  endfunction

  task run_phase(uvm_phase phase);
    // Wait for reset to complete
    @(negedge vif.rst);
    
    fork
      monitor_write_addr_channel();
      monitor_write_data_channel();
      monitor_write_resp_channel();
      monitor_read_addr_channel();
      monitor_read_data_channel();
    join
  endtask

  // Monitor Write Address Channel
  task monitor_write_addr_channel();
    lvc_axi_transaction tr;
    
    forever begin
      @(posedge vif.clk);
      if(vif.awvalid && vif.awready) begin
        tr = lvc_axi_transaction::type_id::create("write_addr_tr");
        tr.trans_type   = AXI_WRITE;
        tr.id           = vif.awid;
        tr.addr         = vif.awaddr;
        tr.burst_length = vif.awlen;
        tr.burst_size   = lvc_axi_size_e'(vif.awsize);
        tr.burst_type   = lvc_axi_burst_type_e'(vif.awburst);
        tr.lock         = vif.awlock;
        tr.cache        = vif.awcache;
        tr.prot         = vif.awprot;
        tr.start_time   = $time;
        
        // Allocate data array
        tr.data = new[tr.burst_length + 1];
        tr.strb = new[tr.burst_length + 1];
        
        write_addr_queue.push_back(tr);
        `uvm_info(get_type_name(), $sformatf("Write address observed: addr=0x%0h, len=%0d, id=0x%0h", 
                  tr.addr, tr.burst_length, tr.id), UVM_HIGH)
      end
    end
  endtask

  // Monitor Write Data Channel
  task monitor_write_data_channel();
    bit [`LVC_AXI_MAX_DATA_WIDTH-1:0] data;
    bit [`LVC_AXI_MAX_STRB_WIDTH-1:0] strb;
    bit last;
    int beat_cnt;
    
    forever begin
      @(posedge vif.clk);
      if(vif.wvalid && vif.wready) begin
        data = vif.wdata;
        strb = vif.wstrb;
        last = vif.wlast;
        
        // Find matching write address transaction
        foreach(write_addr_queue[i]) begin
          if(write_addr_queue[i].data.size() > 0) begin
            // Count how many data beats we have for this transaction
            beat_cnt = 0;
            foreach(write_addr_queue[i].data[j]) begin
              if(write_addr_queue[i].data[j] !== '0 || write_addr_queue[i].strb[j] !== '0)
                beat_cnt++;
              else
                break;
            end
            
            if(beat_cnt <= write_addr_queue[i].burst_length) begin
              write_addr_queue[i].data[beat_cnt] = data;
              write_addr_queue[i].strb[beat_cnt] = strb;
              `uvm_info(get_type_name(), $sformatf("Write data beat %0d observed: data=0x%0h, strb=0x%0h, last=%0b", 
                        beat_cnt, data, strb, last), UVM_HIGH)
              break;
            end
          end
        end
      end
    end
  endtask

  // Monitor Write Response Channel
  task monitor_write_resp_channel();
    lvc_axi_transaction tr;
    int idx;
    
    forever begin
      @(posedge vif.clk);
      if(vif.bvalid && vif.bready) begin
        // Find matching transaction by ID
        idx = -1;
        foreach(write_addr_queue[i]) begin
          if(write_addr_queue[i].id == vif.bid) begin
            idx = i;
            break;
          end
        end
        
        if(idx >= 0) begin
          tr = write_addr_queue[idx];
          tr.bresp = lvc_axi_resp_type_e'(vif.bresp);
          tr.end_time = $time;
          
          `uvm_info(get_type_name(), $sformatf("Write response observed: id=0x%0h, resp=%s", 
                    tr.id, tr.bresp.name()), UVM_HIGH)
          
          // Remove from queue and publish
          write_addr_queue.delete(idx);
          item_observed_port.write(tr);
          write_observed_port.write(tr);
        end
        else begin
          `uvm_warning(get_type_name(), $sformatf("Write response with unmatched ID: 0x%0h", vif.bid))
        end
      end
    end
  endtask

  // Monitor Read Address Channel
  task monitor_read_addr_channel();
    lvc_axi_transaction tr;
    
    forever begin
      @(posedge vif.clk);
      if(vif.arvalid && vif.arready) begin
        tr = lvc_axi_transaction::type_id::create("read_addr_tr");
        tr.trans_type   = AXI_READ;
        tr.id           = vif.arid;
        tr.addr         = vif.araddr;
        tr.burst_length = vif.arlen;
        tr.burst_size   = lvc_axi_size_e'(vif.arsize);
        tr.burst_type   = lvc_axi_burst_type_e'(vif.arburst);
        tr.lock         = vif.arlock;
        tr.cache        = vif.arcache;
        tr.prot         = vif.arprot;
        tr.start_time   = $time;
        
        // Allocate arrays
        tr.data = new[tr.burst_length + 1];
        tr.resp = new[tr.burst_length + 1];
        
        read_addr_queue.push_back(tr);
        `uvm_info(get_type_name(), $sformatf("Read address observed: addr=0x%0h, len=%0d, id=0x%0h", 
                  tr.addr, tr.burst_length, tr.id), UVM_HIGH)
      end
    end
  endtask

  // Monitor Read Data Channel
  task monitor_read_data_channel();
    lvc_axi_transaction tr;
    int idx;
    int beat_cnt;
    
    forever begin
      @(posedge vif.clk);
      if(vif.rvalid && vif.rready) begin
        // Find matching transaction by ID
        idx = -1;
        foreach(read_addr_queue[i]) begin
          if(read_addr_queue[i].id == vif.rid) begin
            idx = i;
            break;
          end
        end
        
        if(idx >= 0) begin
          tr = read_addr_queue[idx];
          
          // Count beats received so far
          beat_cnt = 0;
          foreach(tr.data[j]) begin
            if(tr.resp[j] !== lvc_axi_resp_type_e'(0) || tr.data[j] !== '0)
              beat_cnt++;
            else
              break;
          end
          
          // Store data
          if(beat_cnt <= tr.burst_length) begin
            tr.data[beat_cnt] = vif.rdata;
            tr.resp[beat_cnt] = lvc_axi_resp_type_e'(vif.rresp);
            
            `uvm_info(get_type_name(), $sformatf("Read data beat %0d observed: data=0x%0h, resp=%s, last=%0b", 
                      beat_cnt, tr.data[beat_cnt], tr.resp[beat_cnt].name(), vif.rlast), UVM_HIGH)
          end
          
          // Check if last beat
          if(vif.rlast) begin
            tr.end_time = $time;
            read_addr_queue.delete(idx);
            item_observed_port.write(tr);
            read_observed_port.write(tr);
          end
        end
        else begin
          `uvm_warning(get_type_name(), $sformatf("Read data with unmatched ID: 0x%0h", vif.rid))
        end
      end
    end
  endtask

endclass

`endif // LVC_AXI_MASTER_MONITOR_SV
