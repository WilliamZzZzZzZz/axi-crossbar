`ifndef AXICB_SCOREBOARD_SV
`define AXICB_SCOREBOARD_SV

`uvm_analysis_imp_decl(_scb_expected)
`uvm_analysis_imp_decl(_scb_mst00)
`uvm_analysis_imp_decl(_scb_mst01)
`uvm_analysis_imp_decl(_scb_slv00)
`uvm_analysis_imp_decl(_scb_slv01)

// Compares predictor output with channel transfers observed at DUT outputs.
// Protocol timing and arbitration fairness remain in assertions/vseq checkers.
class axicb_scoreboard extends uvm_component;
    `uvm_component_utils(axicb_scoreboard)

    uvm_analysis_imp_scb_expected #(axi_channel_event, axicb_scoreboard) expected_export;
    uvm_analysis_imp_scb_mst00 #(axi_channel_event, axicb_scoreboard) mst00_export;
    uvm_analysis_imp_scb_mst01 #(axi_channel_event, axicb_scoreboard) mst01_export;
    uvm_analysis_imp_scb_slv00 #(axi_channel_event, axicb_scoreboard) slv00_export;
    uvm_analysis_imp_scb_slv01 #(axi_channel_event, axicb_scoreboard) slv01_export;

    axi_channel_event expected_q[$];
    longint unsigned downstream_w_key[S_COUNT][$];

    int unsigned check_count;
    int unsigned error_count;
    int unsigned decerr_count;

    function new(string name = "axicb_scoreboard", uvm_component parent = null);
        super.new(name, parent);
        expected_export = new("expected_export", this);
        mst00_export = new("mst00_export", this);
        mst01_export = new("mst01_export", this);
        slv00_export = new("slv00_export", this);
        slv01_export = new("slv01_export", this);
    endfunction

    virtual function void write_scb_expected(axi_channel_event ev);
        axi_channel_event copy;
        copy = new("expected_copy");
        copy.copy(ev);
        expected_q.push_back(copy);
        if ((copy.kind == AXI_EVT_B || (copy.kind == AXI_EVT_R && copy.last)) &&
            copy.resp == DECERR)
            decerr_count++;
    endfunction

    virtual function void write_scb_mst00(axi_channel_event ev);
        process_actual(ev, 0, 0);
    endfunction

    virtual function void write_scb_mst01(axi_channel_event ev);
        process_actual(ev, 0, 1);
    endfunction

    virtual function void write_scb_slv00(axi_channel_event ev);
        process_actual(ev, 1, 0);
    endfunction

    virtual function void write_scb_slv01(axi_channel_event ev);
        process_actual(ev, 1, 1);
    endfunction

    local function void process_actual(
        axi_channel_event ev,
        bit is_downstream,
        int unsigned port_idx
    );
        int idx;
        longint unsigned key;

        if (ev.kind == AXI_EVT_RESET) begin
            if (!is_downstream && port_idx == 0)
                flush_state();
            return;
        end

        // Only DUT outputs are compared.  The opposite directions feed the predictor.
        if ((!is_downstream && !(ev.kind inside {AXI_EVT_B, AXI_EVT_R})) ||
            ( is_downstream && !(ev.kind inside {AXI_EVT_AW, AXI_EVT_W, AXI_EVT_AR})))
            return;

        if (is_downstream && ev.kind == AXI_EVT_W) begin
            if (downstream_w_key[port_idx].size() == 0) begin
                record_unexpected(ev, "downstream W has no matched AW");
                return;
            end
            key = downstream_w_key[port_idx][0];
            idx = find_expected(ev, is_downstream, port_idx, key, 1);
            if (idx < 0) begin
                record_unexpected(ev, "downstream W payload/key mismatch");
                return;
            end
            compare_and_consume(ev, idx);
            if (ev.last)
                void'(downstream_w_key[port_idx].pop_front());
            return;
        end

        idx = find_expected(ev, is_downstream, port_idx, '0, 0);
        if (idx < 0) begin
            record_unexpected(ev, "no predicted DUT output");
            return;
        end

        if (is_downstream && ev.kind == AXI_EVT_AW)
            downstream_w_key[port_idx].push_back(expected_q[idx].txn_key);
        compare_and_consume(ev, idx);
    endfunction

    local function int find_expected(
        axi_channel_event actual,
        bit is_downstream,
        int unsigned port_idx,
        longint unsigned key,
        bit use_key
    );
        foreach (expected_q[i]) begin
            if (expected_q[i].is_downstream != is_downstream ||
                expected_q[i].port_idx != port_idx ||
                expected_q[i].kind != actual.kind)
                continue;
            if (use_key && expected_q[i].txn_key != key)
                continue;
            if (identity_matches(expected_q[i], actual))
                return i;
        end
        return -1;
    endfunction

    local function bit identity_matches(axi_channel_event exp, axi_channel_event act);
        case (act.kind)
            AXI_EVT_AW, AXI_EVT_AR:
                return exp.id == act.id && exp.addr == act.addr &&
                       exp.len == act.len && exp.size == act.size &&
                       exp.burst == act.burst;
            AXI_EVT_W:
                return exp.data == act.data && exp.strb == act.strb &&
                       exp.last == act.last;
            AXI_EVT_B:
                return exp.id == act.id && exp.resp == act.resp;
            AXI_EVT_R:
                return exp.id == act.id && exp.resp == act.resp &&
                       exp.data == act.data && exp.last == act.last;
            default:
                return 0;
        endcase
    endfunction

    local function void compare_and_consume(axi_channel_event act, int idx);
        axi_channel_event exp;
        bit match;

        exp = expected_q[idx];
        match = 1;
        case (act.kind)
            AXI_EVT_AW, AXI_EVT_AR: begin
                match &= exp.id     === act.id;
                match &= exp.addr   === act.addr;
                match &= exp.len    === act.len;
                match &= exp.size   === act.size;
                match &= exp.burst  === act.burst;
                match &= exp.lock   === act.lock;
                match &= exp.cache  === act.cache;
                match &= exp.prot   === act.prot;
                match &= exp.qos    === act.qos;
                match &= exp.region === act.region;
                match &= exp.user   === act.user;
            end
            AXI_EVT_W: begin
                match &= exp.data === act.data;
                match &= exp.strb === act.strb;
                match &= exp.last === act.last;
                match &= exp.user === act.user;
            end
            AXI_EVT_B: begin
                match &= exp.id   === act.id;
                match &= exp.resp === act.resp;
                match &= exp.user === act.user;
            end
            AXI_EVT_R: begin
                match &= exp.id   === act.id;
                match &= exp.data === act.data;
                match &= exp.resp === act.resp;
                match &= exp.last === act.last;
                match &= exp.user === act.user;
            end
            default: match = 0;
        endcase

        check_count++;
        if (!match) begin
            error_count++;
            `uvm_error(get_type_name(), $sformatf(
                "channel mismatch kind=%0d side=%0s port=%0d key=%0d\nEXP: %s\nACT: %s",
                act.kind, act.is_downstream ? "downstream" : "upstream",
                act.port_idx, exp.txn_key, exp.sprint(), act.sprint()))
        end
        expected_q.delete(idx);
    endfunction

    local function void record_unexpected(axi_channel_event ev, string reason);
        error_count++;
        `uvm_error(get_type_name(), $sformatf(
            "%s: kind=%0d side=%0s port=%0d id=0x%0h addr=0x%08h",
            reason, ev.kind, ev.is_downstream ? "downstream" : "upstream",
            ev.port_idx, ev.id, ev.addr))
    endfunction

    local function void flush_state();
        expected_q.delete();
        foreach (downstream_w_key[i])
            downstream_w_key[i].delete();
    endfunction

    function void report_phase(uvm_phase phase);
        int pending_w_owner = 0;
        super.report_phase(phase);
        foreach (downstream_w_key[i])
            pending_w_owner += downstream_w_key[i].size();

        if (expected_q.size() || pending_w_owner) begin
            error_count++;
            `uvm_error(get_type_name(), $sformatf(
                "unmatched expected output: events=%0d write_owners=%0d",
                expected_q.size(), pending_w_owner))
        end

        if (error_count == 0)
            `uvm_info(get_type_name(), $sformatf(
                "Scoreboard PASS: channel_checks=%0d decerr_transactions=%0d",
                check_count, decerr_count), UVM_LOW)
        else
            `uvm_error(get_type_name(), $sformatf(
                "Scoreboard ERROR: channel_checks=%0d decerr_transactions=%0d errors=%0d",
                check_count, decerr_count, error_count))
    endfunction
endclass

`endif
