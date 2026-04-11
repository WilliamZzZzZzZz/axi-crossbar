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
    
    //AW
    rand bit [M_ID_WIDTH - 1:0]     awid;      // write address id
    rand bit [ADDR_WIDTH - 1:0]     awaddr;    // write address
    rand burst_len_enum             awlen;     // burst length(0-255)
    rand burst_size_enum            awsize;    // burst size(00-1byte, 01-2bytes, 10-4bytes, 11-8bytes)
    rand burst_type_enum            awburst;   // burst type(00-FIXED, 01-INCR, 10-WRAP)
    rand lock_type_enum             awlock;    // lock type(0-normal access, 1-exclusive access)
    rand cache_type_enum            awcache;   // cache type
    rand prot_type_enum             awprot;    // protection type(bit[0]-privileged, bit[1]-secure, bit[2]-instruction)
    rand bit [QOS_WIDTH - 1:0]      awqos;
    rand bit [REGION_WIDTH - 1:0]   awregion;
    rand bit [WUSER_WIDTH - 1:0]    awuser;

    //W
    rand bit [DATA_WIDTH - 1:0]     wdata[];   // write data
    rand bit [STRB_WIDTH - 1:0]     wstrb[];   // write strobes(1 bit wstrb control 8bits wdata) 1-allow write in, 0-masked

    //B
    bit [M_ID_WIDTH - 1:0]          bid;       // response id(which data)
    bit [1:0]                       bresp;     // write response from slave(00-OKAY, 01-EXOKAY, 10-SLVERR, 11-DECERR)
    bit [BUSER_WIDTH - 1:0]         buser;

    //AR
    rand bit [M_ID_WIDTH - 1:0]     arid;      // read address id
    rand bit [ADDR_WIDTH - 1:0]     araddr;    // read address
    rand burst_len_enum             arlen;     // burst length(0-255)
    rand burst_size_enum            arsize;    // burst size
    rand burst_type_enum            arburst;   // burst type
    rand lock_type_enum             arlock;    // lock type
    rand cache_type_enum            arcache;   // cache type
    rand prot_type_enum             arprot;    // protection type
    rand bit [QOS_WIDTH - 1:0]      arqos;
    rand bit [REGION_WIDTH - 1:0]   arregion;
    rand bit [ARUSER_WIDTH -1:0]    aruser;

    //R
    bit [M_ID_WIDTH - 1:0]          rid;            // read id
    bit [DATA_WIDTH - 1:0]          rdata[];        // read data 
    bit [1:0]                       rresp[];        // read response
    bit                             rlast;
    bit [RUSER_WIDTH - 1:0]         ruser;
    
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
    
    `uvm_object_utils_begin(axi_transaction)
        `uvm_field_enum(trans_type_enum, trans_type, UVM_ALL_ON)
        `uvm_field_int(awid, UVM_ALL_ON)
        `uvm_field_int(awaddr, UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(awlen, UVM_ALL_ON)
        `uvm_field_int(awsize, UVM_ALL_ON)
        `uvm_field_int(awburst, UVM_ALL_ON)
        `uvm_field_int(awqos, UVM_ALL_ON)
        `uvm_field_int(awregion, UVM_ALL_ON)
        `uvm_field_int(awuser, UVM_ALL_ON)
        `uvm_field_array_int(wdata, UVM_ALL_ON | UVM_HEX)
        `uvm_field_array_int(wstrb, UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(arid, UVM_ALL_ON)
        `uvm_field_int(araddr, UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(arlen, UVM_ALL_ON)
        `uvm_field_int(arsize, UVM_ALL_ON)
        `uvm_field_int(arburst, UVM_ALL_ON)
        `uvm_field_int(arqos, UVM_ALL_ON)
        `uvm_field_int(arregion, UVM_ALL_ON)
        `uvm_field_int(aruser, UVM_ALL_ON)
        `uvm_field_int(rid, UVM_ALL_ON)
        `uvm_field_array_int(rdata, UVM_ALL_ON | UVM_HEX)
        `uvm_field_array_int(rresp, UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(ruser, UVM_ALL_ON)
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
    
endclass

`endif 
