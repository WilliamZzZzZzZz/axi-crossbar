`ifndef AXICB_BASE_VIRTUAL_SEQUENCE_SV
`define AXICB_BASE_VIRTUAL_SEQUENCE_SV

class axicb_base_virtual_sequence extends uvm_sequence;
    `uvm_object_utils(axicb_base_virtual_sequence)

    
    bit [31:0] wr_val[]; 
    bit [31:0] rd_val[];
    axi_configuration cfg;

    axicb_single_write_sequence single_write;
    axicb_single_read_sequence single_read;

    virtual axi_if#(.ID_WIDTH(ID_WIDTH)) vif_mst00;
    virtual axi_if#(.ID_WIDTH(ID_WIDTH)) vif_mst01;
    virtual axi_if#(.ID_WIDTH(ID_WIDTH)) vif;       //default

    `uvm_declare_p_sequencer(axicb_virtual_sequencer)

    function new(string name = "axicb_base_virtual_sequence");
        super.new(name);
    endfunction

    virtual task body();
        `uvm_info(get_type_name(), "entering...", UVM_LOW)

        if(p_sequencer == null)
            `uvm_fatal(get_type_name(), "p_sequencer is null")
        if(p_sequencer.axi_mst_sqr00 == null || p_sequencer.axi_mst_sqr01 == null)
            `uvm_fatal(get_type_name(), "master sequencer handles are null in virtual sequencer")

        vif_mst00 = p_sequencer.axi_mst_sqr00.vif;
        vif_mst01 = p_sequencer.axi_mst_sqr01.vif;
        vif       = vif_mst00;                      //default
        cfg       = (p_sequencer.cfg != null) ? p_sequencer.cfg : p_sequencer.axi_mst_sqr00.cfg;
        if(vif_mst00 == null || vif_mst01 == null)
            `uvm_fatal(get_type_name(), "failed to get vif from master sequencers")
        if(cfg == null)
            `uvm_fatal(get_type_name(), "failed to get cfg from virtual/master sequencer")

        `uvm_info(get_type_name(), "exiting...", UVM_LOW)
    endtask

    virtual function bit compare_single_data(bit[31:0] val1, bit[31:0] val2);
        if(val1 === val2) begin
            return 1;
            `uvm_info("CMP-SUCCESS", $sformatf("val1 'h%0x === val2 'h%0x", val1, val2), UVM_LOW)
        end
        else begin
            return 0;
            `uvm_error("CMP-ERROR", $sformatf("val1 'h%0x === val2 'h%0x", val1, val2))
        end
    endfunction  

    virtual function void compare_data(bit[31:0] wr[], bit[31:0] rd[]);
        if(wr.size() != rd.size()) begin
            `uvm_error("CMP-SIZE", $sformatf("wr size(%0d) != rd size(%0d)", 
                        wr.size(), rd.size()))
            return;
        end
        foreach(wr[i]) begin
            if(wr[i] === rd[i])
                `uvm_info("CMP-PASS", $sformatf("beat[%0d] MATCH: wr=0x%08x rd=0x%08x", 
                        i, wr[i], rd[i]), UVM_LOW)
            else
                `uvm_error("CMP-FAIL", $sformatf("beat[%0d] MISMATCH: wr=0x%08x rd=0x%08x", 
                        i, wr[i], rd[i]))
        end
    endfunction

    task wait_cycles(int n);
        repeat(n) @(posedge vif.aclk);
    endtask

    protected function int unsigned get_reset_timeout_cycles();
        if(cfg != null && cfg.reset_deassert_timeout_cycles > 0) begin
            return cfg.reset_deassert_timeout_cycles;
        end
        return 128;
    endfunction

    protected function int unsigned get_sequence_timeout_cycles();
        if(cfg != null && cfg.sequence_timeout_cycles > 0) begin
            return cfg.sequence_timeout_cycles;
        end
        return 4000;
    endfunction

    protected function virtual axi_if#(.ID_WIDTH(ID_WIDTH)) get_master_vif(int unsigned idx);
        case(idx)
            0: return vif_mst00;
            1: return vif_mst01;
            default: begin
                `uvm_fatal(get_type_name(), $sformatf("invalid master index for vif lookup: %0d", idx))
            end
        endcase
    endfunction

    protected task wait_reset_release_or_timeout(
        input virtual axi_if#(.ID_WIDTH(ID_WIDTH)) vif_handle,
        input string timeout_context
    );
        bit released = 0;
        int unsigned timeout_cycles;

        if(vif_handle == null) begin
            `uvm_fatal(get_type_name(), $sformatf(
                "null vif while waiting reset release: %s", timeout_context))
        end

        timeout_cycles = get_reset_timeout_cycles();

        fork
            begin
                if(vif_handle.arst === 1'b0) begin
                    released = 1;
                end
                else begin
                    @(negedge vif_handle.arst);
                    released = 1;
                end
            end
            begin
                repeat(timeout_cycles) @(posedge vif_handle.aclk);
            end
        join_any
        disable fork;

        if(!released) begin
            `uvm_fatal(get_type_name(), $sformatf(
                "reset deassert timeout after %0d cycles: %s",
                timeout_cycles, timeout_context))
        end
    endtask

    protected task start_subsequence_or_timeout(
        input uvm_sequence_base seq_h,
        input uvm_sequencer_base sqr_h,
        input virtual axi_if#(.ID_WIDTH(ID_WIDTH)) clk_vif,
        input string timeout_context
    );
        bit seq_done = 0;
        int unsigned timeout_cycles;

        if(seq_h == null || sqr_h == null || clk_vif == null) begin
            `uvm_fatal(get_type_name(), $sformatf(
                "invalid handles when starting subsequence: %s", timeout_context))
        end

        timeout_cycles = get_sequence_timeout_cycles();

        fork
            begin
                seq_h.start(sqr_h);
                seq_done = 1;
            end
            begin
                repeat(timeout_cycles) @(posedge clk_vif.aclk);
            end
        join_any
        disable fork;

        if(!seq_done) begin
            `uvm_fatal(get_type_name(), $sformatf(
                "subsequence timeout after %0d cycles: %s",
                timeout_cycles, timeout_context))
        end
    endtask
endclass

`endif 
