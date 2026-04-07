`ifndef AXI_CONFIG_SV
`define AXI_CONFIG_SV

class axi_configuration extends uvm_object;

    `uvm_object_utils(axi_configuration)

    function new(string name = "axi_configuration");
        super.new(name);
    endfunction

endclass

`endif 