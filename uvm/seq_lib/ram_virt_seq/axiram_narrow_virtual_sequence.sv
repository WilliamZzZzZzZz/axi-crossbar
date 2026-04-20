`ifndef AXIRAM_NARROW_VIRTUAL_SEQUENCE_SV
`define AXIRAM_NARROW_VIRTUAL_SEQUENCE_SV

class axiram_narrow_virtual_sequence extends axiram_base_virtual_sequence;
    `uvm_object_utils(axiram_narrow_virtual_sequence)

    function new(string name = "axiram_narrow_virtual_sequence");
        super.new(name);
    endfunction

    virtual task body();
        super.body();
        sweep_narrow_incr();
    endtask

    // Systematically sweep all (burst_size, starting_offset, num_beats) combinations.
    // For a 32-bit bus, narrow sizes are 1BYTE and 2BYTES.
    //   1BYTE  : offsets 0,1,2,3  ×  beats 1..8  →  32 cases
    //   2BYTES : offsets 0,2      ×  beats 1..8  →  16 cases
    // Total: 48 test cases covering no-cross / single-cross / multi-cross boundary scenarios.
    virtual task sweep_narrow_incr();
        bit [15:0]      region_base   = 16'h7000;
        int             test_id       = 0;
        burst_size_enum narrow_sizes[] = '{BURST_SIZE_1BYTE, BURST_SIZE_2BYTES};

        foreach (narrow_sizes[s]) begin
            int stride = 1 << int'(narrow_sizes[s]);

            // all valid byte-lane offsets within a 4-byte word
            for (int offset = 0; offset < 4; offset += stride) begin
                // beat counts from 1 to 8
                for (int nbeats = 1; nbeats <= 8; nbeats++) begin
                    // each test owns a 0x20-byte address region to avoid overlap
                    bit [15:0] test_addr = region_base + test_id * 'h20 + offset;

                    `uvm_info(get_type_name(), $sformatf(
                        "Test #%0d: size=%s, offset=%0d, beats=%0d, addr=0x%04h",
                        test_id, narrow_sizes[s].name(), offset, nbeats, test_addr),
                        UVM_MEDIUM)

                    narrow_incr_test(test_addr, nbeats, narrow_sizes[s]);
                    test_id++;
                end
            end
        end

        `uvm_info(get_type_name(), $sformatf(
            "Sweep complete: %0d narrow INCR test cases executed", test_id), UVM_LOW)
    endtask

    virtual task narrow_incr_test(bit [15:0] base_addr, int num_beats, burst_size_enum burst_size);
        bit [31:0] init_data = 32'hFFFF_FFFF;
        bit [31:0] wdata_arr[];
        bit [3:0]  wstrb_arr[];
        int stride = 1 << int'(burst_size);  //byte width of 1 beat
        bit [15:0] first_word_addr;
        bit [15:0] last_word_addr;
        bit [15:0] last_beat_addr;
        bit [15:0] current_beat_addr;
        int lane;
        int num_words;
        
        wdata_arr = new[num_beats];
        wstrb_arr = new[num_beats];

        //no cross boundary: first_word_addr = last_word_addr
        //cross boundary:   first_word_addr != last_word_addr
        first_word_addr = {base_addr[15:2], 2'b00};
        last_beat_addr  = base_addr + (num_beats - 1) * stride;
        last_word_addr  = {last_beat_addr[15:2], 2'b00};
        num_words = (last_word_addr - first_word_addr)/4 + 1;

        //pre write-in initial data
        begin: PRE_WRITE
            bit [15:0] current_word_addr = first_word_addr;
            for(int i = 0; i < num_words; i++) begin
                do_aligned_write(current_word_addr, init_data);
                current_word_addr = current_word_addr + 4;
            end
        end

        //construct wdata and wstrb: place data on correct byte lane per beat
        for(int i = 0; i < num_beats; i++) begin
            current_beat_addr = base_addr + i * stride;     //every beat's address
            lane = current_beat_addr[1:0];
            wdata_arr[i] = 0;          //clear every lane, make sure only the choosen lane data write in
            case (burst_size)
                BURST_SIZE_1BYTE: begin
                    wdata_arr[i] = 32'(8'hA0 + i) << (lane * 8);
                    wstrb_arr[i] = 4'b0001 << lane;     //only enable the choosen lane
                end
                BURST_SIZE_2BYTES: begin
                    wdata_arr[i] = 32'(16'hBB00 + i) << (lane[1] * 16);
                    wstrb_arr[i] = lane[1] ? 4'b1100 : 4'b0011;
                end
                default: `uvm_fatal(get_type_name(), "unsupported narrow burst size")
            endcase
        end
        //write-in
        single_write = axiram_single_write_sequence::type_id::create("single_write");
        single_write.addr               = base_addr;
        single_write.data               = wdata_arr[0];
        single_write.every_beat_data    = wdata_arr;
        single_write.every_beat_wstrb   = wstrb_arr;
        single_write.burst_len          = burst_len_enum'(num_beats - 1);
        single_write.burst_size         = burst_size;
        single_write.burst_type         = INCR;
        single_write.start(p_sequencer);
        //read-back
        begin: READ_BACK
            bit [15:0] current_word_addr = first_word_addr;
            for(int i = 0; i < num_words; i++) begin
                single_read = axiram_single_read_sequence::type_id::create("single_read");
                single_read.addr        = current_word_addr;
                single_read.burst_len   = BURST_LEN_SINGLE;
                single_read.burst_size  = BURST_SIZE_4BYTES;
                single_read.burst_type  = INCR;
                single_read.start(p_sequencer);
                current_word_addr = current_word_addr + 4;
            end
        end
    endtask

    // Issue a single aligned write beat to seed initial data before a narrow test.
    local task do_aligned_write(bit [15:0] addr, bit [31:0] data);
        // every_beat_data requires a dynamic array, so wrap the scalar in a 1-entry array
        bit [31:0] init_data_arr[] = '{data};

        single_write = axiram_single_write_sequence::type_id::create("single_write");
        single_write.addr            = addr;
        single_write.data            = data;
        single_write.every_beat_data = init_data_arr;
        single_write.burst_len       = BURST_LEN_SINGLE;
        single_write.burst_size      = BURST_SIZE_4BYTES;
        single_write.burst_type      = INCR;
        single_write.start(p_sequencer);
    endtask
endclass

`endif 