module axiram_tb;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import axi_pkg::*;
    import axiram_pkg::*;       

    logic clk;
    logic rst;

    initial begin 
        clk = 0;
        forever #2ns clk = !clk;
    end

    initial begin
        rst = 1'b1;
        #20ns;
        rst = 1'b0;
    end

    axi_if #(
        .DATA_WIDTH(32),
        .ADDR_WIDTH(16),
        .ID_WIDTH(8),
        .STRB_WIDTH(4)
    ) axi_if_inst(
        .aclk(clk),
        .arst(rst)
    );

    axi_ram #(
        .DATA_WIDTH(32),
        .ADDR_WIDTH(16),
        .STRB_WIDTH(4),
        .ID_WIDTH(8),
        .PIPELINE_OUTPUT(0)
        ) dut(
        .clk(axi_if_inst.aclk),
        .rst(axi_if_inst.arst),
        //AW channel
        .s_axi_awid(axi_if_inst.awid),
        .s_axi_awaddr(axi_if_inst.awaddr),
        .s_axi_awlen(axi_if_inst.awlen),
        .s_axi_awsize(axi_if_inst.awsize),
        .s_axi_awburst(axi_if_inst.awburst),
        .s_axi_awlock(axi_if_inst.awlock),
        .s_axi_awcache(axi_if_inst.awcache),
        .s_axi_awprot(axi_if_inst.awprot),
        .s_axi_awvalid(axi_if_inst.awvalid),
        .s_axi_awready(axi_if_inst.awready),
        //W channel
        .s_axi_wdata(axi_if_inst.wdata),
        .s_axi_wstrb(axi_if_inst.wstrb),
        .s_axi_wlast(axi_if_inst.wlast),
        .s_axi_wvalid(axi_if_inst.wvalid),
        .s_axi_wready(axi_if_inst.wready),
        //B channel
        .s_axi_bid(axi_if_inst.bid),
        .s_axi_bresp(axi_if_inst.bresp),
        .s_axi_bvalid(axi_if_inst.bvalid),
        .s_axi_bready(axi_if_inst.bready),
        //AR channel
        .s_axi_arid(axi_if_inst.arid),
        .s_axi_araddr(axi_if_inst.araddr),
        .s_axi_arlen(axi_if_inst.arlen),
        .s_axi_arsize(axi_if_inst.arsize),
        .s_axi_arburst(axi_if_inst.arburst),
        .s_axi_arlock(axi_if_inst.arlock),
        .s_axi_arcache(axi_if_inst.arcache),
        .s_axi_arprot(axi_if_inst.arprot),
        .s_axi_arvalid(axi_if_inst.arvalid),
        .s_axi_arready(axi_if_inst.arready),
        //R channel
        .s_axi_rid(axi_if_inst.rid),
        .s_axi_rdata(axi_if_inst.rdata),
        .s_axi_rresp(axi_if_inst.rresp),
        .s_axi_rlast(axi_if_inst.rlast),
        .s_axi_rvalid(axi_if_inst.rvalid),
        .s_axi_rready(axi_if_inst.rready)
    );

    initial begin
        uvm_config_db#(virtual axi_if)::set(null, "uvm_test_top*", "vif", axi_if_inst);
        run_test();
    end
endmodule