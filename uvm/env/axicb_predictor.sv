`ifndef AXICB_PREDICTOR_SV
`define AXICB_PREDICTOR_SV

`uvm_analysis_imp_decl(_pred_mst00)
`uvm_analysis_imp_decl(_pred_mst01)
`uvm_analysis_imp_decl(_pred_slv00)
`uvm_analysis_imp_decl(_pred_slv01)

class axicb_write_context extends uvm_object;
    int unsigned         src_master;
    int                  dst_slave;
    bit                  legal;
    bit [ID_WIDTH-1:0]   src_id;
    bit [M_ID_WIDTH-1:0] dst_id;
    bit [ADDR_WIDTH-1:0] addr;
    bit [7:0]            len;
    bit [2:0]            size;
    bit [1:0]            burst;
    int unsigned         beat_count;
    longint unsigned     txn_key;
    int unsigned         epoch;
    bit [DATA_WIDTH-1:0] wdata[$];
    bit [STRB_WIDTH-1:0] wstrb[$];

    `uvm_object_utils(axicb_write_context)

    function new(string name = "axicb_write_context");
        super.new(name);
    endfunction
endclass

class axicb_read_context extends uvm_object;
    int unsigned         src_master;
    int                  dst_slave;
    bit [ID_WIDTH-1:0]   src_id;
    bit [M_ID_WIDTH-1:0] dst_id;
    bit [ADDR_WIDTH-1:0] addr;
    bit [7:0]            len;
    bit [2:0]            size;
    bit [1:0]            burst;
    int unsigned         beat_count;
    longint unsigned     txn_key;
    int unsigned         epoch;

    `uvm_object_utils(axicb_read_context)

    function new(string name = "axicb_read_context");
        super.new(name);
    endfunction
endclass

