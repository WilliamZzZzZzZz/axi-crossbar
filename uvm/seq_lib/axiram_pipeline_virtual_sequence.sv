`ifndef AXIRAM_PIPELINE_VIRTUAL_SEQUENCE_SV
`define AXIRAM_PIPELINE_VIRTUAL_SEQUENCE_SV

class axiram_pipeline_virtual_sequence extends axiram_base_virtual_sequence;
    `uvm_object_utils(axiram_pipeline_virtual_sequence)

    function new(string name = "axiram_pipeline_virtual_sequence");
        super.new(name);
    endfunction

    virtual task body();
        super.body();
        `uvm_info(get_type_name(), "--- pipeline_sequence_test-START---", UVM_LOW)
        pipeline_write_burst(10);
        wait_cycles(200);
        pipeline_read_burst(10);
        wait_cycles(200);
        verify_after_pipeline();
        `uvm_info(get_type_name(), "--- pipeline_sequence_test-END---", UVM_LOW)

    endtask

    virtual task pipeline_write_burst(int num_trans);
        burst_len_enum burst_len    = BURST_LEN_4BEATS;
        burst_type_enum burst_type  = INCR;
        int actual_beats = burst_len + 1;

        `uvm_info(get_type_name(), $sformatf("WRITE: sending %0d back-to-back trans", num_trans),UVM_LOW)
        //back to back send 'num_trans' times transaction 
        for(int i = 0; i < num_trans; i++) begin
            bit [31:0] every_beat_data[];
            every_beat_data = new[actual_beats];

            single_write = axiram_single_write_sequence::type_id::create("single_write");
            single_write.addr       = 16'h3000 + i * (actual_beats * 4);
            single_write.burst_len  = burst_len;
            single_write.burst_size = BURST_SIZE_4BYTES;
            single_write.burst_type = burst_type;

            foreach(every_beat_data[x]) every_beat_data[x] = (i << 8) | x;
            single_write.data               = every_beat_data[0];
            single_write.every_beat_data    = every_beat_data;
            single_write.wait_for_response  = 0;    //non-blocking
            single_write.start(p_sequencer);
        end
    endtask

    virtual task pipeline_read_burst(int num_trans);
        burst_len_enum burst_len = BURST_LEN_4BEATS;
        burst_type_enum burst_type = INCR;
        int actual_beats = burst_len + 1;

        `uvm_info(get_type_name(), $sformatf("READ: sending %0d back-to-back trans", num_trans),UVM_LOW)
        for(int i = 0; i < num_trans; i ++) begin
            single_read = axiram_single_read_sequence::type_id::create("single_read");
            single_read.addr                = 16'h3000 + i * (actual_beats * 4);
            single_read.burst_len           = burst_len;
            single_read.burst_size          = BURST_SIZE_4BYTES;
            single_read.burst_type          = burst_type;
            single_read.wait_for_response   = 0;
            single_read.start(p_sequencer);
        end
    endtask

    virtual task verify_after_pipeline();
        bit [31:0] every_beat_data[] = '{32'hAAAA_0001, 32'hBBBB_0002,
                                         32'hCCCC_0003, 32'hDDDD_0004};
        `uvm_info(get_type_name(), "verfiy dut's performance after pipeline", UVM_LOW)
        //write blocking-mode(default)
        single_write = axiram_single_write_sequence::type_id::create("single_write");
        single_write.addr               = 16'h5000;
        single_write.data               = every_beat_data[0];
        single_write.every_beat_data    = every_beat_data;
        single_write.burst_len          = BURST_LEN_4BEATS;
        single_write.burst_size         = BURST_SIZE_4BYTES;
        single_write.burst_type         = INCR;
        single_write.start(p_sequencer);
        //read blocking-mode(default)
        single_read = axiram_single_read_sequence::type_id::create("single_read");
        single_read.addr                = 16'h5000;
        single_read.burst_len           = BURST_LEN_4BEATS;
        single_read.burst_size          = BURST_SIZE_4BYTES;
        single_read.burst_type          = INCR;
        single_read.start(p_sequencer);

        wr_val = every_beat_data;
        rd_val = single_read.every_beat_data;
        compare_data(wr_val, rd_val);
    endtask

endclass

`endif 