`ifndef AXICB_QOS_ARB_TEST_SV
`define AXICB_QOS_ARB_TEST_SV

class axicb_qos_arb_test extends axicb_base_test;
    `uvm_component_utils(axicb_qos_arb_test)

    function new(string name = "axicb_qos_arb_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        axicb_qos_arb_vseq seq = axicb_qos_arb_vseq::type_id::create("seq");
        super.run_phase(phase);
        phase.raise_objection(this);
        if (!seq.randomize())
            `uvm_fatal(get_type_name(), "sequence randomization failed")
        seq.start(env.virt_sqr);
        phase.drop_objection(this);
    endtask

    function void report_phase(uvm_phase phase);
        uvm_report_server srv = uvm_report_server::get_server();
        super.report_phase(phase);
        if (env.scb.check_count == 0)
            `uvm_error(get_type_name(), "ATTENTION: scoreboard checked 0 channel events")
        if (srv.get_severity_count(UVM_ERROR) > 0 || srv.get_severity_count(UVM_FATAL) > 0)
            `uvm_info(get_type_name(), $sformatf(
                "======= QOS ARB TEST FAILED ======= (%0d errors, %0d fatals)",
                srv.get_severity_count(UVM_ERROR), srv.get_severity_count(UVM_FATAL)), UVM_NONE)
        else
            `uvm_info(get_type_name(), "======= QOS ARB TEST PASSED =======", UVM_NONE)
    endfunction
endclass

`endif
