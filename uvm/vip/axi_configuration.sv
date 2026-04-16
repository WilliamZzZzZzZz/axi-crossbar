`ifndef AXI_CONFIG_SV
`define AXI_CONFIG_SV

class axi_configuration extends uvm_object;

    `uvm_object_utils(axi_configuration)

    int data_width = 32;
    int strb_width = 4;
    int addr_width = 32;

    int handshake_timeout_cycles = 500;
    int idle_timeout_cycles = 5000;     //for slave AW and AR channel

    function new(string name = "axi_configuration");
        super.new(name);
    endfunction

endclass

`endif 