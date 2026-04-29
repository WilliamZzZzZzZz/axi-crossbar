`ifndef AXICB_SCOREBOARD_SV
`define AXICB_SCOREBOARD_SV

`uvm_analysis_imp_decl(_scb_mst00)
`uvm_analysis_imp_decl(_scb_mst01)
`uvm_analysis_imp_decl(_scb_slv00)
`uvm_analysis_imp_decl(_scb_slv01)

class axicb_scoreboard extends uvm_component;

    `uvm_component_utils(axicb_scoreboard)

    typedef struct {
        trans_type_enum      trans_type;
        int unsigned         mst_idx;
        bit [ID_WIDTH-1:0]   id;
        bit [ADDR_WIDTH-1:0] addr;
        burst_len_enum       len;
        burst_size_enum      size;
        burst_type_enum      burst;
    } expected_downstream_txn_t;

    uvm_analysis_imp_scb_mst00 #(axi_transaction, axicb_scoreboard) mst00_export;
    uvm_analysis_imp_scb_mst01 #(axi_transaction, axicb_scoreboard) mst01_export;
    uvm_analysis_imp_scb_slv00 #(axi_transaction, axicb_scoreboard) slv00_export;
    uvm_analysis_imp_scb_slv01 #(axi_transaction, axicb_scoreboard) slv01_export;

    int unsigned check_count;
    int unsigned error_count;
    int unsigned decerr_count;

    bit [DATA_WIDTH-1:0] ref_mem[bit [ADDR_WIDTH-1:0]];

    expected_downstream_txn_t exp_slv00_q[$];
    expected_downstream_txn_t exp_slv01_q[$];
    axi_transaction           act_slv00_q[$];
    axi_transaction           act_slv01_q[$];

    function new(string name = "axicb_scoreboard", uvm_component parent = null);
        super.new(name, parent);
        mst00_export = new("mst00_export", this);
        mst01_export = new("mst01_export", this);
        slv00_export = new("slv00_export", this);
        slv01_export = new("slv01_export", this);
    endfunction

    virtual function void write_scb_mst00(axi_transaction t);
        process_upstream(t, 0);
    endfunction

    virtual function void write_scb_mst01(axi_transaction t);
        process_upstream(t, 1);
    endfunction

    virtual function void write_scb_slv00(axi_transaction t);
        process_downstream(t, 0);
    endfunction

    virtual function void write_scb_slv01(axi_transaction t);
        process_downstream(t, 1);
    endfunction

    // Dispatch an upstream monitor transaction to the write or read checker.
    local function void process_upstream(axi_transaction tr, int unsigned mst_idx);
        case (tr.trans_type)
            WRITE: process_write(tr, mst_idx);
            READ:  process_read(tr, mst_idx);
            default: begin
                error_count++;
                `uvm_error(get_type_name(), "Unknown transaction type from upstream monitor")
            end
        endcase
    endfunction

    // Record a downstream monitor transaction and match it against the expected route.
    local function void process_downstream(axi_transaction tr, int unsigned slv_idx);
        bit [ADDR_WIDTH-1:0] addr;
        int expected_slv;

        addr = (tr.trans_type == WRITE) ? tr.awaddr : tr.araddr;
        expected_slv = decode_slave(addr);

        if (expected_slv < 0) begin
            error_count++;
            `uvm_error(get_type_name(), $sformatf("illegal address leaked to downstream slv%0d addr=0x%08h", slv_idx, addr))
            return;
        end

        if (expected_slv != int'(slv_idx)) begin
            error_count++;
            `uvm_error(get_type_name(), $sformatf("route error: addr=0x%08h expected slv%0d observed slv%0d",
                                                  addr, expected_slv, slv_idx))
            return;
        end

        if (slv_idx == 0)
            act_slv00_q.push_back(tr);
        else
            act_slv01_q.push_back(tr);

        match_downstream_queue(slv_idx);
    endfunction

    // Check one completed upstream write and update the reference memory model.
    local function void process_write(axi_transaction tr, int unsigned mst_idx);
        int beats;
        bit legal_addr;
        bit [ADDR_WIDTH-1:0] addr;
        bit [ADDR_WIDTH-1:0] word_addr;
        bit [DATA_WIDTH-1:0] old_word;

        beats = int'(tr.awlen) + 1;
        legal_addr = !is_decerr_expected(tr.awaddr);

        if (!check_write_shape(tr))
            return;

        if (!check_wrap_legal(tr.awaddr, tr.awlen, tr.awburst, tr.awsize, "AW"))
            return;

        if (tr.awid !== tr.bid) begin
            error_count++;
            `uvm_error(get_type_name(), $sformatf("WRITE ID mismatch: awid=0x%0h bid=0x%0h", tr.awid, tr.bid))
        end

        if (!legal_addr) begin
            decerr_count++;
            if (tr.bresp !== DECERR) begin
                error_count++;
                `uvm_error(get_type_name(), $sformatf("WRITE expected DECERR, got bresp=%0b addr=0x%08h", tr.bresp, tr.awaddr))
            end
            return;
        end

        if (tr.bresp !== OKAY) begin
            error_count++;
            `uvm_error(get_type_name(), $sformatf("WRITE expected OKAY, got bresp=%0b addr=0x%08h", tr.bresp, tr.awaddr))
        end

        enqueue_expected_downstream(WRITE, mst_idx, tr.awid, tr.awaddr, tr.awlen, tr.awsize, tr.awburst);

        for (int i = 0; i < beats; i++) begin
            addr = calculate_beat_addr(tr.awaddr, tr.awlen, tr.awburst, tr.awsize, i);
            word_addr = {addr[ADDR_WIDTH-1:2], 2'b00};
            void'(check_wstrb_legal(addr, tr.awsize, tr.wstrb[i], i));

            old_word = ref_mem.exists(word_addr) ? ref_mem[word_addr] : '0;
            ref_mem[word_addr] = merge_data_with_strb(old_word, tr.wdata[i], tr.wstrb[i]);
        end
    endfunction

    // Check one completed upstream read against the reference memory model.
    local function void process_read(axi_transaction tr, int unsigned mst_idx);
        int beats;
        bit legal_addr;
        bit [ADDR_WIDTH-1:0] addr;
        bit [ADDR_WIDTH-1:0] word_addr;
        bit [DATA_WIDTH-1:0] expected_data;

        beats = int'(tr.arlen) + 1;
        legal_addr = !is_decerr_expected(tr.araddr);

        if (!check_read_shape(tr))
            return;

        if (!check_wrap_legal(tr.araddr, tr.arlen, tr.arburst, tr.arsize, "AR"))
            return;

        if (tr.arid !== tr.rid) begin
            error_count++;
            `uvm_error(get_type_name(), $sformatf("READ ID mismatch: arid=0x%0h rid=0x%0h", tr.arid, tr.rid))
        end

        if (!legal_addr) begin
            decerr_count++;
            foreach (tr.rresp[i]) begin
                if (tr.rresp[i] !== DECERR) begin
                    error_count++;
                    `uvm_error(get_type_name(), $sformatf("READ expected DECERR, got rresp[%0d]=%0b addr=0x%08h",
                                                          i, tr.rresp[i], tr.araddr))
                end
            end
            return;
        end

        foreach (tr.rresp[i]) begin
            if (tr.rresp[i] !== OKAY) begin
                error_count++;
                `uvm_error(get_type_name(), $sformatf("READ expected OKAY, got rresp[%0d]=%0b addr=0x%08h",
                                                      i, tr.rresp[i], tr.araddr))
            end
        end

        enqueue_expected_downstream(READ, mst_idx, tr.arid, tr.araddr, tr.arlen, tr.arsize, tr.arburst);

        for (int i = 0; i < beats; i++) begin
            addr = calculate_beat_addr(tr.araddr, tr.arlen, tr.arburst, tr.arsize, i);
            word_addr = {addr[ADDR_WIDTH-1:2], 2'b00};
            expected_data = ref_mem.exists(word_addr) ? ref_mem[word_addr] : '0;
            check_count++;

            if (tr.rdata[i] !== expected_data) begin
                error_count++;
                `uvm_error(get_type_name(), $sformatf("READ data mismatch beat[%0d] addr=0x%08h exp=0x%08h act=0x%08h",
                                                      i, addr, expected_data, tr.rdata[i]))
            end
        end
    endfunction

    // Queue the downstream transaction expected from a legal upstream access.
    local function void enqueue_expected_downstream(
        trans_type_enum      trans_type,
        int unsigned         mst_idx,
        bit [ID_WIDTH-1:0]   id,
        bit [ADDR_WIDTH-1:0] addr,
        burst_len_enum       len,
        burst_size_enum      size,
        burst_type_enum      burst
    );
        expected_downstream_txn_t exp;
        int slv_idx;

        slv_idx = decode_slave(addr);
        if (slv_idx < 0)
            return;

        exp.trans_type = trans_type;
        exp.mst_idx    = mst_idx;
        exp.id         = id;
        exp.addr       = addr;
        exp.len        = len;
        exp.size       = size;
        exp.burst      = burst;

        if (slv_idx == 0)
            exp_slv00_q.push_back(exp);
        else
            exp_slv01_q.push_back(exp);

        match_downstream_queue(slv_idx);
    endfunction

    // Compare pending expected and observed downstream transactions for one slave.
    local function void match_downstream_queue(int unsigned slv_idx);
        expected_downstream_txn_t exp;
        axi_transaction act;

        if (slv_idx == 0) begin
            while (exp_slv00_q.size() > 0 && act_slv00_q.size() > 0) begin
                exp = exp_slv00_q.pop_front();
                act = act_slv00_q.pop_front();
                check_downstream_txn(exp, act, slv_idx);
            end
        end else begin
            while (exp_slv01_q.size() > 0 && act_slv01_q.size() > 0) begin
                exp = exp_slv01_q.pop_front();
                act = act_slv01_q.pop_front();
                check_downstream_txn(exp, act, slv_idx);
            end
        end
    endfunction

    // Check that a routed downstream transaction preserves the expected AXI attributes.
    local function void check_downstream_txn(
        expected_downstream_txn_t exp,
        axi_transaction act,
        int unsigned slv_idx
    );
        bit [M_ID_WIDTH-1:0] exp_id;

        exp_id = expected_m_id(exp.mst_idx, exp.id);

        if (act.trans_type !== exp.trans_type) begin
            error_count++;
            `uvm_error(get_type_name(), $sformatf("downstream slv%0d type mismatch", slv_idx))
            return;
        end

        if (exp.trans_type == WRITE) begin
            if (act.m_awid !== exp_id) begin
                error_count++;
                `uvm_error(get_type_name(), $sformatf("downstream AWID mismatch slv%0d exp=0x%0h act=0x%0h", slv_idx, exp_id, act.m_awid))
            end
            if (act.m_bid !== exp_id) begin
                error_count++;
                `uvm_error(get_type_name(), $sformatf("downstream BID mismatch slv%0d exp=0x%0h act=0x%0h", slv_idx, exp_id, act.m_bid))
            end
            if (act.awaddr !== exp.addr || act.awlen !== exp.len || act.awsize !== exp.size || act.awburst !== exp.burst) begin
                error_count++;
                `uvm_error(get_type_name(), $sformatf("downstream AW attr mismatch slv%0d exp addr=0x%08h len=%0d size=%0d burst=%0s act addr=0x%08h len=%0d size=%0d burst=%0s",
                                                      slv_idx, exp.addr, exp.len, exp.size, exp.burst.name(),
                                                      act.awaddr, act.awlen, act.awsize, act.awburst.name()))
            end
            if (act.bresp !== OKAY) begin
                error_count++;
                `uvm_error(get_type_name(), $sformatf("downstream B expected OKAY slv%0d bresp=%0b", slv_idx, act.bresp))
            end
        end else begin
            if (act.m_arid !== exp_id) begin
                error_count++;
                `uvm_error(get_type_name(), $sformatf("downstream ARID mismatch slv%0d exp=0x%0h act=0x%0h", slv_idx, exp_id, act.m_arid))
            end
            if (act.m_rid !== exp_id) begin
                error_count++;
                `uvm_error(get_type_name(), $sformatf("downstream RID mismatch slv%0d exp=0x%0h act=0x%0h", slv_idx, exp_id, act.m_rid))
            end
            if (act.araddr !== exp.addr || act.arlen !== exp.len || act.arsize !== exp.size || act.arburst !== exp.burst) begin
                error_count++;
                `uvm_error(get_type_name(), $sformatf("downstream AR attr mismatch slv%0d exp addr=0x%08h len=%0d size=%0d burst=%0s act addr=0x%08h len=%0d size=%0d burst=%0s",
                                                      slv_idx, exp.addr, exp.len, exp.size, exp.burst.name(),
                                                      act.araddr, act.arlen, act.arsize, act.arburst.name()))
            end
            foreach (act.rresp[i]) begin
                if (act.rresp[i] !== OKAY) begin
                    error_count++;
                    `uvm_error(get_type_name(), $sformatf("downstream R expected OKAY slv%0d beat=%0d rresp=%0b", slv_idx, i, act.rresp[i]))
                end
            end
        end
    endfunction

    // Validate write beat arrays and beat count against AWLEN.
    local function bit check_write_shape(axi_transaction tr);
        int beats;
        bit ok;

        beats = int'(tr.awlen) + 1;
        ok = 1;

        if (tr.wdata.size() != beats) begin
            error_count++;
            `uvm_error(get_type_name(), $sformatf("WRITE wdata size mismatch exp=%0d act=%0d", beats, tr.wdata.size()))
            ok = 0;
        end
        if (tr.wstrb.size() != beats) begin
            error_count++;
            `uvm_error(get_type_name(), $sformatf("WRITE wstrb size mismatch exp=%0d act=%0d", beats, tr.wstrb.size()))
            ok = 0;
        end
        if (tr.current_wbeat_count != 0 && tr.current_wbeat_count != beats) begin
            error_count++;
            `uvm_error(get_type_name(), $sformatf("WRITE beat count mismatch exp=%0d act=%0d", beats, tr.current_wbeat_count))
            ok = 0;
        end
        return ok;
    endfunction

    // Validate read beat arrays and beat count against ARLEN.
    local function bit check_read_shape(axi_transaction tr);
        int beats;
        bit ok;

        beats = int'(tr.arlen) + 1;
        ok = 1;

        if (tr.rdata.size() != beats) begin
            error_count++;
            `uvm_error(get_type_name(), $sformatf("READ rdata size mismatch exp=%0d act=%0d", beats, tr.rdata.size()))
            ok = 0;
        end
        if (tr.rresp.size() != beats) begin
            error_count++;
            `uvm_error(get_type_name(), $sformatf("READ rresp size mismatch exp=%0d act=%0d", beats, tr.rresp.size()))
            ok = 0;
        end
        if (tr.current_rbeat_count != 0 && tr.current_rbeat_count != beats) begin
            error_count++;
            `uvm_error(get_type_name(), $sformatf("READ beat count mismatch exp=%0d act=%0d", beats, tr.current_rbeat_count))
            ok = 0;
        end
        return ok;
    endfunction

    // Check the basic AXI legality rules for a WRAP burst.
    local function bit check_wrap_legal(
        bit [ADDR_WIDTH-1:0] addr,
        burst_len_enum len,
        burst_type_enum burst,
        burst_size_enum size,
        string chan
    );
        int unsigned bytes_per_beat;

        if (burst != WRAP)
            return 1;

        bytes_per_beat = 1 << int'(size);

        if (!(len inside {BURST_LEN_2BEATS, BURST_LEN_4BEATS, BURST_LEN_8BEATS, BURST_LEN_16BEATS})) begin
            error_count++;
            `uvm_error(get_type_name(), $sformatf("%s illegal WRAP len=%0d", chan, len))
            return 0;
        end

        if ((addr % bytes_per_beat) != 0) begin
            error_count++;
            `uvm_error(get_type_name(), $sformatf("%s WRAP unaligned addr=0x%08h size=%0d", chan, addr, size))
            return 0;
        end

        return 1;
    endfunction

    // Check that WSTRB only enables byte lanes inside the current transfer.
    local function bit check_wstrb_legal(
        bit [ADDR_WIDTH-1:0] addr,
        burst_size_enum size,
        bit [STRB_WIDTH-1:0] wstrb,
        int beat_idx
    );
        bit [STRB_WIDTH-1:0] mask;

        mask = legal_wstrb_mask(addr, size);
        if ((wstrb & ~mask) != '0) begin
            error_count++;
            `uvm_error(get_type_name(), $sformatf("WSTRB outside transfer lane beat=%0d addr=0x%08h size=%0d wstrb=%04b legal=%04b",
                                                  beat_idx, addr, size, wstrb, mask))
            return 0;
        end
        return 1;
    endfunction

    // Build the legal WSTRB byte-lane mask for an address and transfer size.
    local function bit [STRB_WIDTH-1:0] legal_wstrb_mask(
        bit [ADDR_WIDTH-1:0] addr,
        burst_size_enum size
    );
        bit [STRB_WIDTH-1:0] mask;
        int unsigned bytes;
        int unsigned offset;

        mask = '0;
        bytes = 1 << int'(size);
        offset = addr[1:0];

        for (int i = 0; i < bytes; i++) begin
            if ((offset + i) < STRB_WIDTH)
                mask[offset + i] = 1'b1;
        end
        return mask;
    endfunction

    // Calculate the effective byte address for a burst beat.
    local function bit [ADDR_WIDTH-1:0] calculate_beat_addr(
        bit [ADDR_WIDTH-1:0] base_addr,
        burst_len_enum burst_len,
        burst_type_enum burst_type,
        burst_size_enum burst_size,
        int beat_idx
    );
        int unsigned stride;
        int unsigned total_bytes;
        bit [ADDR_WIDTH-1:0] aligned_start;
        bit [ADDR_WIDTH-1:0] wrap_low;
        bit [ADDR_WIDTH-1:0] offset;
        bit [ADDR_WIDTH-1:0] beat_addr;

        stride = 1 << int'(burst_size);
        aligned_start = (base_addr / stride) * stride;

        case (burst_type)
            FIXED: beat_addr = base_addr;
            INCR:  beat_addr = (beat_idx == 0) ? base_addr : aligned_start + beat_idx * stride;
            WRAP: begin
                total_bytes = (int'(burst_len) + 1) * stride;
                wrap_low = (base_addr / total_bytes) * total_bytes;
                offset = base_addr - wrap_low;
                beat_addr = wrap_low + ((offset + beat_idx * stride) % total_bytes);
            end
            default: begin
                error_count++;
                `uvm_error(get_type_name(), $sformatf("illegal burst_type=%0b", burst_type))
                beat_addr = base_addr;
            end
        endcase

        return beat_addr;
    endfunction

    // Merge write data into one reference word according to WSTRB.
    local function bit [DATA_WIDTH-1:0] merge_data_with_strb(
        bit [DATA_WIDTH-1:0] old_data,
        bit [DATA_WIDTH-1:0] new_data,
        bit [STRB_WIDTH-1:0] wstrb
    );
        bit [DATA_WIDTH-1:0] new_word;

        new_word = old_data;
        for (int lane = 0; lane < STRB_WIDTH; lane++) begin
            if (wstrb[lane])
                new_word[lane*8 +: 8] = new_data[lane*8 +: 8];
        end
        return new_word;
    endfunction

    // Convert an upstream master index and ID into the expected downstream ID.
    local function bit [M_ID_WIDTH-1:0] expected_m_id(int unsigned mst_idx, bit [ID_WIDTH-1:0] id);
        return {mst_idx[0], id};
    endfunction

    // Decode an address into the target slave index.
    local function int decode_slave(bit [ADDR_WIDTH-1:0] addr);
        if (addr >= 32'h0000_0000 && addr <= 32'h0000_FFFF)
            return 0;
        if (addr >= 32'h0001_0000 && addr <= 32'h0001_FFFF)
            return 1;
        return -1;
    endfunction

    // Return whether the address should produce a DECERR response.
    local function bit is_decerr_expected(bit [ADDR_WIDTH-1:0] addr);
        return (decode_slave(addr) < 0);
    endfunction

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);

        if (exp_slv00_q.size() || exp_slv01_q.size() || act_slv00_q.size() || act_slv01_q.size()) begin
            error_count++;
            `uvm_error(get_type_name(), $sformatf("unmatched downstream txn: exp_s0=%0d exp_s1=%0d act_s0=%0d act_s1=%0d",
                                                  exp_slv00_q.size(), exp_slv01_q.size(),
                                                  act_slv00_q.size(), act_slv01_q.size()))
        end

        if (error_count == 0)
            `uvm_info(get_type_name(), $sformatf("Scoreboard PASS: check_count=%0d decerr_count=%0d", check_count, decerr_count), UVM_LOW)
        else
            `uvm_error(get_type_name(), $sformatf("Scoreboard ERROR: check_count=%0d decerr_count=%0d error_count=%0d",
                                                  check_count, decerr_count, error_count))
    endfunction

endclass

`endif
