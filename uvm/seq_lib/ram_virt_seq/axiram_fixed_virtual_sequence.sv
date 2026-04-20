`ifndef AXIRAM_FIXED_VIRTUAL_SEQUENCE_SV
`define AXIRAM_FIXED_VIRTUAL_SEQUENCE_SV

class axiram_fixed_virtual_sequence extends axiram_base_virtual_sequence;

    `uvm_object_utils(axiram_fixed_virtual_sequence)

    function new(string name = "axiram_fixed_virtual_sequence");
        super.new(name);
    endfunction

    virtual task body();
        bit [31:0] addr;
        bit [31:0] every_beat_data[];
        bit [31:0] expect_data[];
        bit [31:0] last_beat_data;

        burst_len_enum burst_len    = BURST_LEN_4BEATS;
        burst_type_enum burst_type  = FIXED;
        int actual_beats = burst_len + 1;

        super.body();

        for(int i = 0; i < 20; i++) begin
            std::randomize(addr) with {
                addr[1:0] == 2'b00; 
                addr inside {['h0000 : 'hFFFC]};
                addr[31:16] == 16'h0000;
                };

            every_beat_data = new[actual_beats];
            expect_data     = new[actual_beats];    

            for(int x = 0; x < actual_beats; x++) begin
                every_beat_data[x] = (i << 4) + i + x;  //i=5, beat0=0x55, beat1=0x56
            end

            last_beat_data = every_beat_data[actual_beats - 1];

            for(int x = 0; x < actual_beats; x++) begin
                expect_data[x] = last_beat_data;
            end

            //write-in
            single_write = axiram_single_write_sequence::type_id::create("single_write");
            single_write.addr = addr;
            single_write.data = every_beat_data[0];
            single_write.every_beat_data = every_beat_data;
            single_write.burst_len = burst_len;
            single_write.burst_type = burst_type;
            single_write.start(p_sequencer);

            //read-out
            single_read = axiram_single_read_sequence::type_id::create("single_read");
            single_read.addr = addr;
            single_read.burst_len = burst_len;
            single_read.burst_type = burst_type;
            single_read.start(p_sequencer);

            //compare
            wr_val = expect_data;
            rd_val = single_read.every_beat_data;
            compare_data(wr_val, rd_val);
            compare_single_data(last_beat_data, single_read.data);

        end
    endtask

endclass

`endif 