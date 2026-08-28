`ifndef AXI_CHANNEL_EVENT_SV
`define AXI_CHANNEL_EVENT_SV

typedef enum bit [2:0] {
    AXI_EVT_AW,
    AXI_EVT_W,
    AXI_EVT_B,
    AXI_EVT_AR,
    AXI_EVT_R,
    AXI_EVT_RESET
} axi_channel_event_kind;

// One accepted AXI channel transfer.  The predictor uses these events instead
// of sequence items so that only transfers observed on the DUT pins are modeled.
class axi_channel_event extends uvm_sequence_item;
    axi_channel_event_kind kind;
    bit                    is_downstream;
    int unsigned           port_idx;
    bit [M_ID_WIDTH-1:0]   id;
    bit [ADDR_WIDTH-1:0]   addr;
    bit [7:0]              len;
    bit [2:0]              size;
    bit [1:0]              burst;
    bit                    lock;
    bit [3:0]              cache;
    bit [2:0]              prot;
    bit [QOS_WIDTH-1:0]    qos;
    bit [REGION_WIDTH-1:0] region;
    bit                    user;
    bit [DATA_WIDTH-1:0]   data;
    bit [STRB_WIDTH-1:0]   strb;
    bit [1:0]              resp;
    bit                    last;
    longint unsigned       txn_key;
    int unsigned           epoch;

    `uvm_object_utils_begin(axi_channel_event)
        `uvm_field_enum(axi_channel_event_kind, kind, UVM_ALL_ON)
        `uvm_field_int(is_downstream, UVM_ALL_ON)
        `uvm_field_int(port_idx, UVM_ALL_ON)
        `uvm_field_int(id, UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(addr, UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(len, UVM_ALL_ON)
        `uvm_field_int(size, UVM_ALL_ON)
        `uvm_field_int(burst, UVM_ALL_ON)
        `uvm_field_int(lock, UVM_ALL_ON)
        `uvm_field_int(cache, UVM_ALL_ON)
        `uvm_field_int(prot, UVM_ALL_ON)
        `uvm_field_int(qos, UVM_ALL_ON)
        `uvm_field_int(region, UVM_ALL_ON)
        `uvm_field_int(user, UVM_ALL_ON)
        `uvm_field_int(data, UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(strb, UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(resp, UVM_ALL_ON)
        `uvm_field_int(last, UVM_ALL_ON)
        `uvm_field_int(txn_key, UVM_ALL_ON)
        `uvm_field_int(epoch, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "axi_channel_event");
        super.new(name);
    endfunction
endclass

`endif
