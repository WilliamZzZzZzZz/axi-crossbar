module axiram_tb;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import axi_pkg::*;
    import axiram_pkg::*;

    logic clk;
    logic rst;

    initial begin
        clk = 1'b0;
        forever #2ns clk = ~clk;
    end

    initial begin
        rst = 1'b1;
        #20ns;
        rst = 1'b0;
    end

    // s-side interfaces (driven by UVM master agents)
    axi_if s00_axi_if_inst(.aclk(clk), .arst(rst));
    axi_if s01_axi_if_inst(.aclk(clk), .arst(rst));

    // m-side interfaces (driven by DUT, responded by UVM slave agents)
    axi_if m00_axi_if_inst(.aclk(clk), .arst(rst));
    axi_if m01_axi_if_inst(.aclk(clk), .arst(rst));

    axi_crossbar_wrap_2x2 #(
        .DATA_WIDTH(32),
        .ADDR_WIDTH(32),
        .STRB_WIDTH(4),
        .S_ID_WIDTH(8),
        .M00_BASE_ADDR(32'h0000_0000),
        .M00_ADDR_WIDTH(32'd16),
        .M01_BASE_ADDR(32'h0001_0000),
        .M01_ADDR_WIDTH(32'd16)
    ) dut (
        .clk(clk),
        .rst(rst),

        // s00
        .s00_axi_awid    (s00_axi_if_inst.awid[7:0]),
        .s00_axi_awaddr  (s00_axi_if_inst.awaddr),
        .s00_axi_awlen   (s00_axi_if_inst.awlen),
        .s00_axi_awsize  (s00_axi_if_inst.awsize),
        .s00_axi_awburst (s00_axi_if_inst.awburst),
        .s00_axi_awlock  (s00_axi_if_inst.awlock),
        .s00_axi_awcache (s00_axi_if_inst.awcache),
        .s00_axi_awprot  (s00_axi_if_inst.awprot),
        .s00_axi_awqos   (s00_axi_if_inst.awqos),
        .s00_axi_awuser  (s00_axi_if_inst.awuser[0]),
        .s00_axi_awvalid (s00_axi_if_inst.awvalid),
        .s00_axi_awready (s00_axi_if_inst.awready),
        .s00_axi_wdata   (s00_axi_if_inst.wdata),
        .s00_axi_wstrb   (s00_axi_if_inst.wstrb),
        .s00_axi_wlast   (s00_axi_if_inst.wlast),
        .s00_axi_wuser   (s00_axi_if_inst.wuser[0]),
        .s00_axi_wvalid  (s00_axi_if_inst.wvalid),
        .s00_axi_wready  (s00_axi_if_inst.wready),
        .s00_axi_bid     (s00_axi_if_inst.bid[7:0]),
        .s00_axi_bresp   (s00_axi_if_inst.bresp),
        .s00_axi_buser   (s00_axi_if_inst.buser[0]),
        .s00_axi_bvalid  (s00_axi_if_inst.bvalid),
        .s00_axi_bready  (s00_axi_if_inst.bready),
        .s00_axi_arid    (s00_axi_if_inst.arid[7:0]),
        .s00_axi_araddr  (s00_axi_if_inst.araddr),
        .s00_axi_arlen   (s00_axi_if_inst.arlen),
        .s00_axi_arsize  (s00_axi_if_inst.arsize),
        .s00_axi_arburst (s00_axi_if_inst.arburst),
        .s00_axi_arlock  (s00_axi_if_inst.arlock),
        .s00_axi_arcache (s00_axi_if_inst.arcache),
        .s00_axi_arprot  (s00_axi_if_inst.arprot),
        .s00_axi_arqos   (s00_axi_if_inst.arqos),
        .s00_axi_aruser  (s00_axi_if_inst.aruser[0]),
        .s00_axi_arvalid (s00_axi_if_inst.arvalid),
        .s00_axi_arready (s00_axi_if_inst.arready),
        .s00_axi_rid     (s00_axi_if_inst.rid[7:0]),
        .s00_axi_rdata   (s00_axi_if_inst.rdata),
        .s00_axi_rresp   (s00_axi_if_inst.rresp),
        .s00_axi_rlast   (s00_axi_if_inst.rlast),
        .s00_axi_ruser   (s00_axi_if_inst.ruser[0]),
        .s00_axi_rvalid  (s00_axi_if_inst.rvalid),
        .s00_axi_rready  (s00_axi_if_inst.rready),

        // s01
        .s01_axi_awid    (s01_axi_if_inst.awid[7:0]),
        .s01_axi_awaddr  (s01_axi_if_inst.awaddr),
        .s01_axi_awlen   (s01_axi_if_inst.awlen),
        .s01_axi_awsize  (s01_axi_if_inst.awsize),
        .s01_axi_awburst (s01_axi_if_inst.awburst),
        .s01_axi_awlock  (s01_axi_if_inst.awlock),
        .s01_axi_awcache (s01_axi_if_inst.awcache),
        .s01_axi_awprot  (s01_axi_if_inst.awprot),
        .s01_axi_awqos   (s01_axi_if_inst.awqos),
        .s01_axi_awuser  (s01_axi_if_inst.awuser[0]),
        .s01_axi_awvalid (s01_axi_if_inst.awvalid),
        .s01_axi_awready (s01_axi_if_inst.awready),
        .s01_axi_wdata   (s01_axi_if_inst.wdata),
        .s01_axi_wstrb   (s01_axi_if_inst.wstrb),
        .s01_axi_wlast   (s01_axi_if_inst.wlast),
        .s01_axi_wuser   (s01_axi_if_inst.wuser[0]),
        .s01_axi_wvalid  (s01_axi_if_inst.wvalid),
        .s01_axi_wready  (s01_axi_if_inst.wready),
        .s01_axi_bid     (s01_axi_if_inst.bid[7:0]),
        .s01_axi_bresp   (s01_axi_if_inst.bresp),
        .s01_axi_buser   (s01_axi_if_inst.buser[0]),
        .s01_axi_bvalid  (s01_axi_if_inst.bvalid),
        .s01_axi_bready  (s01_axi_if_inst.bready),
        .s01_axi_arid    (s01_axi_if_inst.arid[7:0]),
        .s01_axi_araddr  (s01_axi_if_inst.araddr),
        .s01_axi_arlen   (s01_axi_if_inst.arlen),
        .s01_axi_arsize  (s01_axi_if_inst.arsize),
        .s01_axi_arburst (s01_axi_if_inst.arburst),
        .s01_axi_arlock  (s01_axi_if_inst.arlock),
        .s01_axi_arcache (s01_axi_if_inst.arcache),
        .s01_axi_arprot  (s01_axi_if_inst.arprot),
        .s01_axi_arqos   (s01_axi_if_inst.arqos),
        .s01_axi_aruser  (s01_axi_if_inst.aruser[0]),
        .s01_axi_arvalid (s01_axi_if_inst.arvalid),
        .s01_axi_arready (s01_axi_if_inst.arready),
        .s01_axi_rid     (s01_axi_if_inst.rid[7:0]),
        .s01_axi_rdata   (s01_axi_if_inst.rdata),
        .s01_axi_rresp   (s01_axi_if_inst.rresp),
        .s01_axi_rlast   (s01_axi_if_inst.rlast),
        .s01_axi_ruser   (s01_axi_if_inst.ruser[0]),
        .s01_axi_rvalid  (s01_axi_if_inst.rvalid),
        .s01_axi_rready  (s01_axi_if_inst.rready),

        // m00
        .m00_axi_awid    (m00_axi_if_inst.awid[8:0]),
        .m00_axi_awaddr  (m00_axi_if_inst.awaddr),
        .m00_axi_awlen   (m00_axi_if_inst.awlen),
        .m00_axi_awsize  (m00_axi_if_inst.awsize),
        .m00_axi_awburst (m00_axi_if_inst.awburst),
        .m00_axi_awlock  (m00_axi_if_inst.awlock),
        .m00_axi_awcache (m00_axi_if_inst.awcache),
        .m00_axi_awprot  (m00_axi_if_inst.awprot),
        .m00_axi_awqos   (m00_axi_if_inst.awqos),
        .m00_axi_awregion(),
        .m00_axi_awuser  (m00_axi_if_inst.awuser[0]),
        .m00_axi_awvalid (m00_axi_if_inst.awvalid),
        .m00_axi_awready (m00_axi_if_inst.awready),
        .m00_axi_wdata   (m00_axi_if_inst.wdata),
        .m00_axi_wstrb   (m00_axi_if_inst.wstrb),
        .m00_axi_wlast   (m00_axi_if_inst.wlast),
        .m00_axi_wuser   (m00_axi_if_inst.wuser[0]),
        .m00_axi_wvalid  (m00_axi_if_inst.wvalid),
        .m00_axi_wready  (m00_axi_if_inst.wready),
        .m00_axi_bid     (m00_axi_if_inst.bid[8:0]),
        .m00_axi_bresp   (m00_axi_if_inst.bresp),
        .m00_axi_buser   (m00_axi_if_inst.buser[0]),
        .m00_axi_bvalid  (m00_axi_if_inst.bvalid),
        .m00_axi_bready  (m00_axi_if_inst.bready),
        .m00_axi_arid    (m00_axi_if_inst.arid[8:0]),
        .m00_axi_araddr  (m00_axi_if_inst.araddr),
        .m00_axi_arlen   (m00_axi_if_inst.arlen),
        .m00_axi_arsize  (m00_axi_if_inst.arsize),
        .m00_axi_arburst (m00_axi_if_inst.arburst),
        .m00_axi_arlock  (m00_axi_if_inst.arlock),
        .m00_axi_arcache (m00_axi_if_inst.arcache),
        .m00_axi_arprot  (m00_axi_if_inst.arprot),
        .m00_axi_arqos   (m00_axi_if_inst.arqos),
        .m00_axi_arregion(),
        .m00_axi_aruser  (m00_axi_if_inst.aruser[0]),
        .m00_axi_arvalid (m00_axi_if_inst.arvalid),
        .m00_axi_arready (m00_axi_if_inst.arready),
        .m00_axi_rid     (m00_axi_if_inst.rid[8:0]),
        .m00_axi_rdata   (m00_axi_if_inst.rdata),
        .m00_axi_rresp   (m00_axi_if_inst.rresp),
        .m00_axi_rlast   (m00_axi_if_inst.rlast),
        .m00_axi_ruser   (m00_axi_if_inst.ruser[0]),
        .m00_axi_rvalid  (m00_axi_if_inst.rvalid),
        .m00_axi_rready  (m00_axi_if_inst.rready),

        // m01
        .m01_axi_awid    (m01_axi_if_inst.awid[8:0]),
        .m01_axi_awaddr  (m01_axi_if_inst.awaddr),
        .m01_axi_awlen   (m01_axi_if_inst.awlen),
        .m01_axi_awsize  (m01_axi_if_inst.awsize),
        .m01_axi_awburst (m01_axi_if_inst.awburst),
        .m01_axi_awlock  (m01_axi_if_inst.awlock),
        .m01_axi_awcache (m01_axi_if_inst.awcache),
        .m01_axi_awprot  (m01_axi_if_inst.awprot),
        .m01_axi_awqos   (m01_axi_if_inst.awqos),
        .m01_axi_awregion(),
        .m01_axi_awuser  (m01_axi_if_inst.awuser[0]),
        .m01_axi_awvalid (m01_axi_if_inst.awvalid),
        .m01_axi_awready (m01_axi_if_inst.awready),
        .m01_axi_wdata   (m01_axi_if_inst.wdata),
        .m01_axi_wstrb   (m01_axi_if_inst.wstrb),
        .m01_axi_wlast   (m01_axi_if_inst.wlast),
        .m01_axi_wuser   (m01_axi_if_inst.wuser[0]),
        .m01_axi_wvalid  (m01_axi_if_inst.wvalid),
        .m01_axi_wready  (m01_axi_if_inst.wready),
        .m01_axi_bid     (m01_axi_if_inst.bid[8:0]),
        .m01_axi_bresp   (m01_axi_if_inst.bresp),
        .m01_axi_buser   (m01_axi_if_inst.buser[0]),
        .m01_axi_bvalid  (m01_axi_if_inst.bvalid),
        .m01_axi_bready  (m01_axi_if_inst.bready),
        .m01_axi_arid    (m01_axi_if_inst.arid[8:0]),
        .m01_axi_araddr  (m01_axi_if_inst.araddr),
        .m01_axi_arlen   (m01_axi_if_inst.arlen),
        .m01_axi_arsize  (m01_axi_if_inst.arsize),
        .m01_axi_arburst (m01_axi_if_inst.arburst),
        .m01_axi_arlock  (m01_axi_if_inst.arlock),
        .m01_axi_arcache (m01_axi_if_inst.arcache),
        .m01_axi_arprot  (m01_axi_if_inst.arprot),
        .m01_axi_arqos   (m01_axi_if_inst.arqos),
        .m01_axi_arregion(),
        .m01_axi_aruser  (m01_axi_if_inst.aruser[0]),
        .m01_axi_arvalid (m01_axi_if_inst.arvalid),
        .m01_axi_arready (m01_axi_if_inst.arready),
        .m01_axi_rid     (m01_axi_if_inst.rid[8:0]),
        .m01_axi_rdata   (m01_axi_if_inst.rdata),
        .m01_axi_rresp   (m01_axi_if_inst.rresp),
        .m01_axi_rlast   (m01_axi_if_inst.rlast),
        .m01_axi_ruser   (m01_axi_if_inst.ruser[0]),
        .m01_axi_rvalid  (m01_axi_if_inst.rvalid),
        .m01_axi_rready  (m01_axi_if_inst.rready)
    );

    initial begin
        uvm_config_db#(virtual axi_if)::set(null, "uvm_test_top.env", "s00_vif", s00_axi_if_inst);
        uvm_config_db#(virtual axi_if)::set(null, "uvm_test_top.env", "s01_vif", s01_axi_if_inst);
        uvm_config_db#(virtual axi_if)::set(null, "uvm_test_top.env", "m00_vif", m00_axi_if_inst);
        uvm_config_db#(virtual axi_if)::set(null, "uvm_test_top.env", "m01_vif", m01_axi_if_inst);
        run_test();
    end

endmodule
