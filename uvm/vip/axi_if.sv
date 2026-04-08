`ifndef AXI_IF_SV
`define AXI_IF_SV

//------------------------------------------------------------------------------
// AXI4 Interface
//------------------------------------------------------------------------------
interface axi_if #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter ID_WIDTH   = 16,
    parameter STRB_WIDTH = (DATA_WIDTH/8),
    parameter AWUSER_WIDTH = 1,
    parameter WUSER_WIDTH  = 1,
    parameter BUSER_WIDTH  = 1,
    parameter ARUSER_WIDTH = 1,
    parameter RUSER_WIDTH  = 1
)(
    input logic aclk,
    input logic arst
);

    // Write address channel
    logic [ID_WIDTH-1:0]   awid;
    logic [ADDR_WIDTH-1:0] awaddr;
    logic [7:0]            awlen;
    logic [2:0]            awsize;
    logic [1:0]            awburst;
    logic                  awlock;
    logic [3:0]            awcache;
    logic [2:0]            awprot;
    logic [3:0]            awqos;
    logic [AWUSER_WIDTH-1:0] awuser;
    logic                  awvalid;
    logic                  awready;

    // Write data channel
    logic [DATA_WIDTH-1:0] wdata;
    logic [STRB_WIDTH-1:0] wstrb;
    logic                  wlast;
    logic [WUSER_WIDTH-1:0] wuser;
    logic                  wvalid;
    logic                  wready;

    // Write response channel
    logic [ID_WIDTH-1:0]   bid;
    logic [1:0]            bresp;
    logic [BUSER_WIDTH-1:0] buser;
    logic                  bvalid;
    logic                  bready;

    // Read address channel
    logic [ID_WIDTH-1:0]   arid;
    logic [ADDR_WIDTH-1:0] araddr;
    logic [7:0]            arlen;
    logic [2:0]            arsize;
    logic [1:0]            arburst;
    logic                  arlock;
    logic [3:0]            arcache;
    logic [2:0]            arprot;
    logic [3:0]            arqos;
    logic [ARUSER_WIDTH-1:0] aruser;
    logic                  arvalid;
    logic                  arready;

    // Read data channel
    logic [ID_WIDTH-1:0]   rid;
    logic [DATA_WIDTH-1:0] rdata;
    logic [1:0]            rresp;
    logic                  rlast;
    logic [RUSER_WIDTH-1:0] ruser;
    logic                  rvalid;
    logic                  rready;

    // Master clocking block
    clocking master_cb @(posedge aclk);
        default input #1ns output #1ns;

        output awid, awaddr, awlen, awsize, awburst, awlock, awcache, awprot, awqos, awuser, awvalid;
        input  awready;

        output wdata, wstrb, wlast, wuser, wvalid;
        input  wready;

        input  bid, bresp, buser, bvalid;
        output bready;

        output arid, araddr, arlen, arsize, arburst, arlock, arcache, arprot, arqos, aruser, arvalid;
        input  arready;

        input  rid, rdata, rresp, rlast, ruser, rvalid;
        output rready;
    endclocking

    // Slave clocking block
    clocking slave_cb @(posedge aclk);
        default input #1ns output #1ns;

        input  awid, awaddr, awlen, awsize, awburst, awlock, awcache, awprot, awqos, awuser, awvalid;
        output awready;

        input  wdata, wstrb, wlast, wuser, wvalid;
        output wready;

        output bid, bresp, buser, bvalid;
        input  bready;

        input  arid, araddr, arlen, arsize, arburst, arlock, arcache, arprot, arqos, aruser, arvalid;
        output arready;

        output rid, rdata, rresp, rlast, ruser, rvalid;
        input  rready;
    endclocking

    // Monitor clocking block
    clocking monitor_cb @(posedge aclk);
        default input #1ns output #1ns;

        input awid, awaddr, awlen, awsize, awburst, awlock, awcache, awprot, awqos, awuser, awvalid, awready;
        input wdata, wstrb, wlast, wuser, wvalid, wready;
        input bid, bresp, buser, bvalid, bready;
        input arid, araddr, arlen, arsize, arburst, arlock, arcache, arprot, arqos, aruser, arvalid, arready;
        input rid, rdata, rresp, rlast, ruser, rvalid, rready;
    endclocking

    modport master (
        clocking master_cb,
        input aclk, arst
    );

    modport slave (
        clocking slave_cb,
        input aclk, arst
    );

    modport monitor (
        clocking monitor_cb,
        input aclk, arst,
        input awid, awaddr, awlen, awsize, awburst, awlock, awcache, awprot, awqos, awuser, awvalid, awready,
        input wdata, wstrb, wlast, wuser, wvalid, wready,
        input bid, bresp, buser, bvalid, bready,
        input arid, araddr, arlen, arsize, arburst, arlock, arcache, arprot, arqos, aruser, arvalid, arready,
        input rid, rdata, rresp, rlast, ruser, rvalid, rready
    );

    modport passive (
        input aclk, arst,
        input awid, awaddr, awlen, awsize, awburst, awlock, awcache, awprot, awqos, awuser, awvalid, awready,
        input wdata, wstrb, wlast, wuser, wvalid, wready,
        input bid, bresp, buser, bvalid, bready,
        input arid, araddr, arlen, arsize, arburst, arlock, arcache, arprot, arqos, aruser, arvalid, arready,
        input rid, rdata, rresp, rlast, ruser, rvalid, rready
    );

    // Write address channel stability
    property p_awvalid_stable;
        @(posedge aclk) disable iff (arst)
        (awvalid && !awready) |=>
            $stable(awid) && $stable(awaddr) && $stable(awlen) && $stable(awsize) &&
            $stable(awburst) && $stable(awprot) && $stable(awqos) && $stable(awuser) &&
            $stable(awvalid);
    endproperty
    assert property (p_awvalid_stable) else
        $error("AXI violation: AW channel changed while waiting for handshake");

    // Write data channel stability
    property p_wvalid_stable;
        @(posedge aclk) disable iff (arst)
        (wvalid && !wready) |=> $stable(wdata) && $stable(wstrb) && $stable(wlast) && $stable(wuser) && $stable(wvalid);
    endproperty
    assert property (p_wvalid_stable) else
        $error("AXI violation: W channel changed while waiting for handshake");

    // Read address channel stability
    property p_arvalid_stable;
        @(posedge aclk) disable iff (arst)
        (arvalid && !arready) |=>
            $stable(arid) && $stable(araddr) && $stable(arlen) && $stable(arsize) &&
            $stable(arburst) && $stable(arprot) && $stable(arqos) && $stable(aruser) &&
            $stable(arvalid);
    endproperty
    assert property (p_arvalid_stable) else
        $error("AXI violation: AR channel changed while waiting for handshake");

    // Write response channel stability
    property p_bvalid_stable;
        @(posedge aclk) disable iff (arst)
        (bvalid && !bready) |=> $stable(bid) && $stable(bresp) && $stable(buser) && $stable(bvalid);
    endproperty
    assert property (p_bvalid_stable) else
        $error("AXI violation: B channel changed while waiting for handshake");

    // Read data channel stability
    property p_rvalid_stable;
        @(posedge aclk) disable iff (arst)
        (rvalid && !rready) |=> $stable(rid) && $stable(rdata) && $stable(rresp) &&
                                $stable(rlast) && $stable(ruser) && $stable(rvalid);
    endproperty
    assert property (p_rvalid_stable) else
        $error("AXI violation: R channel changed while waiting for handshake");

    task automatic reset_signals();
        awid    <= '0;
        awaddr  <= '0;
        awlen   <= '0;
        awsize  <= '0;
        awburst <= '0;
        awlock  <= '0;
        awcache <= '0;
        awprot  <= '0;
        awqos   <= '0;
        awuser  <= '0;
        awvalid <= '0;

        wdata   <= '0;
        wstrb   <= '0;
        wlast   <= '0;
        wuser   <= '0;
        wvalid  <= '0;

        bready  <= '0;

        arid    <= '0;
        araddr  <= '0;
        arlen   <= '0;
        arsize  <= '0;
        arburst <= '0;
        arlock  <= '0;
        arcache <= '0;
        arprot  <= '0;
        arqos   <= '0;
        aruser  <= '0;
        arvalid <= '0;

        rready  <= '0;
    endtask

    task automatic wait_clks(int num);
        repeat(num) @(posedge aclk);
    endtask

    task automatic assert_reset();
        force arst = 1'b1;
    endtask

    task automatic deassert_reset();
        release arst;
    endtask

    task automatic do_reset(int num_cycles = 5);
        force arst = 1'b1;
        repeat(num_cycles) @(posedge aclk);
        release arst;
        @(posedge aclk);
    endtask

endinterface : axi_if

`endif
