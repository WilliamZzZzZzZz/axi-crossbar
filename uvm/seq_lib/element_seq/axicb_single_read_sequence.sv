`ifndef AXICB_SINGLE_READ_SEQUENCE_SV
`define AXICB_SINGLE_READ_SEQUENCE_SV

class axicb_single_read_sequence extends axiram_base_sequence;

    `uvm_object_utils(axicb_single_read_sequence)

    rand bit[31:0] addr;
    rand bit[31:0] data;
    rand burst_len_enum burst_len;
    rand burst_type_enum burst_type;
    rand burst_size_enum burst_size;

    bit [31:0] every_beat_data[];   //store every beat's data

    bit wait_for_response = 1;

    function new(string name = "axicb_single_read_sequence");
        super.new(name);
    endfunction

    virtual task body();
    axi_master_single_sequence axi_single;
    axi_master_sequencer       target_sqr;
    `uvm_info(get_type_name(), "entering...", UVM_LOW)

    axi_single = axi_master_single_sequence::type_id::create("axi_single");
    axi_single.trans_type  = READ;
    axi_single.addr        = addr;
    axi_single.burst_len   = burst_len;
    axi_single.burst_type  = burst_type;
    axi_single.burst_size  = burst_size;
    axi_single.wait_for_response = wait_for_response;

    target_sqr = p_sequencer.get_master_sqr(0);     //'0' means send tr to slave00 port
    axi_single.start(p_sequencer.axi_mst_sqr);

    if(wait_for_response) begin
        every_beat_data = axi_single.every_beat_data;
        data            = axi_single.data;
    end

    `uvm_info(get_type_name(), "exiting...", UVM_LOW)
    endtask
endclass

`endif 