// Architectural predictor for the instantiated 2x2 crossbar.  It models only
// deterministic interface transformations; arbitration latency and READY timing
// remain the responsibility of assertions and scenario-specific checkers.
class axicb_predictor extends uvm_component;
    `uvm_component_utils(axicb_predictor)

    axi_configuration cfg;

    uvm_analysis_imp_pred_mst00 #(axi_channel_event, axicb_predictor) mst00_export;
    uvm_analysis_imp_pred_mst01 #(axi_channel_event, axicb_predictor) mst01_export;
    uvm_analysis_imp_pred_slv00 #(axi_channel_event, axicb_predictor) slv00_export;
    uvm_analysis_imp_pred_slv01 #(axi_channel_event, axicb_predictor) slv01_export;
    uvm_analysis_port #(axi_channel_event) expected_port;

    axicb_write_context aw_queue[S_COUNT][$];
    axicb_write_context write_rsp_queue[$];
    axicb_read_context  read_rsp_queue[$];

    bit [DATA_WIDTH-1:0] ref_mem[bit [ADDR_WIDTH-1:0]];
    longint unsigned next_txn_key;
    int unsigned epoch;
    int unsigned memory_check_count;

    function new(string name = "axicb_predictor", uvm_component parent = null);
        super.new(name, parent);
        mst00_export = new("mst00_export", this);
        mst01_export = new("mst01_export", this);
        slv00_export = new("slv00_export", this);
        slv01_export = new("slv01_export", this);
        expected_port = new("expected_port", this);
    endfunction

    virtual function void write_pred_mst00(axi_channel_event ev);
        process_upstream(ev, 0);
    endfunction

    virtual function void write_pred_mst01(axi_channel_event ev);
        process_upstream(ev, 1);
    endfunction

    virtual function void write_pred_slv00(axi_channel_event ev);
        process_downstream(ev);
    endfunction

    virtual function void write_pred_slv01(axi_channel_event ev);
        process_downstream(ev);
    endfunction

    local function void process_upstream(axi_channel_event ev, int unsigned mst_idx);
        if (ev.kind == AXI_EVT_RESET) begin
            if (mst_idx == 0)
                reset_model();
            return;
        end

        case (ev.kind)
            AXI_EVT_AW: predict_aw(ev, mst_idx);
            AXI_EVT_W:  predict_w(ev, mst_idx);
            AXI_EVT_AR: predict_ar(ev, mst_idx);
            default: ; // upstream B/R are predictor outputs, not inputs
        endcase
    endfunction

    local function void process_downstream(axi_channel_event ev);
        case (ev.kind)
            AXI_EVT_B: predict_b(ev);
            AXI_EVT_R: predict_r(ev);
            default: ; // downstream AW/W/AR are predictor outputs
        endcase
    endfunction

    local function void predict_aw(axi_channel_event ev, int unsigned mst_idx);
        axicb_write_context ctx;
        axi_channel_event exp;

        ctx = new("write_ctx");
        ctx.src_master = mst_idx;
        ctx.dst_slave  = decode_slave(ev.addr);
        ctx.legal      = ctx.dst_slave >= 0;
        ctx.src_id     = ev.id[ID_WIDTH-1:0];
        ctx.dst_id     = {mst_idx[0], ev.id[ID_WIDTH-1:0]};
        ctx.addr        = ev.addr;
        ctx.len         = ev.len;
        ctx.size        = ev.size;
        ctx.burst       = ev.burst;
        ctx.txn_key     = next_txn_key++;
        ctx.epoch       = epoch;
        aw_queue[mst_idx].push_back(ctx);

        if (ctx.legal) begin
            write_rsp_queue.push_back(ctx);
            exp = copy_event(ev, "exp_aw");
            exp.is_downstream = 1;
            exp.port_idx      = ctx.dst_slave;
            exp.id            = ctx.dst_id;
            exp.region        = '0;
            exp.user          = '0;
            stamp_and_send(exp, ctx.txn_key);
        end
    endfunction

    local function void predict_w(axi_channel_event ev, int unsigned mst_idx);
        axicb_write_context ctx;
        axi_channel_event exp;
        int unsigned expected_beats;

        if (aw_queue[mst_idx].size() == 0) begin
            `uvm_error(get_type_name(), $sformatf("master%0d W beat has no accepted AW", mst_idx))
            return;
        end

        ctx = aw_queue[mst_idx][0];
        expected_beats = int'(ctx.len) + 1;
        ctx.wdata.push_back(ev.data);
        ctx.wstrb.push_back(ev.strb);
        ctx.beat_count++;

        if (ctx.legal) begin
            exp = copy_event(ev, "exp_w");
            exp.is_downstream = 1;
            exp.port_idx      = ctx.dst_slave;
            exp.user          = '0;
            stamp_and_send(exp, ctx.txn_key);
        end

        if (ev.last !== (ctx.beat_count == expected_beats))
            `uvm_error(get_type_name(), $sformatf(
                "master%0d WLAST mismatch key=%0d beat=%0d expected_beats=%0d",
                mst_idx, ctx.txn_key, ctx.beat_count, expected_beats))

        if (ev.last) begin
            if (ctx.legal)
                commit_write(ctx);
            else begin
                exp = new("exp_decerr_b");
                exp.kind          = AXI_EVT_B;
                exp.is_downstream = 0;
                exp.port_idx      = mst_idx;
                exp.id            = ctx.src_id;
                exp.resp          = DECERR;
                stamp_and_send(exp, ctx.txn_key);
            end
            void'(aw_queue[mst_idx].pop_front());
        end
    endfunction

    local function void predict_b(axi_channel_event ev);
        axi_channel_event exp;
        int idx;

        idx = find_write_by_id(ev.id);
        if (idx < 0) begin
            `uvm_error(get_type_name(), $sformatf("downstream BID 0x%0h has no outstanding write", ev.id))
            return;
        end

        if (ev.port_idx != write_rsp_queue[idx].dst_slave)
            `uvm_error(get_type_name(), $sformatf(
                "B response arrived on slv%0d, expected slv%0d key=%0d",
                ev.port_idx, write_rsp_queue[idx].dst_slave,
                write_rsp_queue[idx].txn_key))

        exp = copy_event(ev, "exp_b");
        exp.is_downstream = 0;
        exp.port_idx      = write_rsp_queue[idx].src_master;
        exp.id            = write_rsp_queue[idx].src_id;
        stamp_and_send(exp, write_rsp_queue[idx].txn_key);
        write_rsp_queue.delete(idx);
    endfunction

    local function void predict_ar(axi_channel_event ev, int unsigned mst_idx);
        axicb_read_context ctx;
        axi_channel_event exp;
        int dst;

        dst = decode_slave(ev.addr);
        ctx = new("read_ctx");
        ctx.src_master = mst_idx;
        ctx.dst_slave  = dst;
        ctx.src_id     = ev.id[ID_WIDTH-1:0];
        ctx.dst_id     = {mst_idx[0], ev.id[ID_WIDTH-1:0]};
        ctx.addr        = ev.addr;
        ctx.len         = ev.len;
        ctx.size        = ev.size;
        ctx.burst       = ev.burst;
        ctx.txn_key     = next_txn_key++;
        ctx.epoch       = epoch;

        if (dst >= 0) begin
            read_rsp_queue.push_back(ctx);
            exp = copy_event(ev, "exp_ar");
            exp.is_downstream = 1;
            exp.port_idx      = dst;
            exp.id            = ctx.dst_id;
            exp.region        = '0;
            exp.user          = '0;
            stamp_and_send(exp, ctx.txn_key);
        end else begin
            for (int i = 0; i <= int'(ev.len); i++) begin
                exp = new("exp_decerr_r");
                exp.kind          = AXI_EVT_R;
                exp.is_downstream = 0;
                exp.port_idx      = mst_idx;
                exp.id            = ctx.src_id;
                exp.data          = '0;
                exp.resp          = DECERR;
                exp.last          = i == int'(ev.len);
                stamp_and_send(exp, ctx.txn_key);
            end
        end
    endfunction

    local function void predict_r(axi_channel_event ev);
        axi_channel_event exp;
        axicb_read_context ctx;
        bit [ADDR_WIDTH-1:0] beat_addr;
        bit [ADDR_WIDTH-1:0] word_addr;
        bit [DATA_WIDTH-1:0] expected_data;
        int idx;
        int unsigned expected_beats;

        idx = find_read_by_id(ev.id);
        if (idx < 0) begin
            `uvm_error(get_type_name(), $sformatf("downstream RID 0x%0h has no outstanding read", ev.id))
            return;
        end

        ctx = read_rsp_queue[idx];
        if (ev.port_idx != ctx.dst_slave)
            `uvm_error(get_type_name(), $sformatf(
                "R response arrived on slv%0d, expected slv%0d key=%0d",
                ev.port_idx, ctx.dst_slave, ctx.txn_key))
        expected_beats = int'(ctx.len) + 1;
        beat_addr = calculate_beat_addr(ctx.addr, ctx.len, ctx.burst, ctx.size, ctx.beat_count);
        word_addr = {beat_addr[ADDR_WIDTH-1:2], 2'b00};
        expected_data = ref_mem.exists(word_addr) ? ref_mem[word_addr] : '0;
        memory_check_count++;
        if (ev.data !== expected_data)
            `uvm_error(get_type_name(), $sformatf(
                "reference memory mismatch key=%0d beat=%0d addr=0x%08h exp=0x%08h act=0x%08h",
                ctx.txn_key, ctx.beat_count, beat_addr, expected_data, ev.data))

        ctx.beat_count++;
        if (ev.last !== (ctx.beat_count == expected_beats))
            `uvm_error(get_type_name(), $sformatf(
                "downstream RLAST mismatch key=%0d beat=%0d expected_beats=%0d",
                ctx.txn_key, ctx.beat_count, expected_beats))

        exp = copy_event(ev, "exp_r");
        exp.is_downstream = 0;
        exp.port_idx      = ctx.src_master;
        exp.id            = ctx.src_id;
        stamp_and_send(exp, ctx.txn_key);

        if (ev.last)
            read_rsp_queue.delete(idx);
    endfunction

    local function axi_channel_event copy_event(axi_channel_event ev, string name);
        axi_channel_event result;
        result = new(name);
        result.copy(ev);
        return result;
    endfunction

    local function void stamp_and_send(axi_channel_event ev, longint unsigned key);
        ev.txn_key = key;
        ev.epoch   = epoch;
        expected_port.write(ev);
    endfunction

    local function int decode_slave(bit [ADDR_WIDTH-1:0] addr);
        for (int i = 0; i < S_COUNT; i++) begin
            if ((addr >> cfg.slv_addr_width[i]) ==
                (cfg.slv_base_addr[i] >> cfg.slv_addr_width[i]))
                return i;
        end
        return -1;
    endfunction

    local function int find_write_by_id(bit [M_ID_WIDTH-1:0] id);
        foreach (write_rsp_queue[i])
            if (write_rsp_queue[i].dst_id == id)
                return i;
        return -1;
    endfunction

    local function int find_read_by_id(bit [M_ID_WIDTH-1:0] id);
        foreach (read_rsp_queue[i])
            if (read_rsp_queue[i].dst_id == id)
                return i;
        return -1;
    endfunction

    local function void commit_write(axicb_write_context ctx);
        bit [ADDR_WIDTH-1:0] beat_addr;
        bit [ADDR_WIDTH-1:0] word_addr;
        bit [DATA_WIDTH-1:0] old_word;

        foreach (ctx.wdata[i]) begin
            beat_addr = calculate_beat_addr(ctx.addr, ctx.len, ctx.burst, ctx.size, i);
            word_addr = {beat_addr[ADDR_WIDTH-1:2], 2'b00};
            old_word = ref_mem.exists(word_addr) ? ref_mem[word_addr] : '0;
            for (int lane = 0; lane < STRB_WIDTH; lane++)
                if (ctx.wstrb[i][lane])
                    old_word[lane*8 +: 8] = ctx.wdata[i][lane*8 +: 8];
            ref_mem[word_addr] = old_word;
        end
    endfunction

    local function bit [ADDR_WIDTH-1:0] calculate_beat_addr(
        bit [ADDR_WIDTH-1:0] base_addr,
        bit [7:0] len,
        bit [1:0] burst,
        bit [2:0] size,
        int beat_idx
    );
        int unsigned stride;
        int unsigned total_bytes;
        bit [ADDR_WIDTH-1:0] aligned_start;
        bit [ADDR_WIDTH-1:0] wrap_low;

        stride = 1 << int'(size);
        aligned_start = (base_addr / stride) * stride;
        case (burst)
            FIXED: return base_addr;
            INCR:  return beat_idx == 0 ? base_addr : aligned_start + beat_idx * stride;
            WRAP: begin
                total_bytes = (int'(len) + 1) * stride;
                wrap_low = (base_addr / total_bytes) * total_bytes;
                return wrap_low + ((base_addr - wrap_low + beat_idx * stride) % total_bytes);
            end
            default: return base_addr;
        endcase
    endfunction

    local function void reset_model();
        foreach (aw_queue[i])
            aw_queue[i].delete();
        write_rsp_queue.delete();
        read_rsp_queue.delete();
        ref_mem.delete();
        epoch++;
    endfunction

    function void report_phase(uvm_phase phase);
        int pending_aw = 0;
        super.report_phase(phase);
        foreach (aw_queue[i])
            pending_aw += aw_queue[i].size();
        if (pending_aw || write_rsp_queue.size() || read_rsp_queue.size())
            `uvm_error(get_type_name(), $sformatf(
                "undrained predictor state: aw=%0d b=%0d r=%0d",
                pending_aw, write_rsp_queue.size(), read_rsp_queue.size()))
    endfunction
endclass

`endif
