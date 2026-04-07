`ifndef AXIRAM_BASE_TEST_SV
`define AXIRAM_BASE_TEST_SV

class axiram_base_test extends uvm_test;

    `uvm_component_utils(axiram_base_test)
    axiram_env env;

    function new(string name = "axiram_base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = axiram_env::type_id::create("env", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

    endfunction

    task run_phase(uvm_phase phase);
        super.run_phase(phase);
        //after all run phase done, wait 1us for monitor and coverage collecting full data
        phase.phase_done.set_drain_time(this, 1us);
    endtask

endclass

`endif 