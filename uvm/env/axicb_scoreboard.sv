`ifndef AXICB_SCOREBOARD_SV
`define AXICB_SCOREBOARD_SV

class axicb_scoreboard extends uvm_subscriber #(axi_transaction);

    `uvm_component_utils(axicb_scoreboard)
    
    //print in the report_phase 
    int unsigned check_count;   //total beats compared
    int unsigned error_count;   //total error beats

    //associative array: simulate DUT's expected behaviours
    //only be write-in data's address occupy memory
    bit [31:0] ref_mem[bit [15:0]];

    function new(string name = "axicb_scoreboard", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    //automatically callback while monitor finish every single transaction
    virtual function void write(axi_transaction t);
        case (t.trans_type)
            WRITE: process_write(t);
            READ:  process_read(t);
            default: `uvm_error(get_type_name(), "Unknown type!")
        endcase
    endfunction

    //extract wdata from write-transaction
    //merge wdata with wstrb and form a new data(expected data)
    //store expected data in ref_mem
    local function void process_write(axi_transaction tr);
        int beats;
        bit [15:0] addr;            //the raw start_address of first beat
        bit [15:0] word_addr;       //first beat's aligned address
        bit [31:0] old_word;
        beats = int'(tr.awlen) + 1;
        
        `uvm_info(get_type_name(), $sformatf(
            "write-action: base_addr=0x%04h len=%0d size=%0d type=%0s",
            tr.awaddr, tr.awlen, tr.awsize, tr.awburst.name()), UVM_MEDIUM)
        
        //calculate every beat's word_addr, store expected data into ref_mem word by word
        for(int i = 0; i < beats; i++) begin
            //get every beat's address
            addr = calculate_beat_addr(tr.awaddr, tr.awburst, tr.awsize, i);
            word_addr = {addr[15:2], 2'b00};
            //pull old_data from ref_mem
            old_word = ref_mem.exists(word_addr) ? ref_mem[word_addr] : 32'h0;
            //merge old_data with wstrb, got new_data and put it in to ref_mem
            ref_mem[word_addr] = merge_data_with_strb(old_word, tr.wdata[i], tr.wstrb[i]);

            `uvm_info(get_type_name(), $sformatf(
                "beat[%0d]: word_addr=0x%04h wdata=0x%08h wstrb=0x%04b -> ref_mem=0x%08h",
                i, word_addr, tr.wdata[i], tr.wstrb[i], ref_mem[word_addr]), UVM_MEDIUM)
        end
    endfunction

    //extract rdata from read-transaction
    //compare rdata with expected data in ref_mem
    local function void process_read(axi_transaction tr);
        int beats;
        bit [15:0] addr;
        bit [15:0] word_addr;
        bit [31:0] expected_data;
        beats = int'(tr.arlen) + 1;

        for(int i = 0; i < beats; i++) begin
            addr = calculate_beat_addr(tr.araddr, tr.arburst, tr.arsize, i);
            word_addr = {addr[15:2], 2'b00};
            expected_data = ref_mem.exists(word_addr) ? ref_mem[word_addr] : 32'h0;
            check_count++;
            //compare_data
            if(tr.rdata[i] !== expected_data) begin
                error_count++;
                `uvm_error(get_type_name(), $sformatf(
                    "READ data mismatch: beat[%0d] addr=0x%04h exp=0x%08h act=0x%08h",
                    i, addr, expected_data, tr.rdata[i] ))
            end else begin
                `uvm_info(get_type_name(), $sformatf(
                    "READ match: beat[%0d] addr=0x%04h data=0x%08h",
                    i, addr, tr.rdata[i]), UVM_HIGH)
            end
        end
    endfunction

    //calculate the beat's actual address
    local function bit [15:0] calculate_beat_addr(
        bit [15:0]      base_addr,
        burst_type_enum burst_type,
        burst_size_enum burst_size,
        int             beat_idx
    );  
        int unsigned    stride;
        bit [15:0]      aligned_start;
        bit [15:0]      beat_addr;

        stride        = 1 << int'(burst_size);      //byte number of every beat 
        aligned_start = (base_addr / stride) * stride;    //dynamically calculate first beat's aligned addr according to burst_szie

        if(burst_type == FIXED)  begin
            beat_addr = base_addr;
        end
        else begin  //INCR
            if(beat_idx == 0)
                beat_addr = base_addr;          //AXI protocol: under unaligned trans, INCR's first beat addr keep the unaligned address 
            else
                beat_addr = aligned_start + beat_idx * stride;   //calculate following beats' aligned address
        end
        return beat_addr;
    endfunction

    //according to wstrb, merge old_data and new_data
    local function bit [31:0] merge_data_with_strb(
        bit [31:0] old_data,
        bit [31:0] new_data,
        bit [3:0] wstrb
    );
        bit [31:0] new_word;
        new_word = old_data;

        //according to wstrb, merge old_data and new_data
        for(int lane = 0; lane < 4; lane++) begin
            if(wstrb[lane])
                new_word[lane*8 +: 8] = new_data[lane*8 +: 8];
        end 
        return new_word;
    endfunction

    //automatically print report info
    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        if(error_count == 0) begin
            `uvm_info(get_type_name(), $sformatf("Scoreboard PASS: check_count: %0d, 0 error", check_count), UVM_LOW)
        end else begin
            `uvm_error(get_type_name(),$sformatf("Scoreboard ERROR: check_count: %0d, error_count: %0d", check_count, error_count))
        end
    endfunction
endclass

`endif 