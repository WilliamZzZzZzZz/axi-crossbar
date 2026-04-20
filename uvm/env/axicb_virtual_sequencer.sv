`ifndef AXICB_VIRTUAL_SEQUENCER_SV
`define AXICB_VIRTUAL_SEQUENCER_SV

class axicb_virtual_sequencer extends uvm_sequencer;
    `uvm_component_utils(axicb_virtual_sequencer)

    axi_master_sequencer axi_mst_sqr00;
    axi_master_sequencer axi_mst_sqr01;

    virtual axi_if#(.ID_WIDTH(M_ID_WIDTH)) vif_slv00;
    virtual axi_if#(.ID_WIDTH(M_ID_WIDTH)) vif_slv01;

    function axi_master_sequencer get_master_sqr(int unsigned idx);
        case(idx)
            0: return axi_mst_sqr00;
            1: return axi_mst_sqr01;
            default: begin
                `uvm_fatal(get_type_name(), "Invalid master index")
            end
        endcase
    endfunction

    function new(string name = "axicb_virtual_sequencer", uvm_component parent = null);
        super.new(name, parent);
    endfunction

endclass

`endif 