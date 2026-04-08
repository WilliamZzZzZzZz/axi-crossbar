`ifndef AXIRAM_CROSSBAR_SMOKE_TEST_SV
`define AXIRAM_CROSSBAR_SMOKE_TEST_SV

class axiram_crossbar_smoke_test extends axiram_base_test;
    `uvm_component_utils(axiram_crossbar_smoke_test)

    function new(string name = "axiram_crossbar_smoke_test", uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        axiram_crossbar_smoke_virtual_sequence seq;
        super.run_phase(phase);

        seq = axiram_crossbar_smoke_virtual_sequence::type_id::create("seq");
        phase.raise_objection(this);
        seq.start(env.virt_sqr);
        phase.drop_objection(this);
    endtask

endclass

`endif
