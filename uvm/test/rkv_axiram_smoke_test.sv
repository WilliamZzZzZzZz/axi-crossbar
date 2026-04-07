`ifndef RKV_AXIRAM_SMOKE_TEST_SV
`define RKV_AXIRAM_SMOKE_TEST_SV

class rkv_axiram_smoke_test extends rkv_axiram_base_test;

  `uvm_component_utils(rkv_axiram_smoke_test)

  function new(string name = "rkv_axiram_smoke_test", uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  task run_phase(uvm_phase phase);
    rkv_axiram_smoke_virt_seq seq = rkv_axiram_smoke_virt_seq::type_id::create("seq");
    super.run_phase(phase);
    phase.raise_objection(this);
    seq.start(env.virt_sqr);
    phase.drop_objection(this);
  endtask

endclass

`endif // RKV_AXIRAM_SMOKE_TEST_SV
