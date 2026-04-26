`ifndef AXICB_DECODE_BASE_VSEQ_SV
`define AXICB_DECODE_BASE_VSEQ_SV

class axicb_decode_base_vseq extends axicb_base_vseq;

    `uvm_object_utils(axicb_decode_base_vseq)

    bit [ADDR_WIDTH - 1:0] s0_base_addr      = 32'h0000_0000;
    bit [ADDR_WIDTH - 1:0] s0_mid_addr       = 32'h0000_8000;
    bit [ADDR_WIDTH - 1:0] s0_boundary_addr  = 32'h0000_FFFC;
    bit [ADDR_WIDTH - 1:0] s1_base_addr      = 32'h0001_0000;
    bit [ADDR_WIDTH - 1:0] s1_mid_addr       = 32'h0001_8000;
    bit [ADDR_WIDTH - 1:0] s1_boundary_addr  = 32'h0001_FFFC;

    function new(string name = "axicb_decode_base_vseq");
        super.new(name);
    endfunction

    protected task automatic upstream_decode_checker(
        input int unsigned         mst_idx,        
        input trans_type_enum      txn_type,
        input bit [ID_WIDTH - 1:0] expected_id,
        ref   bit                  upstream_error
    );
        virtual axi_if#(.ID_WIDTH(ID_WIDTH)) vif_mst;
        bit timeout;

        case(mst_idx)
            0: vif_mst = vif_mst00;
            1: vif_mst = vif_mst01;
            default: `uvm_fatal(get_type_name(), "UNDEFINED master index!")
        endcase

        if(txn_type == WRITE) begin
            //B handshake timeout check
            wait_ups_b_handshake(vif_mst, 1000, timeout);
            if(timeout) begin
                `uvm_error(get_type_name(), "upstream WRITE timeout: no B handshake")
                upstream_error = 1;
                return;
            end            
            //handshake success, then check ID
            if(vif_mst.bid !== expected_id) begin
                `uvm_error(get_type_name(), $sformatf("upstream BID mismatch: expect=%08b actual=%08b", expected_id, vif_mst.bid))
                upstream_error = 1;
            end
        end
        else begin  //READ
            //R handshake timeout check
            wait_ups_r_handshake(vif_mst, 1000, timeout);
            if(timeout) begin
                `uvm_error(get_type_name(), "upstream WRITE timeout: no R handshake")
                upstream_error = 1;
                return;
            end  
            //handshake success, then check ID
            if(vif_mst.rid !== expected_id) begin
                `uvm_error(get_type_name(), $sformatf("upstream RID mismatch: expect=%08b actual=%08b", expected_id, vif_mst.rid))
                upstream_error = 1;
            end
        end

    endtask

    protected task automatic downstream_decode_checker(
        input int unsigned           mst_idx,        
        input trans_type_enum        txn_type,
        input bit [ADDR_WIDTH - 1:0] addr,
        input bit [ID_WIDTH - 1:0]   txn_id,
        ref   bit                    downstream_error 
    );
        virtual axi_if#(.ID_WIDTH(M_ID_WIDTH)) vif_slv;
        bit [M_ID_WIDTH - 1:0] expected_id;
        bit timeout;

        case(mst_idx)
            0: expected_id = {1'b0, txn_id};
            1: expected_id = {1'b1, txn_id};
            default: `uvm_fatal(get_type_name(), "UNDEFINED master index")
        endcase
        
        if (addr inside {[32'h0000_0000:32'h0000_FFFF]})
            vif_slv = vif_slv00;
        else if (addr inside {[32'h0001_0000:32'h0001_FFFF]})
            vif_slv = vif_slv01;
        else
            `uvm_fatal(get_type_name(), $sformatf("Address 0x%08h does not map to any slave!", addr))

        if(txn_type == WRITE) begin
            //AW handshake timeout check
            wait_downs_aw_handshake(vif_slv, 1000, timeout);
            if(timeout) begin
                `uvm_error(get_type_name(), "downstream WRITE timeout: no AW handshake")
                downstream_error = 1;
                return;
            end
            //AW channel AWADDR check 
            if(vif_slv.awaddr !== addr) begin
                `uvm_error(get_type_name(), $sformatf("downstream AWADDR mismatch: expect=%08h actual=%08h", addr, vif_slv.awaddr))
                downstream_error = 1;
            end

            //B handshake timeout check
            wait_downs_b_handshake(vif_slv, 1000, timeout);
            if(timeout) begin
                `uvm_error(get_type_name(), "downstream WRITE timeout: no B handshake")
                downstream_error = 1;
                return;
            end
            //B channel ID check
            if(vif_slv.bid !== expected_id) begin
                `uvm_error(get_type_name(), $sformatf("downstream BID mismatch: expect=%09b actual=%09b", expected_id, vif_slv.bid))
                downstream_error = 1;
            end
            else 
                `uvm_info(get_type_name(), $sformatf("got 9-bit id: %09b", vif_slv.bid), UVM_LOW)
        end
        else begin  //READ
            //AR handshake timeout check
            wait_downs_ar_handshake(vif_slv, 1000, timeout);
            if(timeout) begin
                `uvm_error(get_type_name(), "downstream READ timeout: no AR handshake")
                downstream_error = 1;
                return;
            end
            //AR channel ARADDR check
            if(vif_slv.araddr !== addr) begin
                `uvm_error(get_type_name(), $sformatf("downstream ARADDR mismatch: expect=%08h actual=%08h", addr, vif_slv.araddr))
                downstream_error = 1;
            end

            //R handshake timeout check
            wait_downs_r_handshake(vif_slv, 1000, timeout);
            if(timeout) begin
                `uvm_error(get_type_name(), "downstream READ timeout: no R handshake")
                downstream_error = 1;
                return;
            end
            //R channel ID check
            if(vif_slv.rid !== expected_id) begin
                `uvm_error(get_type_name(), $sformatf("downstream RID mismatch: expect=%09b actual=%09b", expected_id, vif_slv.rid))
                downstream_error = 1;
            end
            else
                `uvm_info(get_type_name(), $sformatf("got 9-bit id: %09b", vif_slv.rid), UVM_LOW)
        end

    endtask

    //downstream AW handshake timeout checker
    local task automatic wait_downs_aw_handshake(
        virtual axi_if#(.ID_WIDTH(M_ID_WIDTH)) vif_slv,
        input   int unsigned                   timeout_cycles,
        output  bit                            timeout 
    );
        timeout = 1;
        repeat(timeout_cycles) begin
            @(posedge vif_slv.aclk);
            if(vif_slv.awvalid && vif_slv.awready) begin
                timeout = 0;
                return;
            end
        end
    endtask

    //downstream B handshake timeout checker
    local task automatic wait_downs_b_handshake(
        virtual axi_if#(.ID_WIDTH(M_ID_WIDTH)) vif_slv,
        input   int unsigned                   timeout_cycles,
        output  bit                            timeout
    );
        timeout = 1;
        repeat(timeout_cycles) begin
            @(posedge vif_slv.aclk);
            if(vif_slv.bvalid && vif_slv.bready) begin
                timeout = 0;
                return;
            end
        end
    endtask

    //downstream AR handshake timeout checker
    local task automatic wait_downs_ar_handshake(
        virtual axi_if#(.ID_WIDTH(M_ID_WIDTH)) vif_slv,
        input   int unsigned                   timeout_cycles,
        output  bit                            timeout
    );
        timeout = 1;
        repeat(timeout_cycles) begin
            @(posedge vif_slv.aclk);
            if(vif_slv.arvalid && vif_slv.arready) begin
                timeout = 0;
                return;
            end
        end
    endtask    

    //downstream R handshake timeout checker
    local task automatic wait_downs_r_handshake(
        virtual axi_if#(.ID_WIDTH(M_ID_WIDTH)) vif_slv,
        input   int unsigned                   timeout_cycles,
        output  bit                            timeout
    );
        timeout = 1;
        repeat(timeout_cycles) begin
            @(posedge vif_slv.aclk);
            if(vif_slv.rvalid && vif_slv.rready) begin
                timeout = 0;
                return;
            end
        end
    endtask  

    //upstream B handshake timeout checker
    local task automatic wait_ups_b_handshake(
        virtual axi_if#(.ID_WIDTH(ID_WIDTH))   vif_mst,
        input   int unsigned                   timeout_cycles,
        output  bit                            timeout
    );
        timeout = 1;
        repeat(timeout_cycles) begin
            @(posedge vif_mst.aclk);
            if(vif_mst.bvalid && vif_mst.bready) begin
                timeout = 0;
                return;
            end
        end
    endtask 

    //upstream R handshake timeout checker
    local task automatic wait_ups_r_handshake(
        virtual axi_if#(.ID_WIDTH(ID_WIDTH))   vif_mst,
        input   int unsigned                   timeout_cycles,
        output  bit                            timeout
    );
        timeout = 1;
        repeat(timeout_cycles) begin
            @(posedge vif_mst.aclk);
            if(vif_mst.rvalid && vif_mst.rready) begin
                timeout = 0;
                return;
            end
        end
    endtask 

endclass

`endif 
