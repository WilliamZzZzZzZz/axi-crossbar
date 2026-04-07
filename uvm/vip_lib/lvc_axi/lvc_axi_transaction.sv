`ifndef LVC_AXI_TRANSACTION_SV
`define LVC_AXI_TRANSACTION_SV

class lvc_axi_transaction extends uvm_sequence_item;

  // Transaction type
  rand lvc_axi_trans_type_e trans_type;

  // Address channel fields
  rand bit [`LVC_AXI_MAX_ID_WIDTH-1:0]   id;
  rand bit [`LVC_AXI_MAX_ADDR_WIDTH-1:0] addr;
  rand bit [7:0]                          burst_length;  // awlen/arlen: actual_length = burst_length + 1
  rand lvc_axi_size_e                     burst_size;
  rand lvc_axi_burst_type_e               burst_type;
  rand bit                                lock;
  rand bit [3:0]                          cache;
  rand bit [2:0]                          prot;

  // Write data channel fields (array for burst)
  rand bit [`LVC_AXI_MAX_DATA_WIDTH-1:0]  data[];
  rand bit [`LVC_AXI_MAX_STRB_WIDTH-1:0]  strb[];

  // Response fields
  lvc_axi_resp_type_e                     resp[];
  lvc_axi_resp_type_e                     bresp;  // For write response

  // Timing
  int unsigned start_time;
  int unsigned end_time;

  // Constraints
  constraint c_burst_length {
    burst_length inside {[0:255]};  // AXI4 supports up to 256 beats
  }

  constraint c_burst_type {
    burst_type inside {AXI_BURST_FIXED, AXI_BURST_INCR, AXI_BURST_WRAP};
  }

  constraint c_burst_size {
    burst_size inside {AXI_SIZE_1BYTE, AXI_SIZE_2BYTES, AXI_SIZE_4BYTES};
  }

  constraint c_addr_aligned {
    // Address must be aligned to burst size
    (burst_size == AXI_SIZE_1BYTE)  -> (addr[0:0] == 0);
    (burst_size == AXI_SIZE_2BYTES) -> (addr[0:0] == 0);
    (burst_size == AXI_SIZE_4BYTES) -> (addr[1:0] == 0);
    (burst_size == AXI_SIZE_8BYTES) -> (addr[2:0] == 0);
  }

  constraint c_wrap_burst_length {
    // Wrap burst length must be 2, 4, 8, or 16
    (burst_type == AXI_BURST_WRAP) -> (burst_length inside {1, 3, 7, 15});
  }

  constraint c_data_size {
    data.size() == burst_length + 1;
    strb.size() == burst_length + 1;
  }

  constraint c_strb_default {
    foreach(strb[i]) {
      strb[i] == '1;  // Default: all bytes enabled
    }
  }

  `uvm_object_utils_begin(lvc_axi_transaction)
    `uvm_field_enum(lvc_axi_trans_type_e, trans_type, UVM_ALL_ON)
    `uvm_field_int(id, UVM_ALL_ON)
    `uvm_field_int(addr, UVM_ALL_ON)
    `uvm_field_int(burst_length, UVM_ALL_ON)
    `uvm_field_enum(lvc_axi_size_e, burst_size, UVM_ALL_ON)
    `uvm_field_enum(lvc_axi_burst_type_e, burst_type, UVM_ALL_ON)
    `uvm_field_int(lock, UVM_ALL_ON)
    `uvm_field_int(cache, UVM_ALL_ON)
    `uvm_field_int(prot, UVM_ALL_ON)
    `uvm_field_array_int(data, UVM_ALL_ON)
    `uvm_field_array_int(strb, UVM_ALL_ON)
    `uvm_field_enum(lvc_axi_resp_type_e, bresp, UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "lvc_axi_transaction");
    super.new(name);
    data = new[1];
    strb = new[1];
    resp = new[1];
  endfunction

  // Calculate the number of bytes in a transfer
  function int get_bytes_per_beat();
    return (1 << burst_size);
  endfunction

  // Calculate total bytes in transaction
  function int get_total_bytes();
    return get_bytes_per_beat() * (burst_length + 1);
  endfunction

  // Calculate the next address in burst
  function bit [`LVC_AXI_MAX_ADDR_WIDTH-1:0] get_next_addr(int beat_num);
    bit [`LVC_AXI_MAX_ADDR_WIDTH-1:0] next_addr;
    int bytes_per_beat = get_bytes_per_beat();
    int wrap_boundary;
    
    case(burst_type)
      AXI_BURST_FIXED: begin
        next_addr = addr;
      end
      AXI_BURST_INCR: begin
        next_addr = addr + (beat_num * bytes_per_beat);
      end
      AXI_BURST_WRAP: begin
        wrap_boundary = bytes_per_beat * (burst_length + 1);
        next_addr = addr + (beat_num * bytes_per_beat);
        if ((next_addr - (addr & ~(wrap_boundary-1))) >= wrap_boundary)
          next_addr = next_addr - wrap_boundary;
      end
      default: next_addr = addr;
    endcase
    return next_addr;
  endfunction

  // Convert to string for debug
  function string convert2string();
    string s;
    s = $sformatf("AXI Transaction:\n");
    s = {s, $sformatf("  Type: %s\n", trans_type.name())};
    s = {s, $sformatf("  ID: 0x%0h\n", id)};
    s = {s, $sformatf("  Address: 0x%0h\n", addr)};
    s = {s, $sformatf("  Burst Length: %0d (beats: %0d)\n", burst_length, burst_length+1)};
    s = {s, $sformatf("  Burst Size: %s\n", burst_size.name())};
    s = {s, $sformatf("  Burst Type: %s\n", burst_type.name())};
    for(int i = 0; i <= burst_length && i < data.size(); i++) begin
      s = {s, $sformatf("  Data[%0d]: 0x%0h, Strb: 0x%0h\n", i, data[i], strb[i])};
    end
    return s;
  endfunction

endclass

`endif // LVC_AXI_TRANSACTION_SV
