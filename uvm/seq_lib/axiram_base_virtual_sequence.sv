`ifndef AXIRAM_BASE_VIRTUAL_SEQUENCE_SV
`define AXIRAM_BASE_VIRTUAL_SEQUENCE_SV

class axiram_base_virtual_sequence extends uvm_sequence;

    virtual axi_if vif;
    bit [31:0] wr_val[]; 
    bit [31:0] rd_val[];

    axiram_single_write_sequence single_write;
    axiram_single_read_sequence single_read;

    `uvm_object_utils(axiram_base_virtual_sequence)
    `uvm_declare_p_sequencer(axiram_virtual_sequencer)

    function new(string name = "axiram_base_virtual_sequence");
        super.new(name);
    endfunction

    virtual task body();
        `uvm_info(get_type_name(), "entering...", UVM_LOW)
        
        if(!uvm_config_db#(virtual axi_if)::get(p_sequencer, "", "vif", vif))
            `uvm_fatal(get_type_name(), "Failed to get vif from config_db in virtual sequence")

        `uvm_info(get_type_name(), "exiting...", UVM_LOW)
    endtask

    virtual function void compare_single_data(bit[31:0] val1, bit[31:0] val2);
        if(val1 === val2)
            `uvm_info("CMP-SUCCESS", $sformatf("val1 'h%0x === val2 'h%0x", val1, val2), UVM_LOW)
        else begin
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