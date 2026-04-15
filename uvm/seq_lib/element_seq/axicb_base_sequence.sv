`ifndef AXICB_BASE_SEQUENCE_SV
`define AXICB_BASE_SEQUENCE_SV

class axicb_base_sequence extends uvm_sequence;
    `uvm_object_utils(axicb_base_sequence)
    bit[31:0] wr_val, rd_val;

    `uvm_declare_p_sequencer(axicb_virtual_sequencer)

    rand int unsigned src_master_idx;
    constraint src_master_idx_c { src_master_idx inside {0, 1}; }

    function new(string name = "axicb_base_sequence");
        super.new(name);
    endfunction

    protected function int unsigned get_master_sequence_timeout_cycles(axi_master_sequencer sqr_h);
        if(sqr_h != null && sqr_h.cfg != null && sqr_h.cfg.sequence_timeout_cycles > 0) begin
            return sqr_h.cfg.sequence_timeout_cycles;
        end
        return 4000;
    endfunction

    protected task start_master_subsequence_or_timeout(
        input uvm_sequence_base seq_h,
        input axi_master_sequencer sqr_h,
        input string timeout_context
    );
        bit seq_done = 0;
        int unsigned timeout_cycles;

        if(seq_h == null || sqr_h == null || sqr_h.vif == null) begin
            `uvm_fatal(get_type_name(), $sformatf(
                "invalid handles when starting master subsequence: %s", timeout_context))
        end

        timeout_cycles = get_master_sequence_timeout_cycles(sqr_h);

        fork
            begin
                seq_h.start(sqr_h);
                seq_done = 1;
            end
            begin
                repeat(timeout_cycles) @(posedge sqr_h.vif.aclk);
            end
        join_any
        disable fork;

        if(!seq_done) begin
            `uvm_fatal(get_type_name(), $sformatf(
                "master subsequence timeout after %0d cycles: %s",
                timeout_cycles, timeout_context))
        end
    endtask

    virtual task body();
        `uvm_info(get_type_name(), "entering...", UVM_LOW)

        `uvm_info(get_type_name(), "exiting...", UVM_LOW)
    endtask
endclass

`endif 
