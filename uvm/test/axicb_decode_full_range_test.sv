`ifndef AXICB_DECODE_FULL_RANGE_TEST_SV
`define AXICB_DECODE_FULL_RANGE_TEST_SV

class axicb_decode_full_range_test extends axicb_base_test;

    `uvm_component_utils(axicb_decode_full_range_test)

    function new(string name = "axicb_decode_full_range_test", uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
    endfunction

    task run_phase(uvm_phase phase);
        axicb_decode_full_range_vseq seq = axicb_decode_full_range_vseq::type_id::create("seq");
        super.run_phase(phase);

        phase.raise_objection(this);
        if(!seq.randomize()) `uvm_fatal(get_type_name(), "sequence randomization failed!")
        seq.start(env.virt_sqr);
        phase.drop_objection(this);
    endtask

    function void report_phase(uvm_phase phase);
        uvm_report_server srv = uvm_report_server::get_server();
        super.report_phase(phase);
        //CHECK_SCOREBOARD
        if(env.scb.check_count == 0)
            `uvm_error(get_type_name(), "ATTENTION: scoreboard check 0 transaction!")
        //summary of entire test
        if(srv.get_severity_count(UVM_ERROR) > 0)
            `uvm_info(get_type_name(), $sformatf(
                "======= DECODE FULL RANGE TEST FAILED ======= (%0d errors)", srv.get_severity_count(UVM_ERROR)), UVM_NONE)
        else
            `uvm_info(get_type_name(), "======= DECODE FULL RANGE TEST PASSED ======= ", UVM_NONE)
    endfunction

endclass

`endif 