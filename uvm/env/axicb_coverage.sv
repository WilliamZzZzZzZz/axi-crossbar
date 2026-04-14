`ifndef AXICB_COVERAGE_SV
`define AXICB_COVERAGE_SV

class axicb_coverage extends uvm_subscriber #(axi_transaction);
    `uvm_component_utils(axicb_coverage)

    trans_type_enum trans_type;
    burst_len_enum  burst_len;
    burst_size_enum burst_size;
    burst_type_enum burst_type;
    bit [15:0]      addr;
    bit [3:0]       wstrb;

    function new(string name  = "axicb_coverage", uvm_component parent = null);
        super.new(name, parent);
        //TODO new every covergroup below
        cg_trans_type = new();
        cg_burst = new();
    endfunction

    //automatically callback while monitor finish every single transaction
    virtual function void write(axi_transaction t);
        trans_type = t.trans_type;
        if(t.trans_type == WRITE) begin
            addr        = t.awaddr;
            burst_len   = t.awlen;
            burst_size  = t.awsize;
            burst_type  = t.awburst;
            wstrb       = (t.wstrb.size() > 0) ? t.wstrb[0][3:0] : 4'hF;
        end else begin  //READ
            addr        = t.araddr;
            burst_len   = t.arlen;
            burst_size  = t.arsize;
            burst_type  = t.arburst;
            wstrb       = 4'h0;
        end
        //TODO sample every covergroup
        cg_trans_type.sample();
        cg_burst.sample();
    endfunction

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
    endfunction

    //trans_type
    covergroup cg_trans_type;
        option.per_instance = 1;
        option.name = "transaction type coverage";

        TRANS_TYPE: coverpoint trans_type {
            bins write = {WRITE};
            bins read  = {READ};
        }
    endgroup

    covergroup cg_burst;
        option.per_instance = 1;
        option.name = "burst characteristics coverage";

        BURST_TYPE: coverpoint burst_type {
            bins fixed = {FIXED};
            bins incr  = {INCR};
        }
        BURST_LEN: coverpoint burst_len {
            bins beat_single = {BURST_LEN_SINGLE};
            bins beats_2     = {BURST_LEN_DOUBLE};
            bins beats_4     = {BURST_LEN_4BEATS};
            bins beats_8     = {BURST_LEN_8BEATS};
            bins beats_16    = {BURST_LEN_16BEATS};
        }
        BURST_SIZE: coverpoint burst_size {
            bins byte_1 = {BURST_SIZE_1BYTE};
            bins byte_2 = {BURST_SIZE_2BYTES};
            bins byte_4 = {BURST_SIZE_4BYTES};
        }

        BURST_TYPE_X_LEN:  cross BURST_TYPE, BURST_LEN;
        BURST_TYPE_X_SIZE: cross BURST_TYPE, BURST_SIZE;
    endgroup
    
    covergroup cg_comprehensive;
        option.per_instance = 1;
        option.name = "comprehensive cross coverage";

        CP_TYPE: coverpoint trans_type {
            bins write = {WRITE};
            bins read  = {READ};
        }
        CP_BURST: coverpoint burst_type {
            bins fixed = {FIXED};
            bins incr  = {INCR};
        }
        CP_LEN: coverpoint burst_len {
            bins beat_single = {BURST_LEN_SINGLE};
            bins beats_2     = {BURST_LEN_DOUBLE};
            bins beats_4     = {BURST_LEN_4BEATS};
            bins beats_8     = {BURST_LEN_8BEATS};
            bins beats_16    = {BURST_LEN_16BEATS};
        }
        TYPE_X_BURST_X_LEN: cross CP_TYPE, CP_BURST, CP_LEN;   
    endgroup
endclass

`endif 