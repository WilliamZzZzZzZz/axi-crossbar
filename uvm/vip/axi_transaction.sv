`ifndef AXI_TRANSACTION_SV
`define AXI_TRANSACTION_SV

class axi_transaction extends uvm_sequence_item;

    // transaction type
    rand trans_type_enum trans_type;

    int current_wbeat_count;
    int current_rbeat_count;
    int wbeat_finish;
    int b_finish;
    int rbeat_finish;

    // Monitor source tags for scoreboard routing checks
    int monitor_port = -1;
    bit monitor_is_slave = 0;

    // Control whether driver returns response item to sequence.
    bit response_requested = 1;

    // Write address channel
    rand bit [31:0]             awid;
    rand bit [31:0]             awaddr;
    rand burst_len_enum         awlen;
    rand burst_size_enum        awsize;
    rand burst_type_enum        awburst;
    rand lock_type_enum         awlock;
    rand cache_type_enum        awcache;
    rand prot_type_enum         awprot;
    rand bit [3:0]              awqos;
    rand bit [31:0]             awuser;

    // Write data channel
    rand bit [31:0]             wdata[];
    rand bit [31:0]             wstrb[];
    rand bit [31:0]             wuser[];

    // Write response channel
    bit [31:0]                  bid;
    bit [1:0]                   bresp;
    bit [31:0]                  buser;

    // Read address channel
    rand bit [31:0]             arid;
    rand bit [31:0]             araddr;
    rand burst_len_enum         arlen;
    rand burst_size_enum        arsize;
    rand burst_type_enum        arburst;
    rand lock_type_enum         arlock;
    rand cache_type_enum        arcache;
    rand prot_type_enum         arprot;
    rand bit [3:0]              arqos;
    rand bit [31:0]             aruser;

    // Read data channel
    bit [31:0]                  rid;
    bit [31:0]                  rdata[];
    bit [1:0]                   rresp[];
    bit [31:0]                  ruser[];

    // AXI4 practical limits used by this environment
    constraint c_len {
        awlen inside {[0:15]};
        arlen inside {[0:15]};
    }

    constraint c_size {
        awsize <= 3'b010;
        arsize <= 3'b010;
    }

    constraint c_burst {
        awburst inside {2'b00, 2'b01, 2'b10};
        arburst inside {2'b00, 2'b01, 2'b10};
    }

    constraint c_data_size {
        if (trans_type == WRITE) {
            wdata.size() == awlen + 1;
            wstrb.size() == awlen + 1;
            wuser.size() == awlen + 1;
        } else {
            wdata.size() == 0;
            wstrb.size() == 0;
            wuser.size() == 0;
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
        `uvm_field_int(awuser, UVM_ALL_ON | UVM_HEX)

        `uvm_field_array_int(wdata, UVM_ALL_ON | UVM_HEX)
        `uvm_field_array_int(wstrb, UVM_ALL_ON | UVM_HEX)
        `uvm_field_array_int(wuser, UVM_ALL_ON | UVM_HEX)

        `uvm_field_int(bid, UVM_ALL_ON)
        `uvm_field_int(bresp, UVM_ALL_ON)
        `uvm_field_int(buser, UVM_ALL_ON | UVM_HEX)

        `uvm_field_int(arid, UVM_ALL_ON)
        `uvm_field_int(araddr, UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(arlen, UVM_ALL_ON)
        `uvm_field_int(arsize, UVM_ALL_ON)
        `uvm_field_int(arburst, UVM_ALL_ON)
        `uvm_field_int(arqos, UVM_ALL_ON)
        `uvm_field_int(aruser, UVM_ALL_ON | UVM_HEX)

        `uvm_field_int(rid, UVM_ALL_ON)
        `uvm_field_array_int(rdata, UVM_ALL_ON | UVM_HEX)
        `uvm_field_array_int(rresp, UVM_ALL_ON)
        `uvm_field_array_int(ruser, UVM_ALL_ON | UVM_HEX)

        `uvm_field_int(monitor_port, UVM_ALL_ON)
        `uvm_field_int(monitor_is_slave, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "axi_transaction");
        super.new(name);
    endfunction

    function void post_randomize();
        if (trans_type == READ) begin
            rdata = new[arlen + 1];
            rresp = new[arlen + 1];
            ruser = new[arlen + 1];
        end
    endfunction

endclass

`endif
