`ifndef AXICB_CONC_BASE_VSEQ_SV
`define AXICB_CONC_BASE_VSEQ_SV

class axicb_conc_base_vseq extends axicb_base_vseq;

    `uvm_object_utils(axicb_conc_base_vseq)

    function new(string name = "axicb_conc_base_vseq");
        super.new(name);
    endfunction

    protected task automatic expect_same_slave_aw_contention(
        input int unsigned expected_slv,
        input int unsigned timeout_cycles = 100,
        input int unsigned min_hit_cycles = 1
    );
        int unsigned hit_cycles;
        bit m0_req;
        bit m1_req;

        if (expected_slv > 1)
            `uvm_fatal(get_type_name(), $sformatf("invalid slave index: %0d", expected_slv))

        repeat (timeout_cycles) begin
            @(vif_mst00.monitor_cb);
            if (vif_mst00.arst)
                continue;

            m0_req = vif_mst00.monitor_cb.awvalid &&
                     (decode_slave(vif_mst00.monitor_cb.awaddr) == int'(expected_slv));
            m1_req = vif_mst01.monitor_cb.awvalid &&
                     (decode_slave(vif_mst01.monitor_cb.awaddr) == int'(expected_slv));

            if (m0_req && m1_req) begin
                hit_cycles++;
                if (hit_cycles >= min_hit_cycles) begin
                    `uvm_info(get_type_name(),
                              $sformatf("same-slave AW contention observed on slv%0d for %0d cycle(s)",
                                        expected_slv, hit_cycles),
                              UVM_LOW)
                    return;
                end
            end
        end
        //timeout error
        `uvm_error(get_type_name(),
                   $sformatf("same-slave AW contention not observed on slv%0d within %0d cycles",
                             expected_slv, timeout_cycles))
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
