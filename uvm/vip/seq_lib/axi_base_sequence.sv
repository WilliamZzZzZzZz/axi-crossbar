`ifndef AXI_BASE_SEQUENCE_SV
`define AXI_BASE_SEQUENCE_SV

class axi_base_sequence extends uvm_sequence #(axi_transaction);
    `uvm_object_utils(axi_base_sequence)
    `uvm_declare_p_sequencer(axi_master_sequencer)

    function new(string name = "axi_base_sequence");
        super.new(name);
    endfunction

    protected function int unsigned get_sequence_timeout_cycles();
        if(p_sequencer != null && p_sequencer.cfg != null &&
           p_sequencer.cfg.sequence_timeout_cycles > 0) begin
            return p_sequencer.cfg.sequence_timeout_cycles;
        end
        return 4000;
    endfunction

    protected task start_item_or_timeout(
        input axi_transaction item,
        input string timeout_context
    );
        bit start_done = 0;
        int unsigned timeout_cycles;

        if(p_sequencer == null || p_sequencer.vif == null) begin
            `uvm_fatal(get_type_name(), $sformatf(
                "cannot start item without sequencer/vif: %s", timeout_context))
        end

        timeout_cycles = get_sequence_timeout_cycles();

        fork
            begin
                start_item(item);
                start_done = 1;
            end
            begin
                repeat(timeout_cycles) @(posedge p_sequencer.vif.aclk);
            end
        join_any
        disable fork;

        if(!start_done) begin
            `uvm_fatal(get_type_name(), $sformatf(
                "sequence start_item timeout after %0d cycles: %s",
                timeout_cycles, timeout_context))
        end
    endtask

    protected task finish_item_or_timeout(
        input axi_transaction item,
        input string timeout_context
    );
        bit finish_done = 0;
        int unsigned timeout_cycles;

        if(p_sequencer == null || p_sequencer.vif == null) begin
            `uvm_fatal(get_type_name(), $sformatf(
                "cannot finish item without sequencer/vif: %s", timeout_context))
        end

        timeout_cycles = get_sequence_timeout_cycles();

        fork
            begin
                finish_item(item);
                finish_done = 1;
            end
            begin
                repeat(timeout_cycles) @(posedge p_sequencer.vif.aclk);
            end
        join_any
        disable fork;

        if(!finish_done) begin
            `uvm_fatal(get_type_name(), $sformatf(
                "sequence finish_item timeout after %0d cycles: %s",
                timeout_cycles, timeout_context))
        end
    endtask

    protected task get_response_or_timeout(
        output axi_transaction rsp,
        input string timeout_context
    );
        bit rsp_done = 0;
        int unsigned timeout_cycles;

        if(p_sequencer == null || p_sequencer.vif == null) begin
            `uvm_fatal(get_type_name(), $sformatf(
                "cannot get response without sequencer/vif: %s", timeout_context))
        end

        timeout_cycles = get_sequence_timeout_cycles();

        fork
            begin
                get_response(rsp);
                rsp_done = 1;
            end
            begin
                repeat(timeout_cycles) @(posedge p_sequencer.vif.aclk);
            end
        join_any
        disable fork;

        if(!rsp_done) begin
            `uvm_fatal(get_type_name(), $sformatf(
                "sequence get_response timeout after %0d cycles: %s",
                timeout_cycles, timeout_context))
        end
    endtask
    
endclass

`endif 
