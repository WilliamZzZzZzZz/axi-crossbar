`ifndef AXI_CONFIG_SV
`define AXI_CONFIG_SV

class axi_configuration extends uvm_object;

    `uvm_object_utils(axi_configuration)

    int data_width = 32;
    int strb_width = 4;
    int addr_width = 32;

    int reset_deassert_timeout_cycles = 128;
    int handshake_timeout_cycles      = 2000;
    int sequence_timeout_cycles       = 4000;
    time sim_timeout                  = 200us;

    function new(string name = "axi_configuration");
        super.new(name);
    endfunction

endclass

`endif 
