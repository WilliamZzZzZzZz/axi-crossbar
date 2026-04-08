`ifndef AXIRAM_SINGLE_WRITE_SEQUENCE_SV
`define AXIRAM_SINGLE_WRITE_SEQUENCE_SV

class axiram_single_write_sequence extends axiram_base_sequence;
    `uvm_object_utils(axiram_single_write_sequence)

    rand bit [31:0] addr;
    rand bit [31:0] data;
    rand burst_len_enum burst_len;
    rand burst_type_enum burst_type;
    rand burst_size_enum burst_size;

    int unsigned master_idx = 0;

    bit [31:0] every_beat_data[];
    bit [3:0]  every_beat_wstrb[];

    bit wait_for_response = 1;

    function new(string name = "axiram_single_write_sequence");
        super.new(name);
    endfunction

    virtual task body();
        axi_master_single_sequence axi_single;
        `uvm_info(get_type_name(), "entering...", UVM_LOW)

        if (master_idx >= 2 || p_sequencer.axi_mst_sqr[master_idx] == null) begin
            `uvm_fatal(get_type_name(), $sformatf("Invalid master_idx=%0d", master_idx))
        end

        axi_single = axi_master_single_sequence::type_id::create("axi_single");
        axi_single.trans_type        = WRITE;
        axi_single.addr              = addr;
        axi_single.data              = data;
        axi_single.burst_len         = burst_len;
        axi_single.burst_type        = burst_type;
        axi_single.burst_size        = burst_size;
        axi_single.every_beat_data   = every_beat_data;
        axi_single.every_beat_wstrb  = every_beat_wstrb;
        axi_single.wait_for_response = wait_for_response;

        axi_single.start(p_sequencer.axi_mst_sqr[master_idx]);

        `uvm_info(get_type_name(), "exiting...", UVM_LOW)
    endtask

endclass

`endif
