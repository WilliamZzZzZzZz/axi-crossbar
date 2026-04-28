`ifndef AXICB_SCOREBOARD_SV
`define AXICB_SCOREBOARD_SV

class axicb_scoreboard extends uvm_subscriber #(axi_transaction);

    `uvm_component_utils(axicb_scoreboard)
    
    //print in the report_phase 
    int unsigned check_count;   //total beats compared
    int unsigned error_count;   //total error beats
    int unsigned decerr_count;

    //associative array: simulate DUT's expected behaviours
    //only be write-in data's address occupy memory
    bit [DATA_WIDTH - 1:0] ref_mem[bit [ADDR_WIDTH - 1:0]];

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
        bit [ADDR_WIDTH - 1:0] addr;            //the raw start_address of first beat
        bit [ADDR_WIDTH - 1:0] word_addr;       //first beat's aligned address
        bit [DATA_WIDTH - 1:0] old_word;
        beats = int'(tr.awlen) + 1;
        
        //check DECERR and bresp
        if(is_decerr_expected(tr.awaddr)) begin
            decerr_count++;
            if(tr.bresp !== DECERR) begin
                `uvm_error(get_type_name(), $sformatf("DECERR expected but bresp: %0b, ADDR: %08h", tr.bresp, tr.awaddr))
            end else begin
                `uvm_info(get_type_name(), $sformatf("WRITE DECERR check PASS: ADDR: %08h", tr.awaddr), UVM_LOW)
            end
            return;     //jump out of entire 'process_write()', in case illegal addr and data into ref_mem       
        end else begin  //usual bresp check
            if(tr.bresp !== OKAY)
                `uvm_error(get_type_name(), $sformatf("write option got a non-OKAY response! bresp: %0b, ADDR: %08h ", tr.bresp, tr.awaddr))
        end

        `uvm_info(get_type_name(), $sformatf(
            "write-action: base_addr=0x%04h len=%0d size=%0d type=%0s",
            tr.awaddr, tr.awlen, tr.awsize, tr.awburst.name()), UVM_MEDIUM)
        
        //calculate every beat's word_addr, store expected data into ref_mem word by word
        for(int i = 0; i < beats; i++) begin
            //get every beat's address
            addr = calculate_beat_addr(tr.awaddr, tr.awlen, tr.awburst, tr.awsize, i);
            word_addr = {addr[ADDR_WIDTH - 1:2], 2'b00};
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
        bit [ADDR_WIDTH - 1:0] addr;
        bit [ADDR_WIDTH - 1:0] word_addr;
        bit [DATA_WIDTH - 1:0] expected_data;
        beats = int'(tr.arlen) + 1;

        //check DECERR and rresp
        if(is_decerr_expected(tr.araddr)) begin
            decerr_count++;
            foreach(tr.rresp[i]) begin
                if(tr.rresp[i] !== DECERR)
                    `uvm_error(get_type_name(), $sformatf("DECERR expected but rresp[%0d]: %0b, ADDR: %08h", i, tr.rresp[i], tr.araddr))
                else
                    `uvm_info(get_type_name(), $sformatf("read DECERR check PASS: ADDR: %08h, beat_idx: %0d", tr.araddr, i), UVM_LOW)
            end
            return;
        end else begin  //usual rresp check
            foreach(tr.rresp[i]) begin
                if(tr.rresp[i] !== OKAY)
                    `uvm_error(get_type_name(), $sformatf("read option got a non-OKAY response! rresp[%0d]: %0b, ADDR: %08h", i, tr.rresp[i], tr.araddr))
            end
        end

        for(int i = 0; i < beats; i++) begin
            addr = calculate_beat_addr(tr.araddr, tr.arlen, tr.arburst, tr.arsize, i);
            word_addr = {addr[ADDR_WIDTH - 1:2], 2'b00};
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
    local function bit [ADDR_WIDTH - 1:0] calculate_beat_addr(
        bit [ADDR_WIDTH - 1:0] base_addr,
        burst_len_enum         burst_len,
        burst_type_enum        burst_type,
        burst_size_enum        burst_size,
        int                    beat_idx
    );  
        int unsigned            stride;
        int unsigned            total_bytes;
        bit [ADDR_WIDTH - 1:0]  aligned_start;
        bit [ADDR_WIDTH - 1:0]  beat_addr;
        bit [ADDR_WIDTH - 1:0]  wrap_low;
        bit [ADDR_WIDTH - 1:0]  wrap_high;

        stride        = 1 << int'(burst_size);      //byte number of every beat 
        aligned_start = (base_addr / stride) * stride;    //dynamically calculate first beat's aligned addr according to burst_szie

        case(burst_type)
            FIXED: beat_addr = base_addr;
            INCR: begin
                if(beat_idx == 0)
                    beat_addr = base_addr;
                else
                    beat_addr = aligned_start + beat_idx * stride;
            end
            WRAP: begin
                total_bytes = (int'(burst_len) + 1) * stride;
                wrap_low    = (base_addr / total_bytes) * total_bytes;
                wrap_high   = wrap_low + total_bytes;
                beat_addr   = base_addr + (beat_idx * stride);
                if (beat_addr >= wrap_high)
                    beat_addr = beat_addr - total_bytes;
            end
        endcase

        return beat_addr;
    endfunction

    //according to wstrb, merge old_data and new_data
    local function bit [31:0] merge_data_with_strb(
        bit [DATA_WIDTH - 1:0] old_data,
        bit [DATA_WIDTH - 1:0] new_data,
        bit [STRB_WIDTH - 1:0] wstrb
    );
        bit [DATA_WIDTH - 1:0] new_word;
        new_word = old_data;

        //according to wstrb, merge old_data and new_data
        for(int lane = 0; lane < 4; lane++) begin
            if(wstrb[lane])
                new_word[lane*8 +: 8] = new_data[lane*8 +: 8];
        end 
        return new_word;
    endfunction

    //check decerr whether is expected
    local function bit is_decerr_expected(bit [ADDR_WIDTH - 1:0] addr);
        if(addr >= 32'h0000_0000 && addr <= 32'h0000_FFFF) return 0;
        if(addr >= 32'h0001_0000 && addr <= 32'h0001_FFFF) return 0;
        return 1;
    endfunction

    //automatically print report info
    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        if(error_count == 0) begin
            `uvm_info(get_type_name(), $sformatf("Scoreboard PASS: check_count: %0d, decerr_count: %0d, error: 0", check_count, decerr_count), UVM_LOW)
        end else begin
            `uvm_error(get_type_name(),$sformatf("Scoreboard ERROR: check_count: %0d, , error_count: %0d", check_count, error_count))
        end
    endfunction
endclass

`endif 