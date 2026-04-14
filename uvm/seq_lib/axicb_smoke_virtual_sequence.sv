`ifndef AXICB_SMOKE_VIRTUAL_SEQUENCE_SV
`define AXICB_SMOKE_VIRTUAL_SEQUENCE_SV

class axicb_smoke_virtual_sequence extends axicb_base_virtual_sequence;

    `uvm_object_utils(axicb_smoke_virtual_sequence)

    function new(string name = "axicb_smoke_virtual_sequence");
        super.new(name);
    endfunction

    virtual task body();
        bit [31:0] addr;
        bit [31:0] wr_data;
        bit [31:0] wr_data_arr[];
        bit [3:0]  wr_strb_arr[];

        super.body();
        `uvm_info(get_type_name(), "=======smoke test start=======", UVM_LOW)
        
        if(vif_mst00.arst === 1'b1) @(negedge vif_mst00.arst);
        wait_cycles(5);

        addr            = 32'h0000_0040;
        wr_data         = 32'hA7A7_A7A7;
        wr_data_arr     = new[1];
        wr_strb_arr     = new[1];
        wr_data_arr[0]  = wr_data;
        wr_strb_arr[0]  = 4'hF;

        single_write = axicb_single_write_sequence::type_id::create("single_write");
        single_write.addr               = addr;
        single_write.data               = wr_data;
        single_write.burst_len          = BURST_LEN_SINGLE;
        single_write.burst_type         = INCR;
        single_write.burst_size         = BURST_SIZE_4BYTES;
        single_write.every_beat_data    = wr_data_arr;
        single_write.every_beat_wstrb   = wr_strb_arr;
        single_write.wait_for_response  = 1;
        single_write.start(p_sequencer);

        single_read = axicb_single_read_sequence::type_id::create("single_read");
        single_read.addr                = addr;
        single_read.burst_len           = BURST_LEN_SINGLE;
        single_read.burst_type          = INCR;
        single_read.burst_size          = BURST_SIZE_4BYTES;
        single_read.wait_for_response   = 1;
        single_read.start(p_sequencer);

        compare_single_data(wr_data, single_read.data);

        `uvm_info(get_type_name(), "=======smoke test end=======", UVM_LOW)
    endtask

endclass

`endif 