`ifndef AXIRAM_SCOREBOARD_SV
`define AXIRAM_SCOREBOARD_SV

class axiram_scoreboard extends uvm_subscriber #(axi_transaction);
    `uvm_component_utils(axiram_scoreboard)

    int unsigned check_count;
    int unsigned route_check_count;
    int unsigned error_count;

    bit [31:0] ref_mem[bit [31:0]];

    // Keep this consistent with TB wrapper parameters.
    localparam bit [31:0] M00_START = 32'h0000_0000;
    localparam bit [31:0] M00_END   = 32'h0000_FFFF;
    localparam bit [31:0] M01_START = 32'h0001_0000;
    localparam bit [31:0] M01_END   = 32'h0001_FFFF;

    function new(string name = "axiram_scoreboard", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void write(axi_transaction tr);
        if (tr.monitor_is_slave) begin
            process_route_check(tr);
            return;
        end

        case (tr.trans_type)
            WRITE: process_write(tr);
            READ:  process_read(tr);
            default: `uvm_error(get_type_name(), "Unknown transaction type")
        endcase
    endfunction

    local function void process_route_check(axi_transaction tr);
        bit [31:0] addr;
        int expected_port;

        addr = (tr.trans_type == WRITE) ? tr.awaddr : tr.araddr;
        expected_port = decode_port(addr);
        route_check_count++;

        if (expected_port < 0) begin
            error_count++;
            `uvm_error(get_type_name(), $sformatf(
                "Route check failed: addr=0x%08h does not match configured windows", addr))
            return;
        end

        if (tr.monitor_port != expected_port) begin
            error_count++;
            `uvm_error(get_type_name(), $sformatf(
                "Route mismatch: addr=0x%08h expected m%0d observed m%0d",
                addr, expected_port, tr.monitor_port))
        end
    endfunction

    local function void process_write(axi_transaction tr);
        int beats;
        bit [31:0] addr;
        bit [31:0] word_addr;
        bit [31:0] old_word;

        beats = int'(tr.awlen) + 1;

        for (int i = 0; i < beats; i++) begin
            addr = calculate_beat_addr(tr.awaddr, tr.awburst, tr.awsize, i);
            word_addr = {addr[31:2], 2'b00};
            old_word = ref_mem.exists(word_addr) ? ref_mem[word_addr] : 32'h0;
            ref_mem[word_addr] = merge_data_with_strb(old_word, tr.wdata[i], tr.wstrb[i]);
        end
    endfunction

    local function void process_read(axi_transaction tr);
        int beats;
        bit [31:0] addr;
        bit [31:0] word_addr;
        bit [31:0] expected_data;

        beats = int'(tr.arlen) + 1;

        for (int i = 0; i < beats; i++) begin
            addr = calculate_beat_addr(tr.araddr, tr.arburst, tr.arsize, i);
            word_addr = {addr[31:2], 2'b00};
            expected_data = ref_mem.exists(word_addr) ? ref_mem[word_addr] : 32'h0;
            check_count++;

            if (tr.rdata[i] !== expected_data) begin
                error_count++;
                `uvm_error(get_type_name(), $sformatf(
                    "READ mismatch: beat=%0d addr=0x%08h exp=0x%08h act=0x%08h",
                    i, addr, expected_data, tr.rdata[i]))
            end
        end
    endfunction

    local function int decode_port(bit [31:0] addr);
        if (addr >= M00_START && addr <= M00_END)
            return 0;
        if (addr >= M01_START && addr <= M01_END)
            return 1;
        return -1;
    endfunction

    local function bit [31:0] calculate_beat_addr(
        bit [31:0]      base_addr,
        burst_type_enum burst_type,
        burst_size_enum burst_size,
        int             beat_idx
    );
        int unsigned stride;
        bit [31:0] aligned_start;
        bit [31:0] beat_addr;

        stride        = 1 << int'(burst_size);
        aligned_start = (base_addr >> int'(burst_size)) << int'(burst_size);

        if (burst_type == FIXED) begin
            beat_addr = base_addr;
        end else begin
            if (beat_idx == 0)
                beat_addr = base_addr;
            else
                beat_addr = aligned_start + beat_idx * stride;
        end

        return beat_addr;
    endfunction

    local function bit [31:0] merge_data_with_strb(
        bit [31:0] old_data,
        bit [31:0] new_data,
        bit [31:0] wstrb
    );
        bit [31:0] new_word;
        new_word = old_data;

        for (int lane = 0; lane < 4; lane++) begin
            if (wstrb[lane])
                new_word[lane*8 +: 8] = new_data[lane*8 +: 8];
        end
        return new_word;
    endfunction

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);

        if (error_count == 0) begin
            `uvm_info(get_type_name(), $sformatf(
                "Scoreboard PASS: data_checks=%0d route_checks=%0d",
                check_count, route_check_count), UVM_LOW)
        end else begin
            `uvm_error(get_type_name(), $sformatf(
                "Scoreboard FAIL: data_checks=%0d route_checks=%0d errors=%0d",
                check_count, route_check_count, error_count))
        end
    endfunction

endclass

`endif
