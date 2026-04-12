module axi_crossbar_tb;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import axi_pkg::*;
    import axiram_pkg::*;

    localparam int AXI_DATA_WIDTH   = 32;
    localparam int AXI_ADDR_WIDTH   = 32;
    localparam int AXI_STRB_WIDTH   = AXI_DATA_WIDTH / 8;

    localparam int AXI_S_ID_WIDTH   = 8;
    localparam int AXI_M_ID_WIDTH   = AXI_S_ID_WIDTH + 1;

    localparam int AXI_QOS_WIDTH    = 4;
    localparam int AXI_REGION_WIDTH = 4;
    localparam int AXI_AWUSER_WIDTH = 1;
    localparam int AXI_WUSER_WIDTH  = 1;
    localparam int AXI_BUSER_WIDTH  = 1;
    localparam int AXI_ARUSER_WIDTH = 1;
    localparam int AXI_RUSER_WIDTH  = 1;

    localparam int M_REGIONS = 1;

    localparam logic [AXI_ADDR_WIDTH-1:0] M00_BASE_ADDR  = 32'h0000_0000;
    localparam logic [31:0]               M00_ADDR_WIDTH = 32'd16;
    localparam logic [AXI_ADDR_WIDTH-1:0] M01_BASE_ADDR  = 32'h0001_0000;
    localparam logic [31:0]               M01_ADDR_WIDTH = 32'd16;

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

    axi_if #(
        .DATA_WIDTH   (AXI_DATA_WIDTH),
        .ADDR_WIDTH   (AXI_ADDR_WIDTH),
        .ID_WIDTH     (AXI_S_ID_WIDTH),
        .STRB_WIDTH   (AXI_STRB_WIDTH),
        .QOS_WIDTH    (AXI_QOS_WIDTH),
        .REGION_WIDTH (AXI_REGION_WIDTH),
        .AWUSER_WIDTH (AXI_AWUSER_WIDTH),
        .WUSER_WIDTH  (AXI_WUSER_WIDTH),
        .BUSER_WIDTH  (AXI_BUSER_WIDTH),
        .ARUSER_WIDTH (AXI_ARUSER_WIDTH),
        .RUSER_WIDTH  (AXI_RUSER_WIDTH)
    ) s00_axi_if (
        .aclk(clk),
        .arst(rst)
    );

    axi_if #(
        .DATA_WIDTH   (AXI_DATA_WIDTH),
        .ADDR_WIDTH   (AXI_ADDR_WIDTH),
        .ID_WIDTH     (AXI_S_ID_WIDTH),
        .STRB_WIDTH   (AXI_STRB_WIDTH),
        .QOS_WIDTH    (AXI_QOS_WIDTH),
        .REGION_WIDTH (AXI_REGION_WIDTH),
        .AWUSER_WIDTH (AXI_AWUSER_WIDTH),
        .WUSER_WIDTH  (AXI_WUSER_WIDTH),
        .BUSER_WIDTH  (AXI_BUSER_WIDTH),
        .ARUSER_WIDTH (AXI_ARUSER_WIDTH),
        .RUSER_WIDTH  (AXI_RUSER_WIDTH)
    ) s01_axi_if (
        .aclk(clk),
        .arst(rst)
    );

    axi_if #(
        .DATA_WIDTH   (AXI_DATA_WIDTH),
        .ADDR_WIDTH   (AXI_ADDR_WIDTH),
        .ID_WIDTH     (AXI_M_ID_WIDTH),
        .STRB_WIDTH   (AXI_STRB_WIDTH),
        .QOS_WIDTH    (AXI_QOS_WIDTH),
        .REGION_WIDTH (AXI_REGION_WIDTH),
        .AWUSER_WIDTH (AXI_AWUSER_WIDTH),
        .WUSER_WIDTH  (AXI_WUSER_WIDTH),
        .BUSER_WIDTH  (AXI_BUSER_WIDTH),
        .ARUSER_WIDTH (AXI_ARUSER_WIDTH),
        .RUSER_WIDTH  (AXI_RUSER_WIDTH)
    ) m00_axi_if (
        .aclk(clk),
        .arst(rst)
    );

    axi_if #(
        .DATA_WIDTH   (AXI_DATA_WIDTH),
        .ADDR_WIDTH   (AXI_ADDR_WIDTH),
        .ID_WIDTH     (AXI_M_ID_WIDTH),
        .STRB_WIDTH   (AXI_STRB_WIDTH),
        .QOS_WIDTH    (AXI_QOS_WIDTH),
        .REGION_WIDTH (AXI_REGION_WIDTH),
        .AWUSER_WIDTH (AXI_AWUSER_WIDTH),
        .WUSER_WIDTH  (AXI_WUSER_WIDTH),
        .BUSER_WIDTH  (AXI_BUSER_WIDTH),
        .ARUSER_WIDTH (AXI_ARUSER_WIDTH),
        .RUSER_WIDTH  (AXI_RUSER_WIDTH)
    ) m01_axi_if (
        .aclk(clk),
        .arst(rst)
    );

    // --------------------------------------------------------------------
    // DUT: AXI 2x2 crossbar
    // --------------------------------------------------------------------
    axi_crossbar_wrap_2x2 #(
        .DATA_WIDTH        (AXI_DATA_WIDTH),
        .ADDR_WIDTH        (AXI_ADDR_WIDTH),
        .STRB_WIDTH        (AXI_STRB_WIDTH),
        .S_ID_WIDTH        (AXI_S_ID_WIDTH),
        .M_ID_WIDTH        (AXI_M_ID_WIDTH),

        .AWUSER_ENABLE     (0),
        .AWUSER_WIDTH      (AXI_AWUSER_WIDTH),
        .WUSER_ENABLE      (0),
        .WUSER_WIDTH       (AXI_WUSER_WIDTH),
        .BUSER_ENABLE      (0),
        .BUSER_WIDTH       (AXI_BUSER_WIDTH),
        .ARUSER_ENABLE     (0),
        .ARUSER_WIDTH      (AXI_ARUSER_WIDTH),
        .RUSER_ENABLE      (0),
        .RUSER_WIDTH       (AXI_RUSER_WIDTH),

        .S00_THREADS       (2),
        .S00_ACCEPT        (16),
        .S01_THREADS       (2),
        .S01_ACCEPT        (16),

        .M_REGIONS         (M_REGIONS),
        .M00_BASE_ADDR     (M00_BASE_ADDR),
        .M00_ADDR_WIDTH    (M00_ADDR_WIDTH),
        .M00_CONNECT_READ  (2'b11),
        .M00_CONNECT_WRITE (2'b11),
        .M00_ISSUE         (4),
        .M00_SECURE        (0),

        .M01_BASE_ADDR     (M01_BASE_ADDR),
        .M01_ADDR_WIDTH    (M01_ADDR_WIDTH),
        .M01_CONNECT_READ  (2'b11),
        .M01_CONNECT_WRITE (2'b11),
        .M01_ISSUE         (4),
        .M01_SECURE        (0),

        .S00_AW_REG_TYPE   (0),
        .S00_W_REG_TYPE    (0),
        .S00_B_REG_TYPE    (1),
        .S00_AR_REG_TYPE   (0),
        .S00_R_REG_TYPE    (2),

        .S01_AW_REG_TYPE   (0),
        .S01_W_REG_TYPE    (0),
        .S01_B_REG_TYPE    (1),
        .S01_AR_REG_TYPE   (0),
        .S01_R_REG_TYPE    (2),

        .M00_AW_REG_TYPE   (1),
        .M00_W_REG_TYPE    (2),
        .M00_B_REG_TYPE    (0),
        .M00_AR_REG_TYPE   (1),
        .M00_R_REG_TYPE    (0),

        .M01_AW_REG_TYPE   (1),
        .M01_W_REG_TYPE    (2),
        .M01_B_REG_TYPE    (0),
        .M01_AR_REG_TYPE   (1),
        .M01_R_REG_TYPE    (0)
    ) dut (
        .clk(clk),
        .rst(rst),

        // ==================== salve00_port (connect vip-master) ====================
        .s00_axi_awid     (s00_axi_if.awid),
        .s00_axi_awaddr   (s00_axi_if.awaddr),
        .s00_axi_awlen    (s00_axi_if.awlen),
        .s00_axi_awsize   (s00_axi_if.awsize),
        .s00_axi_awburst  (s00_axi_if.awburst),
        .s00_axi_awlock   (s00_axi_if.awlock),
        .s00_axi_awcache  (s00_axi_if.awcache),
        .s00_axi_awprot   (s00_axi_if.awprot),
        .s00_axi_awqos    (s00_axi_if.awqos),
        .s00_axi_awuser   (s00_axi_if.awuser),
        .s00_axi_awvalid  (s00_axi_if.awvalid),
        .s00_axi_awready  (s00_axi_if.awready),

        .s00_axi_wdata    (s00_axi_if.wdata),
        .s00_axi_wstrb    (s00_axi_if.wstrb),
        .s00_axi_wlast    (s00_axi_if.wlast),
        .s00_axi_wuser    (s00_axi_if.wuser),
        .s00_axi_wvalid   (s00_axi_if.wvalid),
        .s00_axi_wready   (s00_axi_if.wready),

        .s00_axi_bid      (s00_axi_if.bid),
        .s00_axi_bresp    (s00_axi_if.bresp),
        .s00_axi_buser    (s00_axi_if.buser),
        .s00_axi_bvalid   (s00_axi_if.bvalid),
        .s00_axi_bready   (s00_axi_if.bready),

        .s00_axi_arid     (s00_axi_if.arid),
        .s00_axi_araddr   (s00_axi_if.araddr),
        .s00_axi_arlen    (s00_axi_if.arlen),
        .s00_axi_arsize   (s00_axi_if.arsize),
        .s00_axi_arburst  (s00_axi_if.arburst),
        .s00_axi_arlock   (s00_axi_if.arlock),
        .s00_axi_arcache  (s00_axi_if.arcache),
        .s00_axi_arprot   (s00_axi_if.arprot),
        .s00_axi_arqos    (s00_axi_if.arqos),
        .s00_axi_aruser   (s00_axi_if.aruser),
        .s00_axi_arvalid  (s00_axi_if.arvalid),
        .s00_axi_arready  (s00_axi_if.arready),

        .s00_axi_rid      (s00_axi_if.rid),
        .s00_axi_rdata    (s00_axi_if.rdata),
        .s00_axi_rresp    (s00_axi_if.rresp),
        .s00_axi_rlast    (s00_axi_if.rlast),
        .s00_axi_ruser    (s00_axi_if.ruser),
        .s00_axi_rvalid   (s00_axi_if.rvalid),
        .s00_axi_rready   (s00_axi_if.rready),

        // ==================== salve01_port (connect vip-master) ====================
        .s01_axi_awid     (s01_axi_if.awid),
        .s01_axi_awaddr   (s01_axi_if.awaddr),
        .s01_axi_awlen    (s01_axi_if.awlen),
        .s01_axi_awsize   (s01_axi_if.awsize),
        .s01_axi_awburst  (s01_axi_if.awburst),
        .s01_axi_awlock   (s01_axi_if.awlock),
        .s01_axi_awcache  (s01_axi_if.awcache),
        .s01_axi_awprot   (s01_axi_if.awprot),
        .s01_axi_awqos    (s01_axi_if.awqos),
        .s01_axi_awuser   (s01_axi_if.awuser),
        .s01_axi_awvalid  (s01_axi_if.awvalid),
        .s01_axi_awready  (s01_axi_if.awready),

        .s01_axi_wdata    (s01_axi_if.wdata),
        .s01_axi_wstrb    (s01_axi_if.wstrb),
        .s01_axi_wlast    (s01_axi_if.wlast),
        .s01_axi_wuser    (s01_axi_if.wuser),
        .s01_axi_wvalid   (s01_axi_if.wvalid),
        .s01_axi_wready   (s01_axi_if.wready),

        .s01_axi_bid      (s01_axi_if.bid),
        .s01_axi_bresp    (s01_axi_if.bresp),
        .s01_axi_buser    (s01_axi_if.buser),
        .s01_axi_bvalid   (s01_axi_if.bvalid),
        .s01_axi_bready   (s01_axi_if.bready),

        .s01_axi_arid     (s01_axi_if.arid),
        .s01_axi_araddr   (s01_axi_if.araddr),
        .s01_axi_arlen    (s01_axi_if.arlen),
        .s01_axi_arsize   (s01_axi_if.arsize),
        .s01_axi_arburst  (s01_axi_if.arburst),
        .s01_axi_arlock   (s01_axi_if.arlock),
        .s01_axi_arcache  (s01_axi_if.arcache),
        .s01_axi_arprot   (s01_axi_if.arprot),
        .s01_axi_arqos    (s01_axi_if.arqos),
        .s01_axi_aruser   (s01_axi_if.aruser),
        .s01_axi_arvalid  (s01_axi_if.arvalid),
        .s01_axi_arready  (s01_axi_if.arready),

        .s01_axi_rid      (s01_axi_if.rid),
        .s01_axi_rdata    (s01_axi_if.rdata),
        .s01_axi_rresp    (s01_axi_if.rresp),
        .s01_axi_rlast    (s01_axi_if.rlast),
        .s01_axi_ruser    (s01_axi_if.ruser),
        .s01_axi_rvalid   (s01_axi_if.rvalid),
        .s01_axi_rready   (s01_axi_if.rready),

        // ==================== master00_port (connect vip-slave) ====================
        .m00_axi_awid     (m00_axi_if.awid),
        .m00_axi_awaddr   (m00_axi_if.awaddr),
        .m00_axi_awlen    (m00_axi_if.awlen),
        .m00_axi_awsize   (m00_axi_if.awsize),
        .m00_axi_awburst  (m00_axi_if.awburst),
        .m00_axi_awlock   (m00_axi_if.awlock),
        .m00_axi_awcache  (m00_axi_if.awcache),
        .m00_axi_awprot   (m00_axi_if.awprot),
        .m00_axi_awqos    (m00_axi_if.awqos),
        .m00_axi_awregion (m00_axi_if.awregion),
        .m00_axi_awuser   (m00_axi_if.awuser),
        .m00_axi_awvalid  (m00_axi_if.awvalid),
        .m00_axi_awready  (m00_axi_if.awready),

        .m00_axi_wdata    (m00_axi_if.wdata),
        .m00_axi_wstrb    (m00_axi_if.wstrb),
        .m00_axi_wlast    (m00_axi_if.wlast),
        .m00_axi_wuser    (m00_axi_if.wuser),
        .m00_axi_wvalid   (m00_axi_if.wvalid),
        .m00_axi_wready   (m00_axi_if.wready),

        .m00_axi_bid      (m00_axi_if.bid),
        .m00_axi_bresp    (m00_axi_if.bresp),
        .m00_axi_buser    (m00_axi_if.buser),
        .m00_axi_bvalid   (m00_axi_if.bvalid),
        .m00_axi_bready   (m00_axi_if.bready),

        .m00_axi_arid     (m00_axi_if.arid),
        .m00_axi_araddr   (m00_axi_if.araddr),
        .m00_axi_arlen    (m00_axi_if.arlen),
        .m00_axi_arsize   (m00_axi_if.arsize),
        .m00_axi_arburst  (m00_axi_if.arburst),
        .m00_axi_arlock   (m00_axi_if.arlock),
        .m00_axi_arcache  (m00_axi_if.arcache),
        .m00_axi_arprot   (m00_axi_if.arprot),
        .m00_axi_arqos    (m00_axi_if.arqos),
        .m00_axi_arregion (m00_axi_if.arregion),
        .m00_axi_aruser   (m00_axi_if.aruser),
        .m00_axi_arvalid  (m00_axi_if.arvalid),
        .m00_axi_arready  (m00_axi_if.arready),

        .m00_axi_rid      (m00_axi_if.rid),
        .m00_axi_rdata    (m00_axi_if.rdata),
        .m00_axi_rresp    (m00_axi_if.rresp),
        .m00_axi_rlast    (m00_axi_if.rlast),
        .m00_axi_ruser    (m00_axi_if.ruser),
        .m00_axi_rvalid   (m00_axi_if.rvalid),
        .m00_axi_rready   (m00_axi_if.rready),

        // ==================== master01_port (connect vip-slave) ====================
        .m01_axi_awid     (m01_axi_if.awid),
        .m01_axi_awaddr   (m01_axi_if.awaddr),
        .m01_axi_awlen    (m01_axi_if.awlen),
        .m01_axi_awsize   (m01_axi_if.awsize),
        .m01_axi_awburst  (m01_axi_if.awburst),
        .m01_axi_awlock   (m01_axi_if.awlock),
        .m01_axi_awcache  (m01_axi_if.awcache),
        .m01_axi_awprot   (m01_axi_if.awprot),
        .m01_axi_awqos    (m01_axi_if.awqos),
        .m01_axi_awregion (m01_axi_if.awregion),
        .m01_axi_awuser   (m01_axi_if.awuser),
        .m01_axi_awvalid  (m01_axi_if.awvalid),
        .m01_axi_awready  (m01_axi_if.awready),

        .m01_axi_wdata    (m01_axi_if.wdata),
        .m01_axi_wstrb    (m01_axi_if.wstrb),
        .m01_axi_wlast    (m01_axi_if.wlast),
        .m01_axi_wuser    (m01_axi_if.wuser),
        .m01_axi_wvalid   (m01_axi_if.wvalid),
        .m01_axi_wready   (m01_axi_if.wready),

        .m01_axi_bid      (m01_axi_if.bid),
        .m01_axi_bresp    (m01_axi_if.bresp),
        .m01_axi_buser    (m01_axi_if.buser),
        .m01_axi_bvalid   (m01_axi_if.bvalid),
        .m01_axi_bready   (m01_axi_if.bready),

        .m01_axi_arid     (m01_axi_if.arid),
        .m01_axi_araddr   (m01_axi_if.araddr),
        .m01_axi_arlen    (m01_axi_if.arlen),
        .m01_axi_arsize   (m01_axi_if.arsize),
        .m01_axi_arburst  (m01_axi_if.arburst),
        .m01_axi_arlock   (m01_axi_if.arlock),
        .m01_axi_arcache  (m01_axi_if.arcache),
        .m01_axi_arprot   (m01_axi_if.arprot),
        .m01_axi_arqos    (m01_axi_if.arqos),
        .m01_axi_arregion (m01_axi_if.arregion),
        .m01_axi_aruser   (m01_axi_if.aruser),
        .m01_axi_arvalid  (m01_axi_if.arvalid),
        .m01_axi_arready  (m01_axi_if.arready),

        .m01_axi_rid      (m01_axi_if.rid),
        .m01_axi_rdata    (m01_axi_if.rdata),
        .m01_axi_rresp    (m01_axi_if.rresp),
        .m01_axi_rlast    (m01_axi_if.rlast),
        .m01_axi_ruser    (m01_axi_if.ruser),
        .m01_axi_rvalid   (m01_axi_if.rvalid),
        .m01_axi_rready   (m01_axi_if.rready)
    );

    initial begin
        uvm_config_db#(virtual axi_if#(.ID_WIDTH(AXI_S_ID_WIDTH)))::set(null, "uvm_test_top.env.mst_agent00", "vif", s00_axi_if);
        uvm_config_db#(virtual axi_if#(.ID_WIDTH(AXI_S_ID_WIDTH)))::set(null, "uvm_test_top.env.mst_agent01", "vif", s01_axi_if);
        uvm_config_db#(virtual axi_if#(.ID_WIDTH(AXI_M_ID_WIDTH)))::set(null, "uvm_test_top.env.slv_agent00", "vif", m00_axi_if);
        uvm_config_db#(virtual axi_if#(.ID_WIDTH(AXI_M_ID_WIDTH)))::set(null, "uvm_test_top.env.slv_agent01", "vif", m01_axi_if);
        run_test();
    end

endmodule