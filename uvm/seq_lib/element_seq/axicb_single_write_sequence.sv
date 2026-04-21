`ifndef AXICB_SINGLE_WRITE_SEQUENCE_SV
`define AXICB_SINGLE_WRITE_SEQUENCE_SV

class axicb_single_write_sequence extends axicb_base_sequence;

    `uvm_object_utils(axicb_single_write_sequence)

    rand bit [31:0] addr;
    rand bit [31:0] data;
    rand burst_len_enum burst_len;
    rand burst_type_enum burst_type;
    rand burst_size_enum burst_size;

    bit [31:0] every_beat_data[];   //store every beat's data    
    bit [3:0] every_beat_wstrb[];

    bit wait_for_response = 1;
    bit expect_decerr = 0;
    bit [1:0] bresp;
    bit [ID_WIDTH - 1:0] awid;
    bit [ID_WIDTH - 1:0] bid;

    function new(string name = "axicb_single_write_sequence");
        super.new(name);
    endfunction

    virtual task body();
        axi_master_single_sequence axi_single;
        axi_master_sequencer       target_sqr;
        super.body();
        `uvm_info(get_type_name(), "entering...", UVM_LOW)

        axi_single = axi_master_single_sequence::type_id::create("axi_single");
        axi_single.trans_type        = WRITE;
        axi_single.addr              = addr;
        axi_single.data              = data;
        axi_single.burst_len         = burst_len;
        axi_single.burst_type        = burst_type;
        axi_single.burst_size        = burst_size; 
        axi_single.every_beat_data   = every_beat_data;       
        axi_single.every_beat_wstrb  = every_beat_wstrb;
        axi_single.tr_id             = awid;
        axi_single.wait_for_response = wait_for_response;
        axi_single.expect_decerr     = expect_decerr;
        

        target_sqr = p_sequencer.get_master_sqr(src_master_idx);     //'0' means send tr to slave00 port
        axi_single.start(target_sqr);
        bresp = axi_single.write_bresp;
        bid   = axi_single.write_bid;

        `uvm_info(get_type_name(), "exiting...", UVM_LOW)
    endtask
endclass

`endif 