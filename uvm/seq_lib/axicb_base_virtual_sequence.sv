`ifndef AXICB_BASE_VIRTUAL_SEQUENCE_SV
`define AXICB_BASE_VIRTUAL_SEQUENCE_SV

class axicb_base_virtual_sequence extends uvm_sequence;
    `uvm_object_utils(axicb_base_virtual_sequence)

    
    bit [31:0] wr_val[]; 
    bit [31:0] rd_val[];

    axicb_single_write_sequence single_write;
    axicb_single_read_sequence single_read;

    virtual axi_if#(.ID_WIDTH(ID_WIDTH))    vif_mst00;
    virtual axi_if#(.ID_WIDTH(ID_WIDTH))    vif_mst01;
    virtual axi_if#(.ID_WIDTH(M_ID_WIDTH))  vif_slv00;
    virtual axi_if#(.ID_WIDTH(M_ID_WIDTH))  vif_slv01;

    virtual axi_if#(.ID_WIDTH(ID_WIDTH)) vif;       //default

    `uvm_declare_p_sequencer(axicb_virtual_sequencer)

    function new(string name = "axicb_base_virtual_sequence");
        super.new(name);
    endfunction

    virtual task body();
        `uvm_info(get_type_name(), "entering...", UVM_LOW)

        if(p_sequencer == null)
            `uvm_fatal(get_type_name(), "p_sequencer is null")
        if(p_sequencer.axi_mst_sqr00 == null || p_sequencer.axi_mst_sqr01 == null)
            `uvm_fatal(get_type_name(), "master sequencer handles are null in virtual sequencer")

        //upstream VIF
        vif_mst00 = p_sequencer.axi_mst_sqr00.vif;
        vif_mst01 = p_sequencer.axi_mst_sqr01.vif;
        vif       = vif_mst00;                      //default
        if(vif_mst00 == null || vif_mst01 == null)
            `uvm_fatal(get_type_name(), "failed to get vif from master sequencers")
        //downstream VIF
        vif_slv00 = p_sequencer.vif_slv00;
        vif_slv01 = p_sequencer.vif_slv01;
        if(vif_slv00 == null || vif_slv01 == null)
            `uvm_fatal(get_type_name(), "failed to get downstream vif from virtual sequencer")

        `uvm_info(get_type_name(), "exiting...", UVM_LOW)
    endtask

    virtual function bit compare_single_data(bit[31:0] val1, bit[31:0] val2);
        if(val1 === val2) begin
            `uvm_info("CMP-SUCCESS", $sformatf("val1 'h%0x === val2 'h%0x", val1, val2), UVM_LOW)
            return 1;
        end
        else begin
            `uvm_error("CMP-ERROR", $sformatf("val1 'h%0x === val2 'h%0x", val1, val2))
            return 0;
        end
    endfunction  

    virtual function bit compare_data(bit[31:0] wr[], bit[31:0] rd[]);
        if(wr.size() != rd.size()) begin
            `uvm_error("CMP-SIZE", $sformatf("wr size(%0d) != rd size(%0d)", 
                        wr.size(), rd.size()))
            return 0;
        end
        foreach(wr[i]) begin
            if(wr[i] === rd[i])
                `uvm_info("CMP-PASS", $sformatf("beat[%0d] MATCH: wr=0x%08x rd=0x%08x", 
                        i, wr[i], rd[i]), UVM_LOW)
            else begin
                `uvm_error("CMP-FAIL", $sformatf("beat[%0d] MISMATCH: wr=0x%08x rd=0x%08x", 
                        i, wr[i], rd[i]))
                return 0;
            end
        end
        return 1;
    endfunction

    task wait_cycles(int n);
        repeat(n) @(posedge vif.aclk);
    endtask
endclass

`endif 