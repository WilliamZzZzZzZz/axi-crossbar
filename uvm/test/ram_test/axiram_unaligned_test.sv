`ifndef AXIRAM_UNALIGNED_TEST_SV
`define AXIRAM_UNALIGNED_TEST_SV

class axiram_unaligned_test extends axiram_base_test;

    `uvm_component_utils(axiram_unaligned_test)

    function new(string name = "axiram_unaligned_test", uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
    endfunction

    task run_phase(uvm_phase phase);
        axiram_unaligned_virtual_sequence seq = axiram_unaligned_virtual_sequence::type_id::create("seq");
        super.run_phase(phase);
        phase.raise_objection(this);
        seq.start(env.virt_sqr);
        phase.drop_objection(this);
    endtask

endclass

`endif 