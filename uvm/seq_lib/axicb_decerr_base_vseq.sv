`ifndef AXICB_DECERR_BASE_VSEQ_SV
`define AXICB_DECERR_BASE_VSEQ_SV

class axicb_decerr_base_vseq extends axicb_base_vseq;

    `uvm_object_utils(axicb_decerr_base_vseq)

    function new(string name = "axicb_decerr_base_vseq");
        super.new(name);
    endfunction

    protected task randomize_write_data(axicb_single_write_sequence seq, int unsigned beat_num);
        bit [DATA_WIDTH - 1:0] rand_data;
        seq.every_beat_data  = new[beat_num];
        seq.every_beat_wstrb = new[beat_num];

        foreach(seq.every_beat_data[i]) begin
            if(!std::randomize(rand_data))
                `uvm_fatal(get_type_name(), "data randomization FAILED!")
                
            seq.every_beat_data[i]  = rand_data;
            seq.every_beat_wstrb[i] = 4'hF;
        end
        seq.data = seq.every_beat_data[0];
    endtask

    protected task automatic check_downstream_port(
        trans_type_enum txn_type,
        virtual axi_if#(.ID_WIDTH(M_ID_WIDTH)) vif_slv,
        ref bit downstream_leak
    );
        if(txn_type == WRITE) begin     //WRITE
            //AWVALID check
            if(vif_slv.awvalid === 1'b1) begin
                `uvm_error(get_type_name(), $sformatf("downstream LEAK when decerr_write! awvalid=1, awaddr: %08h, awid: %09h", vif_slv.awaddr, vif_slv.awid))
                downstream_leak = 1;
            end
            //WVALID check
            if(vif_slv.wvalid === 1'b1) begin
                `uvm_error(get_type_name(), $sformatf("downstream LEAK when decerr_write! wvalid=1, wdata: %08h", vif_slv.wdata))
                downstream_leak = 1;
            end
        end
        else begin      //READ
            //ARVALID
            if(vif_slv.arvalid === 1'b1) begin
                `uvm_error(get_type_name(), $sformatf("downstream LEAK when decerr_read! arvalid=1, araddr: %08h, arid: %09h", vif_slv.araddr, vif_slv.arid))
                downstream_leak = 1;
            end
        end
    endtask

endclass

`endif 