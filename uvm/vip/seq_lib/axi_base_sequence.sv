`ifndef AXI_BASE_SEQUENCE_SV
`define AXI_BASE_SEQUENCE_SV

class axi_base_sequence extends uvm_sequence #(axi_transaction);
    `uvm_object_utils(axi_base_sequence)

    function new(string name = "axi_base_sequence");
        super.new(name);
    endfunction
    
endclass

`endif 