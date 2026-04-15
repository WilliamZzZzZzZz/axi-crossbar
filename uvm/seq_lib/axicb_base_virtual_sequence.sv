`ifndef AXICB_BASE_VIRTUAL_SEQUENCE_SV
`define AXICB_BASE_VIRTUAL_SEQUENCE_SV

class axicb_base_virtual_sequence extends uvm_sequence;
    `uvm_object_utils(axicb_base_virtual_sequence)

    
    bit [31:0] wr_val[]; 
    bit [31:0] rd_val[];

    axicb_single_write_sequence single_write;
    axicb_single_read_sequence single_read;

    virtual axi_if#(.ID_WIDTH(ID_WIDTH)) vif_mst00;
    virtual axi_if#(.ID_WIDTH(ID_WIDTH)) vif_mst01;
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

        vif_mst00 = p_sequencer.axi_mst_sqr00.vif;
        vif_mst01 = p_sequencer.axi_mst_sqr01.vif;
        vif       = vif_mst00;                      //default
        if(vif_mst00 == null || vif_mst01 == null)
            `uvm_fatal(get_type_name(), "failed to get vif from master sequencers")

        `uvm_info(get_type_name(), "exiting...", UVM_LOW)
    endtask

    virtual function bit compare_single_data(bit[31:0] val1, bit[31:0] val2);
        if(val1 === val2) begin
            return 1;
            `uvm_info("CMP-SUCCESS", $sformatf("val1 'h%0x === val2 'h%0x", val1, val2), UVM_LOW)
        end
        else begin
            return 0;
            `uvm_error("CMP-ERROR", $sformatf("val1 'h%0x === val2 'h%0x", val1, val2))
        end
    endfunction  

    virtual function void compare_data(bit[31:0] wr[], bit[31:0] rd[]);
        if(wr.size() != rd.size()) begin
            `uvm_error("CMP-SIZE", $sformatf("wr size(%0d) != rd size(%0d)", 
                        wr.size(), rd.size()))
            return;
        end
        foreach(wr[i]) begin
            if(wr[i] === rd[i])
                `uvm_info("CMP-PASS", $sformatf("beat[%0d] MATCH: wr=0x%08x rd=0x%08x", 
                        i, wr[i], rd[i]), UVM_LOW)
            else
                `uvm_error("CMP-FAIL", $sformatf("beat[%0d] MISMATCH: wr=0x%08x rd=0x%08x", 
                        i, wr[i], rd[i]))
        end
    endfunction

    task wait_cycles(int n);
        repeat(n) @(posedge vif.aclk);
    endtask
endclass

`endif 