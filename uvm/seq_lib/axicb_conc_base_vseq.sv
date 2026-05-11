`ifndef AXICB_CONC_BASE_VSEQ_SV
`define AXICB_CONC_BASE_VSEQ_SV

class axicb_conc_base_vseq extends axicb_base_vseq;

    `uvm_object_utils(axicb_conc_base_vseq)

    function new(string name = "axicb_conc_base_vseq");
        super.new(name);
    endfunction

    //different master send tr to same slave, check upstream AW channel concurrency
    protected task automatic expect_same_slave_aw_contention(
        input int unsigned slv_idx,
        input int unsigned timeout_cycles = 100,
        input int unsigned min_hit_cycles = 1
    );
        expect_same_slave_addr_contention(WRITE, slv_idx, timeout_cycles, min_hit_cycles);
    endtask

    //check upstream AR channel concurrency
    protected task automatic expect_same_slave_ar_contention(
        input int unsigned slv_idx,
        input int unsigned timeout_cycles = 100,
        input int unsigned min_hit_cycles = 1
    );
        expect_same_slave_addr_contention(READ, slv_idx, timeout_cycles, min_hit_cycles);
    endtask

    //check downstream W whether hold on for entire transaction cycles
    protected task automatic expect_downstream_w_burst_integrity(
        input int unsigned slv_idx,
        input int unsigned expected_bursts = 2,
        input int unsigned timeout_cycles = 1000
    );
        expect_downstream_burst_integrity(WRITE, slv_idx, expected_bursts, timeout_cycles);
    endtask

    protected task automatic expect_downstream_r_burst_integrity(
        input int unsigned slv_idx,
        input int unsigned expected_bursts = 2,
        input int unsigned timeout_cycles = 1000
    );
        expect_downstream_burst_integrity(READ, slv_idx, expected_bursts, timeout_cycles);
    endtask

    //check same-ID write cannot switch to another slave before the first response
    protected task automatic expect_same_id_diff_slave_aw_block(
        input int unsigned          mst_idx,
        input int unsigned          first_slv,
        input int unsigned          blocked_slv,
        input bit [ID_WIDTH-1:0]    exp_id,
        input int unsigned          timeout_cycles = 1000
    );
        expect_same_id_diff_slave_addr_block(WRITE, mst_idx, first_slv, blocked_slv, exp_id, timeout_cycles);
    endtask

    //check same-ID read cannot switch to another slave before the first response
    protected task automatic expect_same_id_diff_slave_ar_block(
        input int unsigned          mst_idx,
        input int unsigned          first_slv,
        input int unsigned          blocked_slv,
        input bit [ID_WIDTH-1:0]    exp_id,
        input int unsigned          timeout_cycles = 1000
    );
        expect_same_id_diff_slave_addr_block(READ, mst_idx, first_slv, blocked_slv, exp_id, timeout_cycles);
    endtask    

    //check two downstream B responses contend for the same upstream master
    protected task automatic expect_same_master_b_resp_contention(
        input int unsigned mst_idx,
        input int unsigned slv_a = 0,
        input int unsigned slv_b = 1,
        input int unsigned timeout_cycles = 1000,
        input int unsigned min_hit_cycles = 1
    );
        expect_same_master_resp_contention(WRITE, mst_idx, slv_a, slv_b, timeout_cycles, min_hit_cycles);
    endtask

    //check two downstream R responses contend for the same upstream master
    protected task automatic expect_same_master_r_resp_contention(
        input int unsigned mst_idx,
        input int unsigned slv_a = 0,
        input int unsigned slv_b = 1,
        input int unsigned timeout_cycles = 1000,
        input int unsigned min_hit_cycles = 1
    );
        expect_same_master_resp_contention(READ, mst_idx, slv_a, slv_b, timeout_cycles, min_hit_cycles);
    endtask

    //drain helper for testcase boundary, count upstream transaction completions
    protected task automatic wait_upstream_done(
        input int unsigned expected_write,
        input int unsigned expected_read,
        input int unsigned timeout_cycles = 5000
    );
        int unsigned write_done;
        int unsigned read_done;

        if (expected_write == 0 && expected_read == 0)
            `uvm_fatal(get_type_name(), "wait_upstream_done expects at least one completion")

        repeat (timeout_cycles) begin
            @(vif_mst00.monitor_cb);
            if (vif_mst00.arst) begin
                write_done = 0;
                read_done  = 0;
                continue;
            end

            if (vif_mst00.monitor_cb.bvalid && vif_mst00.monitor_cb.bready)
                write_done++;
            if (vif_mst01.monitor_cb.bvalid && vif_mst01.monitor_cb.bready)
                write_done++;

            if (vif_mst00.monitor_cb.rvalid && vif_mst00.monitor_cb.rready && vif_mst00.monitor_cb.rlast)
                read_done++;
            if (vif_mst01.monitor_cb.rvalid && vif_mst01.monitor_cb.rready && vif_mst01.monitor_cb.rlast)
                read_done++;

            if (write_done >= expected_write && read_done >= expected_read) begin
                `uvm_info(get_type_name(),
                          $sformatf("upstream done drained: write=%0d/%0d read=%0d/%0d",
                                    write_done, expected_write, read_done, expected_read),
                          UVM_LOW)
                return;
            end
        end

        `uvm_error(get_type_name(),
                   $sformatf("upstream done drain timeout: write=%0d/%0d read=%0d/%0d",
                             write_done, expected_write, read_done, expected_read))
    endtask

    protected function void set_slave_b_resp_delay(
        input int unsigned slv_idx,
        input int unsigned delay_cycles
    );
        if (p_sequencer == null)
            `uvm_fatal(get_type_name(), "p_sequencer is null")
        if (p_sequencer.cfg == null)
            `uvm_fatal(get_type_name(), "virtual sequencer cfg is null")
        if (slv_idx >= S_COUNT)
            `uvm_fatal(get_type_name(), $sformatf("invalid slave index: %0d", slv_idx))

        p_sequencer.cfg.slv_b_resp_delay_cycles[slv_idx] = delay_cycles;
        `uvm_info(get_type_name(),
                  $sformatf("set slv%0d B response delay to %0d cycle(s)",
                            slv_idx, delay_cycles),
                  UVM_LOW)
    endfunction

    protected function void clear_slave_b_resp_delay(input int unsigned slv_idx);
        set_slave_b_resp_delay(slv_idx, 0);
    endfunction

    protected function void clear_all_slave_b_resp_delay();
        for (int i = 0; i < S_COUNT; i++)
            set_slave_b_resp_delay(i, 0);
    endfunction

    protected function void set_slave_r_resp_delay(
        input int unsigned slv_idx,
        input int unsigned delay_cycles
    );
        if (p_sequencer == null)
            `uvm_fatal(get_type_name(), "p_sequencer is null")
        if (p_sequencer.cfg == null)
            `uvm_fatal(get_type_name(), "virtual sequencer cfg is null")
        if (slv_idx >= S_COUNT)
            `uvm_fatal(get_type_name(), $sformatf("invalid slave index: %0d", slv_idx))

        p_sequencer.cfg.slv_r_resp_delay_cycles[slv_idx] = delay_cycles;
        `uvm_info(get_type_name(),
                  $sformatf("set slv%0d R response delay to %0d cycle(s)",
                            slv_idx, delay_cycles),
                  UVM_LOW)
    endfunction

    protected function void clear_slave_r_resp_delay(input int unsigned slv_idx);
        set_slave_r_resp_delay(slv_idx, 0);
    endfunction

    protected function void clear_all_slave_r_resp_delay();
        for (int i = 0; i < S_COUNT; i++)
            set_slave_r_resp_delay(i, 0);
    endfunction
    
    //arbiter's Round-Robin check, check downstream whether appear the same count of each master's tr
    protected task automatic expect_downstream_rr_grant_fairness(
        input trans_type_enum txn_type,
        input int unsigned    slv_idx,
        input int unsigned    expected_per_master,
        input int unsigned    timeout_cycles = 1000
    );
        virtual axi_if#(.ID_WIDTH(M_ID_WIDTH)) vif_slv;
        int unsigned grant_cnt[2];
        int unsigned total_grants;
        int unsigned expected_total;
        bit hit;
        bit owner;
        string chan;

        if (expected_per_master == 0)
            `uvm_fatal(get_type_name(), "expected_per_master must be greater than 0")

        case (txn_type)
            WRITE: chan = "AW";
            READ:  chan = "AR";
            default: `uvm_fatal(get_type_name(), "unsupported transaction type for RR grant checker")
        endcase

        case (slv_idx)
            0: vif_slv = vif_slv00;
            1: vif_slv = vif_slv01;
            default: `uvm_fatal(get_type_name(), $sformatf("invalid slave index: %0d", slv_idx))
        endcase

        expected_total = expected_per_master * 2;

        repeat (timeout_cycles) begin
            @(vif_slv.monitor_cb);
            if (vif_slv.arst) begin
                grant_cnt[0] = 0;
                grant_cnt[1] = 0;
                total_grants = 0;
                continue;
            end

            hit = 0;
            case (txn_type)
                WRITE: begin
                    hit   = vif_slv.monitor_cb.awvalid && vif_slv.monitor_cb.awready;
                    owner = vif_slv.monitor_cb.awid[M_ID_WIDTH-1];
                end
                READ: begin
                    hit   = vif_slv.monitor_cb.arvalid && vif_slv.monitor_cb.arready;
                    owner = vif_slv.monitor_cb.arid[M_ID_WIDTH-1];
                end
            endcase

            if (hit) begin
                grant_cnt[int'(owner)]++;
                total_grants++;

                if (total_grants >= expected_total) begin
                    if (grant_cnt[0] != expected_per_master || grant_cnt[1] != expected_per_master) begin
                        `uvm_error(get_type_name(),
                                   $sformatf("downstream %s RR grant unfair on slv%0d: m0=%0d m1=%0d exp_each=%0d",
                                             chan, slv_idx, grant_cnt[0], grant_cnt[1], expected_per_master))
                    end else begin
                        `uvm_info(get_type_name(),
                                  $sformatf("downstream %s RR grant fair on slv%0d: m0=%0d m1=%0d",
                                            chan, slv_idx, grant_cnt[0], grant_cnt[1]),
                                  UVM_LOW)
                    end
                    return;
                end
            end
        end

        `uvm_error(get_type_name(),
                   $sformatf("downstream %s RR grant fairness not completed on slv%0d: m0=%0d m1=%0d exp_each=%0d",
                             chan, slv_idx, grant_cnt[0], grant_cnt[1], expected_per_master))
    endtask

    //check upstream accepted-but-not-completed(outstanding) transaction depth
    protected task automatic expect_upstream_outstanding_depth(
        input trans_type_enum txn_type,
        input int unsigned    mst_idx,
        input int unsigned    expected_depth,
        input int unsigned    timeout_cycles = 1000
    );
        virtual axi_if#(.ID_WIDTH(ID_WIDTH)) vif_mst;
        int unsigned curr_depth;
        int unsigned next_depth;
        int unsigned max_depth;
        bit start_hs;
        bit done_hs;
        string txn_name;

        if (expected_depth == 0)
            `uvm_fatal(get_type_name(), "expected_depth must be greater than 0")

        case (txn_type)
            WRITE: txn_name = "WRITE";
            READ:  txn_name = "READ";
            default: `uvm_fatal(get_type_name(), "unsupported transaction type for outstanding checker")
        endcase

        case (mst_idx)
            0: vif_mst = vif_mst00;
            1: vif_mst = vif_mst01;
            default: `uvm_fatal(get_type_name(), $sformatf("invalid master index: %0d", mst_idx))
        endcase

        repeat (timeout_cycles) begin
            @(vif_mst.monitor_cb);
            if (vif_mst.arst) begin
                curr_depth = 0;
                max_depth  = 0;
                continue;
            end

            case (txn_type)
                WRITE: begin
                    start_hs = vif_mst.monitor_cb.awvalid && vif_mst.monitor_cb.awready;
                    done_hs  = vif_mst.monitor_cb.bvalid  && vif_mst.monitor_cb.bready;
                end
                READ: begin
                    start_hs = vif_mst.monitor_cb.arvalid && vif_mst.monitor_cb.arready;
                    done_hs  = vif_mst.monitor_cb.rvalid  && vif_mst.monitor_cb.rready &&
                               vif_mst.monitor_cb.rlast;
                end
            endcase

            next_depth = curr_depth;
            if (start_hs)
                next_depth++;
            if (done_hs) begin
                if (next_depth == 0) begin
                    `uvm_error(get_type_name(),
                               $sformatf("master%0d %s completion observed before request",
                                         mst_idx, txn_name))
                    return;
                end
                next_depth--;
            end

            curr_depth = next_depth;
            if (curr_depth > max_depth)
                max_depth = curr_depth;

            if (max_depth >= expected_depth) begin
                `uvm_info(get_type_name(),
                          $sformatf("master%0d upstream %s outstanding depth reached %0d",
                                    mst_idx, txn_name, max_depth),
                          UVM_LOW)
                return;
            end
        end

        `uvm_error(get_type_name(),
                   $sformatf("master%0d upstream %s outstanding depth not reached: max=%0d exp=%0d",
                             mst_idx, txn_name, max_depth, expected_depth))
    endtask

    //check how many unique active IDs exist on one upstream port
    protected task automatic expect_upstream_unique_id_threads(
        input trans_type_enum txn_type,
        input int unsigned    mst_idx,
        input int unsigned    expected_threads = 2,
        input int unsigned    timeout_cycles = 1000
    );
        typedef bit [ID_WIDTH-1:0] id_t;
        virtual axi_if#(.ID_WIDTH(ID_WIDTH)) vif_mst;
        int unsigned active_count[id_t];
        int unsigned max_threads;
        bit start_hs;
        bit done_hs;
        id_t start_id;
        id_t done_id;
        string txn_name;

        if (expected_threads == 0)
            `uvm_fatal(get_type_name(), "expected_threads must be greater than 0")

        case (mst_idx)
            0: vif_mst = vif_mst00;
            1: vif_mst = vif_mst01;
            default: `uvm_fatal(get_type_name(), $sformatf("invalid master index: %0d", mst_idx))
        endcase

        case (txn_type)
            WRITE: txn_name = "WRITE";
            READ:  txn_name = "READ";
            default: `uvm_fatal(get_type_name(), "unsupported transaction type for unique ID thread checker")
        endcase

        repeat (timeout_cycles) begin
            @(vif_mst.monitor_cb);
            if (vif_mst.arst) begin
                active_count.delete();
                max_threads = 0;
                continue;
            end

            case (txn_type)
                WRITE: begin
                    start_hs = vif_mst.monitor_cb.awvalid && vif_mst.monitor_cb.awready;
                    done_hs  = vif_mst.monitor_cb.bvalid  && vif_mst.monitor_cb.bready;
                    start_id = vif_mst.monitor_cb.awid;
                    done_id  = vif_mst.monitor_cb.bid;
                end
                READ: begin
                    start_hs = vif_mst.monitor_cb.arvalid && vif_mst.monitor_cb.arready;
                    done_hs  = vif_mst.monitor_cb.rvalid  && vif_mst.monitor_cb.rready &&
                               vif_mst.monitor_cb.rlast;
                    start_id = vif_mst.monitor_cb.arid;
                    done_id  = vif_mst.monitor_cb.rid;
                end
            endcase

            if (start_hs)
                active_count[start_id]++;

            if (done_hs) begin
                if (!active_count.exists(done_id) || active_count[done_id] == 0) begin
                    `uvm_error(get_type_name(),
                               $sformatf("master%0d %s completion observed before tracked request: id=%0h",
                                         mst_idx, txn_name, done_id))
                    return;
                end
                active_count[done_id]--;
                if (active_count[done_id] == 0)
                    active_count.delete(done_id);
            end

            if (active_count.num() > max_threads)
                max_threads = active_count.num();

            if (max_threads >= expected_threads) begin
                `uvm_info(get_type_name(),
                          $sformatf("master%0d upstream %s unique ID threads reached %0d",
                                    mst_idx, txn_name, max_threads),
                          UVM_LOW)
                return;
            end
        end

        `uvm_error(get_type_name(),
                   $sformatf("master%0d upstream %s unique ID threads not reached: max=%0d exp=%0d",
                             mst_idx, txn_name, max_threads, expected_threads))
    endtask

    local task automatic expect_same_id_diff_slave_addr_block(
        input trans_type_enum       txn_type,
        input int unsigned          mst_idx,
        input int unsigned          first_slv,
        input int unsigned          blocked_slv,
        input bit [ID_WIDTH-1:0]    exp_id,
        input int unsigned          timeout_cycles = 1000
    );
        virtual axi_if#(.ID_WIDTH(ID_WIDTH)) vif_mst;
        bit first_active;
        bit blocked_seen;
        bit addr_hs;
        bit done_hs;
        bit first_req;
        bit blocked_req;
        string addr_chan;
        string resp_chan;

        if (first_slv >= S_COUNT || blocked_slv >= S_COUNT)
            `uvm_fatal(get_type_name(), $sformatf("invalid slave index: first=%0d blocked=%0d", first_slv, blocked_slv))
        if (first_slv == blocked_slv)
            `uvm_fatal(get_type_name(), "first_slv and blocked_slv must be different")

        case (mst_idx)
            0: vif_mst = vif_mst00;
            1: vif_mst = vif_mst01;
            default: `uvm_fatal(get_type_name(), $sformatf("invalid master index: %0d", mst_idx))
        endcase

        case (txn_type)
            WRITE: begin
                addr_chan = "AW";
                resp_chan = "B";
            end
            READ: begin
                addr_chan = "AR";
                resp_chan = "R";
            end
            default: `uvm_fatal(get_type_name(), "unsupported transaction type for same-ID different-slave block checker")
        endcase

        repeat (timeout_cycles) begin
            @(vif_mst.monitor_cb);
            if (vif_mst.arst) begin
                first_active = 0;
                blocked_seen = 0;
                continue;
            end

            case (txn_type)
                WRITE: begin
                    addr_hs = vif_mst.monitor_cb.awvalid && vif_mst.monitor_cb.awready;
                    done_hs = vif_mst.monitor_cb.bvalid  && vif_mst.monitor_cb.bready &&
                              (vif_mst.monitor_cb.bid == exp_id);

                    first_req = vif_mst.monitor_cb.awvalid &&
                                (vif_mst.monitor_cb.awid == exp_id) &&
                                (decode_slave(vif_mst.monitor_cb.awaddr) == int'(first_slv));
                    blocked_req = vif_mst.monitor_cb.awvalid &&
                                  (vif_mst.monitor_cb.awid == exp_id) &&
                                  (decode_slave(vif_mst.monitor_cb.awaddr) == int'(blocked_slv));
                end
                READ: begin
                    addr_hs = vif_mst.monitor_cb.arvalid && vif_mst.monitor_cb.arready;
                    done_hs = vif_mst.monitor_cb.rvalid  && vif_mst.monitor_cb.rready &&
                              vif_mst.monitor_cb.rlast &&
                              (vif_mst.monitor_cb.rid == exp_id);

                    first_req = vif_mst.monitor_cb.arvalid &&
                                (vif_mst.monitor_cb.arid == exp_id) &&
                                (decode_slave(vif_mst.monitor_cb.araddr) == int'(first_slv));
                    blocked_req = vif_mst.monitor_cb.arvalid &&
                                  (vif_mst.monitor_cb.arid == exp_id) &&
                                  (decode_slave(vif_mst.monitor_cb.araddr) == int'(blocked_slv));
                end
            endcase

            if (!first_active) begin
                if (first_req && addr_hs)
                    first_active = 1;
                continue;
            end

            if (blocked_req) begin
                blocked_seen = 1;
                if (addr_hs) begin
                    `uvm_error(get_type_name(),
                               $sformatf("master%0d same-ID different-slave %s accepted before %s response: id=%0h first_slv=%0d blocked_slv=%0d",
                                         mst_idx, addr_chan, resp_chan, exp_id, first_slv, blocked_slv))
                    return;
                end
            end

            if (done_hs) begin
                if (!blocked_seen) begin
                    `uvm_error(get_type_name(),
                               $sformatf("master%0d same-ID different-slave %s block window not observed before %s response: id=%0h",
                                         mst_idx, addr_chan, resp_chan, exp_id))
                    return;
                end
                `uvm_info(get_type_name(),
                          $sformatf("master%0d same-ID different-slave %s blocked until %s response: id=%0h first_slv=%0d blocked_slv=%0d",
                                    mst_idx, addr_chan, resp_chan, exp_id, first_slv, blocked_slv),
                          UVM_LOW)
                return;
            end
        end

        `uvm_error(get_type_name(),
                   $sformatf("master%0d same-ID different-slave %s block check timeout: id=%0h first_active=%0b blocked_seen=%0b",
                             mst_idx, addr_chan, exp_id, first_active, blocked_seen))
    endtask

    local task automatic expect_same_master_resp_contention(
        input trans_type_enum txn_type,
        input int unsigned    mst_idx,
        input int unsigned    slv_a,
        input int unsigned    slv_b,
        input int unsigned    timeout_cycles = 1000,
        input int unsigned    min_hit_cycles = 1
    );
        virtual axi_if#(.ID_WIDTH(M_ID_WIDTH)) vif_a;
        virtual axi_if#(.ID_WIDTH(M_ID_WIDTH)) vif_b;
        int unsigned hit_cycles;
        bit a_req;
        bit b_req;
        string chan;

        if (mst_idx >= S_COUNT)
            `uvm_fatal(get_type_name(), $sformatf("invalid master index: %0d", mst_idx))
        if (slv_a >= S_COUNT || slv_b >= S_COUNT)
            `uvm_fatal(get_type_name(), $sformatf("invalid slave index: slv_a=%0d slv_b=%0d", slv_a, slv_b))
        if (slv_a == slv_b)
            `uvm_fatal(get_type_name(), "slv_a and slv_b must be different")
        if (min_hit_cycles == 0)
            `uvm_fatal(get_type_name(), "min_hit_cycles must be greater than 0")

        case (txn_type)
            WRITE: chan = "B";
            READ:  chan = "R";
            default: `uvm_fatal(get_type_name(), "unsupported transaction type for response contention checker")
        endcase

        case (slv_a)
            0: vif_a = vif_slv00;
            1: vif_a = vif_slv01;
            default: `uvm_fatal(get_type_name(), $sformatf("invalid slave index: %0d", slv_a))
        endcase

        case (slv_b)
            0: vif_b = vif_slv00;
            1: vif_b = vif_slv01;
            default: `uvm_fatal(get_type_name(), $sformatf("invalid slave index: %0d", slv_b))
        endcase

        repeat (timeout_cycles) begin
            @(vif_a.monitor_cb);
            if (vif_a.arst || vif_b.arst) begin
                hit_cycles = 0;
                continue;
            end

            case (txn_type)
                WRITE: begin
                    a_req = vif_a.monitor_cb.bvalid &&
                            (int'(vif_a.monitor_cb.bid[M_ID_WIDTH-1]) == mst_idx);
                    b_req = vif_b.monitor_cb.bvalid &&
                            (int'(vif_b.monitor_cb.bid[M_ID_WIDTH-1]) == mst_idx);
                end
                READ: begin
                    a_req = vif_a.monitor_cb.rvalid &&
                            (int'(vif_a.monitor_cb.rid[M_ID_WIDTH-1]) == mst_idx);
                    b_req = vif_b.monitor_cb.rvalid &&
                            (int'(vif_b.monitor_cb.rid[M_ID_WIDTH-1]) == mst_idx);
                end
            endcase

            if (a_req && b_req) begin
                hit_cycles++;
                if (hit_cycles >= min_hit_cycles) begin
                    `uvm_info(get_type_name(),
                              $sformatf("same-master %s response contention observed: master%0d slv%0d/slv%0d for %0d cycle(s)",
                                        chan, mst_idx, slv_a, slv_b, hit_cycles),
                              UVM_LOW)
                    return;
                end
            end
        end

        `uvm_error(get_type_name(),
                   $sformatf("same-master %s response contention not observed: master%0d slv%0d/slv%0d within %0d cycles",
                             chan, mst_idx, slv_a, slv_b, timeout_cycles))
    endtask

    local task automatic expect_same_slave_addr_contention(
        input trans_type_enum txn_type,
        input int unsigned    expected_slv,
        input int unsigned    timeout_cycles = 100,
        input int unsigned    min_hit_cycles = 1
    );
        int unsigned hit_cycles;
        bit m0_req;
        bit m1_req;
        string chan;

        if (expected_slv > 1)
            `uvm_fatal(get_type_name(), $sformatf("invalid slave index: %0d", expected_slv))

        case (txn_type)
            WRITE: chan = "AW";
            READ:  chan = "AR";
            default: `uvm_fatal(get_type_name(), "unsupported transaction type for address contention checker")
        endcase

        repeat (timeout_cycles) begin
            @(vif_mst00.monitor_cb);
            if (vif_mst00.arst)
                continue;

            case (txn_type)
                WRITE: begin
                    m0_req = vif_mst00.monitor_cb.awvalid &&
                             (decode_slave(vif_mst00.monitor_cb.awaddr) == int'(expected_slv));
                    m1_req = vif_mst01.monitor_cb.awvalid &&
                             (decode_slave(vif_mst01.monitor_cb.awaddr) == int'(expected_slv));
                end
                READ: begin
                    m0_req = vif_mst00.monitor_cb.arvalid &&
                             (decode_slave(vif_mst00.monitor_cb.araddr) == int'(expected_slv));
                    m1_req = vif_mst01.monitor_cb.arvalid &&
                             (decode_slave(vif_mst01.monitor_cb.araddr) == int'(expected_slv));
                end
            endcase

            if (m0_req && m1_req) begin
                hit_cycles++;
                if (hit_cycles >= min_hit_cycles) begin
                    `uvm_info(get_type_name(),
                              $sformatf("same-slave %s contention observed on slv%0d for %0d cycle(s)",
                                        chan, expected_slv, hit_cycles),
                              UVM_LOW)
                    return;
                end
            end
        end
        //timeout error
        `uvm_error(get_type_name(),
                   $sformatf("same-slave %s contention not observed on slv%0d within %0d cycles",
                             chan, expected_slv, timeout_cycles))
    endtask

    local task automatic expect_downstream_burst_integrity(
        input trans_type_enum txn_type,
        input int unsigned    slv_idx,
        input int unsigned    expected_bursts = 2,
        input int unsigned    timeout_cycles = 1000
    );
        virtual axi_if#(.ID_WIDTH(M_ID_WIDTH)) vif_slv;
        int unsigned beat_q[$];
        int unsigned exp_beats;
        int unsigned beat_idx;
        int unsigned checked_bursts;
        bit active;
        bit addr_hs;
        bit data_hs;
        bit last;
        string addr_chan;
        string data_chan;
        string last_name;

        if (expected_bursts == 0)
            `uvm_fatal(get_type_name(), "expected_bursts must be greater than 0")

        case (txn_type)
            WRITE: begin
                addr_chan = "AW";
                data_chan = "W";
                last_name = "WLAST";
            end
            READ: begin
                addr_chan = "AR";
                data_chan = "R";
                last_name = "RLAST";
            end
            default: `uvm_fatal(get_type_name(), "unsupported transaction type for burst integrity checker")
        endcase

        case (slv_idx)
            0: vif_slv = vif_slv00;
            1: vif_slv = vif_slv01;
            default: `uvm_fatal(get_type_name(), $sformatf("invalid slave index: %0d", slv_idx))
        endcase

        repeat (timeout_cycles) begin
            @(vif_slv.monitor_cb);
            if (vif_slv.arst) begin
                beat_q.delete();
                active = 0;
                beat_idx = 0;
                continue;
            end

            case (txn_type)
                WRITE: begin
                    addr_hs = vif_slv.monitor_cb.awvalid && vif_slv.monitor_cb.awready;
                    data_hs = vif_slv.monitor_cb.wvalid  && vif_slv.monitor_cb.wready;
                    last    = vif_slv.monitor_cb.wlast;
                    if (addr_hs)
                        beat_q.push_back(int'(vif_slv.monitor_cb.awlen) + 1);
                end
                READ: begin
                    addr_hs = vif_slv.monitor_cb.arvalid && vif_slv.monitor_cb.arready;
                    data_hs = vif_slv.monitor_cb.rvalid  && vif_slv.monitor_cb.rready;
                    last    = vif_slv.monitor_cb.rlast;
                    if (addr_hs)
                        beat_q.push_back(int'(vif_slv.monitor_cb.arlen) + 1);
                end
            endcase

            if (data_hs) begin
                if (!active) begin
                    if (beat_q.size() == 0) begin
                        `uvm_error(get_type_name(),
                                   $sformatf("slv%0d %s beat observed before downstream %s",
                                             slv_idx, data_chan, addr_chan))
                        return;
                    end
                    exp_beats = beat_q.pop_front();
                    beat_idx = 0;
                    active = 1;
                end

                if (beat_idx < exp_beats - 1 && last) begin
                    `uvm_error(get_type_name(),
                               $sformatf("slv%0d %s early: beat=%0d exp_last=%0d",
                                         slv_idx, last_name, beat_idx, exp_beats - 1))
                    return;
                end

                if (beat_idx == exp_beats - 1) begin
                    if (!last) begin
                        `uvm_error(get_type_name(),
                                   $sformatf("slv%0d %s missing on beat=%0d",
                                             slv_idx, last_name, beat_idx))
                        return;
                    end
                    checked_bursts++;
                    active = 0;
                    if (checked_bursts >= expected_bursts) begin
                        `uvm_info(get_type_name(),
                                  $sformatf("downstream %s burst integrity observed on slv%0d for %0d burst(s)",
                                            data_chan, slv_idx, checked_bursts),
                                  UVM_LOW)
                        return;
                    end
                end

                beat_idx++;
            end
        end
        //timeout error
        `uvm_error(get_type_name(),
                   $sformatf("downstream %s burst integrity not completed on slv%0d: checked=%0d exp=%0d",
                             data_chan, slv_idx, checked_bursts, expected_bursts))
    endtask

    //return which slave with addr
    local function int decode_slave(bit [ADDR_WIDTH - 1:0] addr);
        if (addr inside {[32'h0000_0000:32'h0000_FFFF]})
            return 0;
        if (addr inside {[32'h0001_0000:32'h0001_FFFF]})
            return 1;
        return -1;
    endfunction

endclass

`endif 
