`ifndef AXIRAM_SMOKE_VIRTUAL_SEQUENCE_SV
`define AXIRAM_SMOKE_VIRTUAL_SEQUENCE_SV

class axiram_smoke_virtual_sequence extends axiram_base_virtual_sequence;

    `uvm_object_utils(axiram_smoke_virtual_sequence)

    function new(string name = "axiram_smoke_virtual_sequence");
        super.new(name);
    endfunction

    virtual task body();
        bit [31:0] addr;
        bit [31:0] every_beat_data[]; 
        burst_len_enum burst_len    = BURST_LEN_8BEATS;
        burst_type_enum burst_type  = INCR;
        int actual_beats = burst_len + 1;

        super.body();
        `uvm_info(get_type_name(), "entering...", UVM_LOW)

        for(int i = 0; i < 10; i++) begin
            std::randomize(addr) with {addr[1:0] == 0; addr inside {['h1000:'h1FFF]};}; //data = 0x00 0x11 0x22 0x33 0x44 0x55...
            
            every_beat_data = new[actual_beats];
            for(int x = 0; x < actual_beats; x++) begin
                every_beat_data[x] = (i << 4) + i + x;  //i=5, beat0=0x55, beat1=0x56
            end

            //write-in
            single_write = axiram_single_write_sequence::type_id::create("single_write");
            single_write.addr               = addr;
            single_write.data               = every_beat_data[0]; //single beat
            single_write.every_beat_data    = every_beat_data; //mutiple beats
            single_write.burst_len          = burst_len;
            single_write.burst_type         = burst_type;
            single_write.start(p_sequencer);

            //read-out
            single_read = axiram_single_read_sequence::type_id::create("single_read");
            single_read.addr        = addr;
            single_read.burst_len   = burst_len;
            single_read.burst_type  = burst_type;
            single_read.start(p_sequencer);

            //compare
            wr_val = every_beat_data;
            rd_val = single_read.every_beat_data;
            compare_data(wr_val, rd_val);

        end
        `uvm_info(get_type_name(), "entering...", UVM_LOW)
    endtask

endclass

`endif 