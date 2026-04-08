`ifndef AXIRAM_CROSSBAR_SMOKE_VIRTUAL_SEQUENCE_SV
`define AXIRAM_CROSSBAR_SMOKE_VIRTUAL_SEQUENCE_SV

class axiram_crossbar_smoke_virtual_sequence extends uvm_sequence;
    `uvm_object_utils(axiram_crossbar_smoke_virtual_sequence)
    `uvm_declare_p_sequencer(axiram_virtual_sequencer)

    function new(string name = "axiram_crossbar_smoke_virtual_sequence");
        super.new(name);
    endfunction

    virtual task body();
        `uvm_info(get_type_name(), "crossbar smoke start", UVM_LOW)

        // 4 basic routes
        do_write_read_check(0, 32'h0000_0040, 32'hA000_0001); // s00 -> m00
        do_write_read_check(0, 32'h0001_0040, 32'hA100_0001); // s00 -> m01
        do_write_read_check(1, 32'h0000_0080, 32'hB000_0001); // s01 -> m00
        do_write_read_check(1, 32'h0001_0080, 32'hB100_0001); // s01 -> m01

        // Concurrent accesses to the same target slave (m00)
        fork
            do_write_read_check(0, 32'h0000_0100, 32'h1111_AAAA);
            do_write_read_check(1, 32'h0000_0140, 32'h2222_BBBB);
        join

        `uvm_info(get_type_name(), "crossbar smoke done", UVM_LOW)
    endtask

    local task do_write_read_check(
        int unsigned mst_idx,
        bit [31:0] addr,
        bit [31:0] exp_data
    );
        axiram_single_write_sequence wr_seq;
        axiram_single_read_sequence  rd_seq;
        bit [31:0] data_arr[];

        data_arr = new[1];
        data_arr[0] = exp_data;

        wr_seq = axiram_single_write_sequence::type_id::create($sformatf("wr_m%0d_%08h", mst_idx, addr));
        wr_seq.master_idx        = mst_idx;
        wr_seq.addr              = addr;
        wr_seq.data              = exp_data;
        wr_seq.every_beat_data   = data_arr;
        wr_seq.burst_len         = BURST_LEN_SINGLE;
        wr_seq.burst_size        = BURST_SIZE_4BYTES;
        wr_seq.burst_type        = INCR;
        wr_seq.wait_for_response = 1;
        wr_seq.start(p_sequencer);

        rd_seq = axiram_single_read_sequence::type_id::create($sformatf("rd_m%0d_%08h", mst_idx, addr));
        rd_seq.master_idx        = mst_idx;
        rd_seq.addr              = addr;
        rd_seq.burst_len         = BURST_LEN_SINGLE;
        rd_seq.burst_size        = BURST_SIZE_4BYTES;
        rd_seq.burst_type        = INCR;
        rd_seq.wait_for_response = 1;
        rd_seq.start(p_sequencer);

        if (rd_seq.data !== exp_data) begin
            `uvm_error(get_type_name(), $sformatf(
                "Smoke mismatch: mst=%0d addr=0x%08h exp=0x%08h act=0x%08h",
                mst_idx, addr, exp_data, rd_seq.data))
        end
    endtask

endclass

`endif
