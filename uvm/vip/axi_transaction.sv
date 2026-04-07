`ifndef AXI_TRANSACTION_SV
`define AXI_TRANSACTION_SV

class axi_transaction extends uvm_sequence_item;
    

    //--------------------------------------------------------------------------
    // transaction type: WRITE or READ
    //--------------------------------------------------------------------------
    rand trans_type_enum trans_type;

    int current_wbeat_count;
    int current_rbeat_count;
    int wbeat_finish;
    int b_finish;
    int rbeat_finish;

    //pipeline-mode, driver checks this flag before sending response back
    bit response_requested = 1;
    
    //--------------------------------------------------------------------------
    // Write address channel
    //--------------------------------------------------------------------------
    rand bit [31:0]             awid;      // write address id
    rand bit [15:0]             awaddr;    // write address
    rand burst_len_enum         awlen;     // burst length(0-255)
    rand burst_size_enum        awsize;    // burst size(00-1byte, 01-2bytes, 10-4bytes, 11-8bytes)
    rand burst_type_enum        awburst;   // burst type(00-FIXED, 01-INCR, 10-WRAP)
    rand lock_type_enum         awlock;    // lock type(0-normal access, 1-exclusive access)
    rand cache_type_enum        awcache;   // cache type
    rand prot_type_enum         awprot;    // protection type(bit[0]-privileged, bit[1]-secure, bit[2]-instruction)
    
    //--------------------------------------------------------------------------
    // Write data channel
    //--------------------------------------------------------------------------
    rand bit [31:0]             wdata[];   // write data
    rand bit [15:0]             wstrb[];   // write strobes(1 bit wstrb control 8bits wdata) 1-allow write in, 0-masked
    
    //--------------------------------------------------------------------------
    // write response channel
    //--------------------------------------------------------------------------
    bit [7:0]                   bid;       // response id(which data)
    bit [1:0]                   bresp;     // write response from slave(00-OKAY, 01-EXOKAY, 10-SLVERR, 11-DECERR)
    
    //--------------------------------------------------------------------------
    // read address channel
    //--------------------------------------------------------------------------
    rand bit [7:0]              arid;      // read address id
    rand bit [15:0]             araddr;    // read address
    rand burst_len_enum         arlen;     // burst length(0-255)
    rand burst_size_enum        arsize;    // burst size
    rand burst_type_enum        arburst;   // burst type
    rand lock_type_enum         arlock;    // lock type
    rand cache_type_enum        arcache;   // cache type
    rand prot_type_enum         arprot;    // protection type
    
    //--------------------------------------------------------------------------
    // read data channel
    //--------------------------------------------------------------------------
    bit [7:0]                   rid;            // read id
    bit [31:0]                  rdata[];        // read data 
    bit [1:0]                   rresp[];        // read response
    
    // //--------------------------------------------------------------------------
    // // 时序控制
    // //--------------------------------------------------------------------------
    // rand int awvalid_delay;    // awvalid 延迟周期
    // rand int wvalid_delay;     // wvalid 延迟周期
    // rand int bready_delay;     // bready 延迟周期
    // rand int arvalid_delay;    // arvalid 延迟周期
    // rand int rready_delay;     // rready 延迟周期
    
    //--------------------------------------------------------------------------
    // constraint
    //--------------------------------------------------------------------------
    
    // AXI4 maximum allow awlen = 256 burst, but most pratically only use for short burst
    constraint c_len {
        awlen inside {[0:15]};  // 1-16 beats
        arlen inside {[0:15]};
    }
    
    // maximum burst size is 8 bytes, but DUT's DATA_WIDTH = 32bits,  which means maximum size is 4 bytes
    constraint c_size {
        awsize <= 3'b010;  // less than 4 bytes (32-bit)
        arsize <= 3'b010;
    }
    
    // AXI4 only 3 types of transfer: FIXED, INCR, WRAP
    constraint c_burst {
        awburst inside {2'b00, 2'b01, 2'b10};  // FIXED, INCR, WRAP
        arburst inside {2'b00, 2'b01, 2'b10};
    }
    
    // 4 bytes align
    // constraint c_align {
    //     awaddr[1:0] == 2'b00;  
    //     araddr[1:0] == 2'b00;
    // }
    
    // AXI4 protocol: actual burst size = awlen + 1
    constraint c_data_size {
        if(trans_type == WRITE) {
            wdata.size() == awlen + 1;
            wstrb.size() == awlen + 1;
        } else {
            wdata.size() == 0;
            wstrb.size() == 0;
        }
    }
    
    // // 延迟约束
    // constraint c_delay {
    //     awvalid_delay inside {[0:5]};
    //     wvalid_delay inside {[0:5]};
    //     bready_delay inside {[0:5]};
    //     arvalid_delay inside {[0:5]};
    //     rready_delay inside {[0:5]};
    // }
    
    // wstrb = 4'h1111 -> default all btyes allow to write in 
    // constraint c_wstrb {
    //     foreach(wstrb[i]) {
    //         wstrb[i] == 4'hF;
    //     }
    // }
    
    `uvm_object_utils_begin(axi_transaction)
        `uvm_field_enum(trans_type_enum, trans_type, UVM_ALL_ON)
        `uvm_field_int(awid, UVM_ALL_ON)
        `uvm_field_int(awaddr, UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(awlen, UVM_ALL_ON)
        `uvm_field_int(awsize, UVM_ALL_ON)
        `uvm_field_int(awburst, UVM_ALL_ON)
        `uvm_field_array_int(wdata, UVM_ALL_ON | UVM_HEX)
        `uvm_field_array_int(wstrb, UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(arid, UVM_ALL_ON)
        `uvm_field_int(araddr, UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(arlen, UVM_ALL_ON)
        `uvm_field_int(arsize, UVM_ALL_ON)
        `uvm_field_int(arburst, UVM_ALL_ON)
        `uvm_field_array_int(rdata, UVM_ALL_ON | UVM_HEX)
    `uvm_object_utils_end
    
    function new(string name = "axi_transaction");
        super.new(name);
    endfunction
    
    //--------------------------------------------------------------------------
    // post-randomize
    //--------------------------------------------------------------------------
    function void post_randomize();
        if(trans_type == READ) begin
            rdata = new[arlen + 1];
            rresp = new[arlen + 1];
        end
    endfunction
    // function void post_randomize();
    //     int beat_num;
    //     if(trans_type == WRITE) begin
    //         beat_num = int'(awlen) + 1;
    //         wdata = new[beat_num];
    //         wstrb = new[beat_num];
    //     end else begin
    //         beat_num = int'(arlen) + 1;
    //         rdata = new[beat_num];
    //         rresp = new[beat_num];
    //     end
    // endfunction
    
endclass

`endif 
