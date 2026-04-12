`ifndef AXICB_BASE_TEST_SV
`define AXICB_BASE_TEST_SV

class axicb_base_test extends uvm_test;

    `uvm_component_utils(axicb_base_test)
    axi_crossbar_env env;

    function new(string name = "axicb_base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = axi_crossbar_env::type_id::create("env", this);
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