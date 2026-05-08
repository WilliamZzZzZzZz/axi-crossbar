`ifndef AXICB_CONC_BASE_VSEQ_SV
`define AXICB_CONC_BASE_VSEQ_SV

class axicb_conc_base_vseq extends axicb_base_vseq;

    `uvm_object_utils(axicb_conc_base_vseq)

    function new(string name = "axicb_conc_base_vseq");
        super.new(name);
    endfunction

    //different master send tr to same slave, check upstream AW channel concurrency
    protected task automatic expect_same_slave_aw_contention(
        input int unsigned expected_slv,
        input int unsigned timeout_cycles = 100,
        input int unsigned min_hit_cycles = 1
    );
        expect_same_slave_addr_contention(WRITE, expected_slv, timeout_cycles, min_hit_cycles);
    endtask

    //check upstream AR channel concurrency
    protected task automatic expect_same_slave_ar_contention(
        input int unsigned expected_slv,
        input int unsigned timeout_cycles = 100,
        input int unsigned min_hit_cycles = 1
    );
        expect_same_slave_addr_contention(READ, expected_slv, timeout_cycles, min_hit_cycles);
    endtask

    protected task automatic expect_same_slave_addr_contention(
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

    protected task automatic expect_downstream_burst_integrity(
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
