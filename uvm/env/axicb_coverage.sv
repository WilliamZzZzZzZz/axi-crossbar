`ifndef AXICB_COVERAGE_SV
`define AXICB_COVERAGE_SV

//automatically create 2 callback entry functions
`uvm_analysis_imp_decl(_mst00)      //-> write_mst00()
`uvm_analysis_imp_decl(_mst01)      //-> write_mst01()

class axicb_coverage extends uvm_component;
    `uvm_component_utils(axicb_coverage)

    uvm_analysis_imp_mst00 #(axi_transaction, axicb_coverage) mst00_export;
    uvm_analysis_imp_mst01 #(axi_transaction, axicb_coverage) mst01_export;

    trans_type_enum trans_type;
    burst_len_enum  burst_len;
    burst_size_enum burst_size;
    burst_type_enum burst_type;
    bit [ADDR_WIDTH - 1:0] addr;
    bit [STRB_WIDTH - 1:0] wstrb;

    int src_master;     // 0: mst00, 1: mst01
    int dst_slave;      // 0: slv00, 1: slv01
    bit [1:0] resp;     // bresp and rresp

    function new(string name  = "axicb_coverage", uvm_component parent = null);
        super.new(name, parent);
        mst00_export = new("mst00_export", this);
        mst01_export = new("mst01_export", this);
        //TODO new every covergroup below
        cg_trans_type    = new();
        cg_burst         = new();
        cg_comprehensive = new();
        cg_routing       = new();
        cg_response      = new();
    endfunction

    function void write_mst00(axi_transaction t);
        src_master = 0;
        sample_all(t);
    endfunction

    function void write_mst01(axi_transaction t);
        src_master = 1;
        sample_all(t);
    endfunction

    //automatically callback while monitor finish every single transaction
    virtual function void sample_all(axi_transaction t);
        trans_type = t.trans_type;
        if(t.trans_type == WRITE) begin
            addr        = t.awaddr;
            burst_len   = t.awlen;
            burst_size  = t.awsize;
            burst_type  = t.awburst;
            wstrb       = (t.wstrb.size() > 0) ? t.wstrb[0][3:0] : 4'hF;
            resp        = t.bresp;
        end else begin  //READ
            addr        = t.araddr;
            burst_len   = t.arlen;
            burst_size  = t.arsize;
            burst_type  = t.arburst;
            wstrb       = 4'h0;
            resp        = (t.rresp.size() > 0) ? t.rresp[0] : 2'b00;
        end

        //use 'addr' to decide this tr send to which slave
        if((addr >= 32'h0000_0000) && (addr <= 32'h0000_FFFF))
            dst_slave = 0;
        else if((addr >= 32'h0001_0000) && (addr <= 32'h0001_FFFF))
            dst_slave = 1;
        else
            dst_slave = -1;     //unmapped slave(DECERR)

        //TODO sample every covergroup
        cg_trans_type.sample();
        cg_burst.sample();
        cg_comprehensive.sample();
        cg_routing.sample();
        cg_response.sample();
    endfunction

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
    endfunction

    //====================== covergroup =========================//
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
            bins wrap  = {WRAP};
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

    covergroup cg_routing;
        option.per_instance = 1;
        option.name = "routing path coverage";

        CP_SRC_MASTER: coverpoint src_master {
            bins m0 = {0};
            bins m1 = {1};
        }
        CP_DST_SLAVE: coverpoint dst_slave {
            bins s0     = {0};
            bins s1     = {1};
            bins decerr = {-1};
        }
        CP_TXN_TYPE: coverpoint trans_type {
            bins write = {WRITE};
            bins read  = {READ};
        }
        CX_ROUTING: cross CP_SRC_MASTER, CP_DST_SLAVE, CP_TXN_TYPE;
    endgroup

    covergroup cg_response;
        option.per_instance = 1;
        option.name = "response type coverage";

        CP_RESP: coverpoint resp {
            bins okay   = {2'b00};
            bins decerr = {2'b11};
        }
        CP_TXN_TYPE: coverpoint trans_type {
            bins write = {WRITE};
            bins read  = {READ};
        }
        CX_RESP: cross CP_RESP, CP_TXN_TYPE;
    endgroup

endclass

`endif 