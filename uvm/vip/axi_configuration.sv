`ifndef AXI_CONFIG_SV
`define AXI_CONFIG_SV

class axi_configuration extends uvm_object;
    `uvm_object_utils(axi_configuration)

    // Tag used by monitor/scoreboard to identify which interface produced this transaction.
    int agent_port_idx = -1;

    // 0: master agent side (sXX)
    // 1: slave responder side (mXX)
    bit is_slave_agent = 0;

    function new(string name = "axi_configuration");
        super.new(name);
    endfunction

endclass

`endif
