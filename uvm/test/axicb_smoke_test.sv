`ifndef AXICB_SMOKE_TEST_SV
`define AXICB_SMOKE_TEST_SV

class axicb_smoke_test extends axicb_base_test;

    `uvm_component_utils(axicb_smoke_test)

    function new(string name = "axicb_smoke_test", uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
    endfunction

    task run_phase(uvm_phase phase);
        axicb_smoke_virtual_sequence seq = axicb_smoke_virtual_sequence::type_id::create("seq");
        super.run_phase(phase);

        phase.raise_objection(this);
        if(!seq.randomize()) `uvm_fatal(get_type_name(), "sequence randomization failed!")
        seq.start(env.virt_sqr);
        phase.drop_objection(this);
    endtask

endclass

`endif 