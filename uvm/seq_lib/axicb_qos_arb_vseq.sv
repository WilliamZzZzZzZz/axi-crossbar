`ifndef AXICB_QOS_ARB_VSEQ_SV
`define AXICB_QOS_ARB_VSEQ_SV

class axicb_qos_arb_vseq extends axicb_conc_base_vseq;
    `uvm_object_utils(axicb_qos_arb_vseq)

    function new(string name = "axicb_qos_arb_vseq");
        super.new(name);
    endfunction

    virtual task body();
        super.body();
        if (vif_mst00.arst) @(negedge vif_mst00.arst);

        `uvm_info(get_type_name(), "========== qos_arb_test_start ==========", UVM_LOW)

        run_priority_pair(WRITE, 0, 1, 4'h0, 4'hF, 8'h10, 8'h11, BURST_LEN_16BEATS);
        run_priority_pair(WRITE, 1, 0, 4'h9, 4'h3, 8'h12, 8'h13, BURST_LEN_4BEATS);
        run_priority_pair(READ,  0, 1, 4'h0, 4'hF, 8'h20, 8'h21, BURST_LEN_4BEATS);
        run_priority_pair(READ,  1, 0, 4'h9, 4'h3, 8'h22, 8'h23, BURST_LEN_4BEATS);

        run_equal_qos_rr(WRITE, 0, 0, 4'h7, 8'h30, 8'h31);
        run_equal_qos_rr(READ,  1, 1, 4'h7, 8'h32, 8'h33);
        run_equal_qos_rr(WRITE, 1, 0, 4'h0, 8'h34, 8'h35);

        run_independent_routes(WRITE);
        run_independent_routes(READ);
        run_high_qos_decerr(WRITE);
        run_high_qos_decerr(READ);

        `uvm_info(get_type_name(), "========== qos_arb_test_end ==========", UVM_LOW)
    endtask

    local task automatic run_priority_pair(
        trans_type_enum txn_type,
        int unsigned slv_idx,
        int unsigned expected_owner,
        bit [QOS_WIDTH-1:0] qos0,
        bit [QOS_WIDTH-1:0] qos1,
        bit [ID_WIDTH-1:0] id0,
        bit [ID_WIDTH-1:0] id1,
        burst_len_enum burst_len
    );
        bit [ADDR_WIDTH-1:0] addr0 = slave_addr(slv_idx, txn_type == WRITE ? 32'h1000 : 32'h3000);
        bit [ADDR_WIDTH-1:0] addr1 = slave_addr(slv_idx, txn_type == WRITE ? 32'h2000 : 32'h4000);
        fork
            expect_first_owner(txn_type, slv_idx, expected_owner, addr0, addr1, id0, id1, qos0, qos1);
            begin
                if (txn_type == WRITE)
                    expect_downstream_w_burst_integrity(slv_idx, 2, 2000);
                else
                    expect_downstream_r_burst_integrity(slv_idx, 2, 2000);
            end
            begin
                @(negedge vif_mst00.aclk);
                fork
                    begin
                        if (txn_type == WRITE) do_qos_write(0, addr0, qos0, id0, burst_len);
                        else                   do_qos_read (0, addr0, qos0, id0, burst_len);
                    end
                    begin
                        if (txn_type == WRITE) do_qos_write(1, addr1, qos1, id1, burst_len);
                        else                   do_qos_read (1, addr1, qos1, id1, burst_len);
                    end
                join
            end
        join
    endtask

    // Prime the RR pointer with one uncontended request, then check the first
    // winner of an equal-QoS contention window.
    local task automatic run_equal_qos_rr(
        trans_type_enum txn_type,
        int unsigned slv_idx,
        int unsigned prime_owner,
        bit [QOS_WIDTH-1:0] qos,
        bit [ID_WIDTH-1:0] id0,
        bit [ID_WIDTH-1:0] id1
    );
        int unsigned expected_owner = prime_owner == 0 ? 1 : 0;
        bit [ADDR_WIDTH-1:0] base = txn_type == WRITE ? 32'h5000 : 32'h6000;
        bit [ADDR_WIDTH-1:0] prime_addr = slave_addr(slv_idx, base);
        bit [ADDR_WIDTH-1:0] addr0 = slave_addr(slv_idx, base + 32'h100);
        bit [ADDR_WIDTH-1:0] addr1 = slave_addr(slv_idx, base + 32'h200);

        if (txn_type == WRITE) do_qos_write(prime_owner, prime_addr, qos, 8'h3E, BURST_LEN_SINGLE);
        else                   do_qos_read (prime_owner, prime_addr, qos, 8'h3F, BURST_LEN_SINGLE);
        fork
            expect_first_owner(txn_type, slv_idx, expected_owner, addr0, addr1, id0, id1, qos, qos);
            begin
                @(negedge vif_mst00.aclk);
                fork
                    begin
                        if (txn_type == WRITE) do_qos_write(0, addr0, qos, id0, BURST_LEN_SINGLE);
                        else                   do_qos_read (0, addr0, qos, id0, BURST_LEN_SINGLE);
                    end
                    begin
                        if (txn_type == WRITE) do_qos_write(1, addr1, qos, id1, BURST_LEN_SINGLE);
                        else                   do_qos_read (1, addr1, qos, id1, BURST_LEN_SINGLE);
                    end
                join
            end
        join
    endtask

    local task automatic run_independent_routes(trans_type_enum txn_type);
        bit [ID_WIDTH-1:0] id0 = txn_type == WRITE ? 8'h40 : 8'h42;
        bit [ID_WIDTH-1:0] id1 = txn_type == WRITE ? 8'h41 : 8'h43;
        bit [QOS_WIDTH-1:0] qos0 = txn_type == WRITE ? 4'hF : 4'h1;
        bit [QOS_WIDTH-1:0] qos1 = txn_type == WRITE ? 4'h1 : 4'hF;
        bit [ADDR_WIDTH-1:0] addr0 = s0_mid_addr + (txn_type == WRITE ? 0 : 32'h100);
        bit [ADDR_WIDTH-1:0] addr1 = s1_mid_addr + (txn_type == WRITE ? 0 : 32'h100);

        fork
            expect_independent_routes(txn_type, id0, id1, qos0, qos1);
            begin
                @(negedge vif_mst00.aclk);
                fork
                    begin
                        if (txn_type == WRITE) do_qos_write(0, addr0, qos0, id0, BURST_LEN_SINGLE);
                        else                   do_qos_read (0, addr0, qos0, id0, BURST_LEN_SINGLE);
                    end
                    begin
                        if (txn_type == WRITE) do_qos_write(1, addr1, qos1, id1, BURST_LEN_SINGLE);
                        else                   do_qos_read (1, addr1, qos1, id1, BURST_LEN_SINGLE);
                    end
                join
            end
        join
    endtask

    local task automatic run_high_qos_decerr(trans_type_enum txn_type);
        int unsigned mst_idx = txn_type == WRITE ? 0 : 1;
        bit [ID_WIDTH-1:0] id = txn_type == WRITE ? 8'h50 : 8'h51;
        bit [ADDR_WIDTH-1:0] addr = txn_type == WRITE ? 32'hDEAD_0000 : 32'hBEEF_0000;

        fork
            expect_decerr_isolation(txn_type, mst_idx, id);
            begin
                @(negedge vif_mst00.aclk);
                if (txn_type == WRITE)
                    do_qos_write(mst_idx, addr, 4'hF, id, BURST_LEN_4BEATS, 1);
                else
                    do_qos_read(mst_idx, addr, 4'hF, id, BURST_LEN_4BEATS, 1);
            end
        join
    endtask

    local task automatic do_qos_write(
        int unsigned mst_idx,
        bit [ADDR_WIDTH-1:0] addr,
        bit [QOS_WIDTH-1:0] qos,
        bit [ID_WIDTH-1:0] id,
        burst_len_enum burst_len,
        bit expect_decerr = 0
    );
        axicb_single_write_sequence seq;
        int unsigned beats = int'(burst_len) + 1;

        seq = axicb_single_write_sequence::type_id::create("qos_write");
        seq.src_master_idx = mst_idx;
        seq.addr = addr;
        seq.data = 32'hA000_0000 | (mst_idx << 16);
        seq.burst_len = burst_len;
        seq.burst_type = INCR;
        seq.burst_size = BURST_SIZE_4BYTES;
        seq.qos = qos;
        seq.awid = id;
        seq.expect_decerr = expect_decerr;
        seq.every_beat_data = new[beats];
        for (int i = 0; i < beats; i++)
            seq.every_beat_data[i] = seq.data + i;
        seq.start(p_sequencer);

        if (seq.bresp != (expect_decerr ? DECERR : OKAY))
            `uvm_error(get_type_name(), $sformatf(
                "QoS write response mismatch master=%0d addr=%08h qos=%0h exp=%0b act=%0b",
                mst_idx, addr, qos, expect_decerr ? DECERR : OKAY, seq.bresp))
        if (seq.bid != id)
            `uvm_error(get_type_name(), $sformatf("QoS write ID mismatch exp=%0h act=%0h", id, seq.bid))
    endtask

    local task automatic do_qos_read(
        int unsigned mst_idx,
        bit [ADDR_WIDTH-1:0] addr,
        bit [QOS_WIDTH-1:0] qos,
        bit [ID_WIDTH-1:0] id,
        burst_len_enum burst_len,
        bit expect_decerr = 0
    );
        axicb_single_read_sequence seq;

        seq = axicb_single_read_sequence::type_id::create("qos_read");
        seq.src_master_idx = mst_idx;
        seq.addr = addr;
        seq.burst_len = burst_len;
        seq.burst_type = INCR;
        seq.burst_size = BURST_SIZE_4BYTES;
        seq.qos = qos;
        seq.arid = id;
        seq.expect_decerr = expect_decerr;
        seq.start(p_sequencer);

        if (seq.rresp != (expect_decerr ? DECERR : OKAY))
            `uvm_error(get_type_name(), $sformatf(
                "QoS read response mismatch master=%0d addr=%08h qos=%0h exp=%0b act=%0b",
                mst_idx, addr, qos, expect_decerr ? DECERR : OKAY, seq.rresp))
        if (seq.rid != id)
            `uvm_error(get_type_name(), $sformatf("QoS read ID mismatch exp=%0h act=%0h", id, seq.rid))
    endtask

    local task automatic expect_first_owner(
        trans_type_enum txn_type,
        int unsigned slv_idx,
        int unsigned expected_owner,
        bit [ADDR_WIDTH-1:0] addr0,
        bit [ADDR_WIDTH-1:0] addr1,
        bit [ID_WIDTH-1:0] id0,
        bit [ID_WIDTH-1:0] id1,
        bit [QOS_WIDTH-1:0] qos0,
        bit [QOS_WIDTH-1:0] qos1,
        int unsigned timeout_cycles = 500
    );
        virtual axi_if#(.ID_WIDTH(M_ID_WIDTH)) down_vif;
        bit pair_seen;
        bit m0_req;
        bit m1_req;
        bit down_hs;
        bit owner;
        bit [ID_WIDTH-1:0] expected_id;
        bit [QOS_WIDTH-1:0] expected_qos;

        down_vif = slv_idx == 0 ? vif_slv00 : vif_slv01;
        expected_id = expected_owner == 0 ? id0 : id1;
        expected_qos = expected_owner == 0 ? qos0 : qos1;

        repeat (timeout_cycles) begin
            @(vif_mst00.monitor_cb);
            if (vif_mst00.arst) continue;

            if (txn_type == WRITE) begin
                m0_req = vif_mst00.monitor_cb.awvalid && vif_mst00.monitor_cb.awid == id0 &&
                         vif_mst00.monitor_cb.awaddr == addr0 && vif_mst00.monitor_cb.awqos == qos0;
                m1_req = vif_mst01.monitor_cb.awvalid && vif_mst01.monitor_cb.awid == id1 &&
                         vif_mst01.monitor_cb.awaddr == addr1 && vif_mst01.monitor_cb.awqos == qos1;
                down_hs = down_vif.monitor_cb.awvalid && down_vif.monitor_cb.awready;
            end else begin
                m0_req = vif_mst00.monitor_cb.arvalid && vif_mst00.monitor_cb.arid == id0 &&
                         vif_mst00.monitor_cb.araddr == addr0 && vif_mst00.monitor_cb.arqos == qos0;
                m1_req = vif_mst01.monitor_cb.arvalid && vif_mst01.monitor_cb.arid == id1 &&
                         vif_mst01.monitor_cb.araddr == addr1 && vif_mst01.monitor_cb.arqos == qos1;
                down_hs = down_vif.monitor_cb.arvalid && down_vif.monitor_cb.arready;
            end

            if (!pair_seen) begin
                if (m0_req ^ m1_req) begin
                    `uvm_error(get_type_name(), "QoS requests did not enter the same arbitration window")
                    return;
                end
                if (m0_req && m1_req)
                    pair_seen = 1;
            end

            if (pair_seen && down_hs) begin
                if (txn_type == WRITE) begin
                    owner = down_vif.monitor_cb.awid[M_ID_WIDTH-1];
                    if (owner != expected_owner ||
                        down_vif.monitor_cb.awid[ID_WIDTH-1:0] != expected_id ||
                        down_vif.monitor_cb.awqos != expected_qos)
                        `uvm_error(get_type_name(), $sformatf(
                            "QoS AW winner mismatch exp_owner=%0d exp_id=%0h exp_qos=%0h act_owner=%0d act_id=%0h act_qos=%0h",
                            expected_owner, expected_id, expected_qos, owner,
                            down_vif.monitor_cb.awid[ID_WIDTH-1:0], down_vif.monitor_cb.awqos))
                end else begin
                    owner = down_vif.monitor_cb.arid[M_ID_WIDTH-1];
                    if (owner != expected_owner ||
                        down_vif.monitor_cb.arid[ID_WIDTH-1:0] != expected_id ||
                        down_vif.monitor_cb.arqos != expected_qos)
                        `uvm_error(get_type_name(), $sformatf(
                            "QoS AR winner mismatch exp_owner=%0d exp_id=%0h exp_qos=%0h act_owner=%0d act_id=%0h act_qos=%0h",
                            expected_owner, expected_id, expected_qos, owner,
                            down_vif.monitor_cb.arid[ID_WIDTH-1:0], down_vif.monitor_cb.arqos))
                end
                return;
            end
        end

        `uvm_error(get_type_name(), pair_seen ?
            "QoS downstream handshake timeout" :
            "QoS simultaneous request window was never observed")
    endtask

    local task automatic expect_independent_routes(
        trans_type_enum txn_type,
        bit [ID_WIDTH-1:0] id0,
        bit [ID_WIDTH-1:0] id1,
        bit [QOS_WIDTH-1:0] qos0,
        bit [QOS_WIDTH-1:0] qos1,
        int unsigned timeout_cycles = 500
    );
        bit seen0;
        bit seen1;

        repeat (timeout_cycles) begin
            @(vif_mst00.monitor_cb);
            if (vif_mst00.arst) continue;

            if (txn_type == WRITE) begin
                if (vif_slv00.monitor_cb.awvalid && vif_slv00.monitor_cb.awready &&
                    vif_slv00.monitor_cb.awid == {1'b0, id0} && vif_slv00.monitor_cb.awqos == qos0)
                    seen0 = 1;
                if (vif_slv01.monitor_cb.awvalid && vif_slv01.monitor_cb.awready &&
                    vif_slv01.monitor_cb.awid == {1'b1, id1} && vif_slv01.monitor_cb.awqos == qos1)
                    seen1 = 1;
            end else begin
                if (vif_slv00.monitor_cb.arvalid && vif_slv00.monitor_cb.arready &&
                    vif_slv00.monitor_cb.arid == {1'b0, id0} && vif_slv00.monitor_cb.arqos == qos0)
                    seen0 = 1;
                if (vif_slv01.monitor_cb.arvalid && vif_slv01.monitor_cb.arready &&
                    vif_slv01.monitor_cb.arid == {1'b1, id1} && vif_slv01.monitor_cb.arqos == qos1)
                    seen1 = 1;
            end

            if (seen0 && seen1) return;
        end
        `uvm_error(get_type_name(), $sformatf(
            "independent QoS routes not completed: slv0=%0b slv1=%0b", seen0, seen1))
    endtask

    local task automatic expect_decerr_isolation(
        trans_type_enum txn_type,
        int unsigned mst_idx,
        bit [ID_WIDTH-1:0] id,
        int unsigned timeout_cycles = 1000
    );
        virtual axi_if#(.ID_WIDTH(ID_WIDTH)) up_vif;
        bit done;

        up_vif = mst_idx == 0 ? vif_mst00 : vif_mst01;
        repeat (timeout_cycles) begin
            @(vif_mst00.monitor_cb);
            if (vif_mst00.arst) continue;

            if (txn_type == WRITE) begin
                if ((vif_slv00.monitor_cb.awvalid && vif_slv00.monitor_cb.awaddr >= 32'h0002_0000) ||
                    (vif_slv01.monitor_cb.awvalid && vif_slv01.monitor_cb.awaddr >= 32'h0002_0000) ||
                    vif_slv00.monitor_cb.wvalid || vif_slv01.monitor_cb.wvalid)
                    `uvm_error(get_type_name(), "high-QoS DECERR write leaked downstream")
                done = up_vif.monitor_cb.bvalid && up_vif.monitor_cb.bready &&
                       up_vif.monitor_cb.bid == id && up_vif.monitor_cb.bresp == DECERR;
            end else begin
                if ((vif_slv00.monitor_cb.arvalid && vif_slv00.monitor_cb.araddr >= 32'h0002_0000) ||
                    (vif_slv01.monitor_cb.arvalid && vif_slv01.monitor_cb.araddr >= 32'h0002_0000))
                    `uvm_error(get_type_name(), "high-QoS DECERR read leaked downstream")
                done = up_vif.monitor_cb.rvalid && up_vif.monitor_cb.rready &&
                       up_vif.monitor_cb.rid == id && up_vif.monitor_cb.rresp == DECERR &&
                       up_vif.monitor_cb.rlast;
            end
            if (done) return;
        end
        `uvm_error(get_type_name(), "high-QoS DECERR completion timeout")
    endtask

    local function bit [ADDR_WIDTH-1:0] slave_addr(
        int unsigned slv_idx,
        bit [ADDR_WIDTH-1:0] offset
    );
        return (slv_idx == 0 ? 32'h0000_0000 : 32'h0001_0000) + offset;
    endfunction
endclass

`endif
