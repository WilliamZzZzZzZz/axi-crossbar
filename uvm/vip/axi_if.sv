`ifndef AXI_IF_SV
`define AXI_IF_SV

//------------------------------------------------------------------------------
// AXI4 Interface
// Description: AXI4 interface for connecting master and slave devices
//------------------------------------------------------------------------------

interface axi_if #(
    parameter int DATA_WIDTH    = 32,
    parameter int ADDR_WIDTH    = 32,
    parameter int ID_WIDTH      = 8,
    parameter int STRB_WIDTH    = (DATA_WIDTH/8),

    parameter int QOS_WIDTH     = 4,
    parameter int REGION_WIDTH  = 4,
    
    parameter int AWUSER_WIDTH  = 1,
    parameter int WUSER_WIDTH   = 1,
    parameter int BUSER_WIDTH   = 1,
    parameter int ARUSER_WIDTH  = 1,
    parameter int RUSER_WIDTH   = 1
)(
    input logic aclk,
    input logic arst
);

    //--------------------------------------------------------------------------
    // Write Address Channel (AW)
    //--------------------------------------------------------------------------
    logic [ID_WIDTH-1:0]        awid;      // Write address ID
    logic [ADDR_WIDTH-1:0]      awaddr;    // Write address
    logic [7:0]                 awlen;     // Burst length (number of transfers)
    logic [2:0]                 awsize;    // Burst size (bytes per transfer)
    logic [1:0]                 awburst;   // Burst type (FIXED, INCR, WRAP)
    logic                       awlock;    // Lock type (atomic access)
    logic [3:0]                 awcache;   // Cache type
    logic [2:0]                 awprot;    // Protection type
    logic [QOS_WIDTH-1:0]       awqos;
    logic [REGION_WIDTH-1:0]    awregion;
    logic [AWUSER_WIDTH-1:0]    awuser;
    logic                       awvalid;   // Write address valid
    logic                       awready;   // Write address ready

    //--------------------------------------------------------------------------
    // Write Data Channel (W)
    //--------------------------------------------------------------------------
    logic [DATA_WIDTH-1:0]      wdata;     // Write data
    logic [STRB_WIDTH-1:0]      wstrb;     // Write strobes (byte enable)
    logic [WUSER_WIDTH-1:0]     wuser;
    logic                       wlast;     // Write last (last transfer in burst)
    logic                       wvalid;    // Write valid
    logic                       wready;    // Write ready

    //--------------------------------------------------------------------------
    // Write Response Channel (B)
    //--------------------------------------------------------------------------
    logic [ID_WIDTH-1:0]        bid;       // Response ID
    logic [1:0]                 bresp;     // Write response (OKAY, EXOKAY, SLVERR, DECERR)
    logic [BUSER_WIDTH-1:0]     buser;
    logic                       bvalid;    // Write response valid
    logic                       bready;    // Write response ready

    //--------------------------------------------------------------------------
    // Read Address Channel (AR)
    //--------------------------------------------------------------------------
    logic [ID_WIDTH-1:0]        arid;      // Read address ID
    logic [ADDR_WIDTH-1:0]      araddr;    // Read address
    logic [7:0]                 arlen;     // Burst length
    logic [2:0]                 arsize;    // Burst size
    logic [1:0]                 arburst;   // Burst type
    logic                       arlock;    // Lock type
    logic [3:0]                 arcache;   // Cache type
    logic [2:0]                 arprot;    // Protection type
    logic [QOS_WIDTH-1:0]       arqos;
    logic [REGION_WIDTH-1:0]    arregion;
    logic [ARUSER_WIDTH-1:0]    aruser;
    logic                       arvalid;   // Read address valid
    logic                       arready;   // Read address ready

    //--------------------------------------------------------------------------
    // Read Data Channel (R)
    //--------------------------------------------------------------------------
    logic [ID_WIDTH-1:0]        rid;       // Read ID
    logic [DATA_WIDTH-1:0]      rdata;     // Read data
    logic [1:0]                 rresp;     // Read response
    logic                       rlast;     // Read last
    logic [RUSER_WIDTH-1:0]    ruser;
    logic                       rvalid;    // Read valid
    logic                       rready;    // Read ready

    //--------------------------------------------------------------------------
    // Clocking Blocks for Master and Slave
    //--------------------------------------------------------------------------
    
    // Master clocking block - used by master driver
    clocking master_cb @(posedge aclk);
        default input #1ns output #1ns;
        
        //AW
        output awid, awaddr, awlen, awsize, awburst, awlock, awcache, awprot, awvalid;
        output awqos, awregion, awuser;
        input  awready;
        //W
        output wdata, wstrb, wlast, wvalid;
        output wuser;
        input  wready;
        //B
        input bid, bresp, bvalid;
        input buser;
        output bready;
        
        //AR
        output arid, araddr, arlen, arsize, arburst, arlock, arcache, arprot, arvalid;
        output arqos, arregion, aruser;
        input  arready;
        //R
        input rid, rdata, rresp, rlast, rvalid;
        input ruser;
        output rready;
    endclocking

    // Slave clocking block - used by slave driver (if needed)
    clocking slave_cb @(posedge aclk);
        default input #1ns output #1ns;
        
        //AW
        input awid, awaddr, awlen, awsize, awburst, awlock, awcache, awprot, awvalid;
        input awqos, awregion, awuser;
        output awready;
        //W
        input wdata, wstrb, wlast, wvalid;
        input wuser;
        output wready;
        //B
        output bid, bresp, bvalid;
        output buser;
        input  bready;
        
        //AR
        input arid, araddr, arlen, arsize, arburst, arlock, arcache, arprot, arvalid;
        input arqos, arregion, aruser;
        output arready;
        //R
        output rid, rdata, rresp, rlast, rvalid;
        output ruser;
        input rready;
    endclocking

    // Monitor clocking block - used by monitor (samples all signals)
    clocking monitor_cb @(posedge aclk);
        default input #1ns output #1ns;
        //AW
        input awid, awaddr, awlen, awsize, awburst, awlock, awcache, awprot, awvalid, awready;
        input awqos, awregion, awuser;
        //W
        input wdata, wstrb, wlast, wvalid, wready;
        input wuser;
        //B
        input bid, bresp, bvalid, bready;
        input buser;
        //AR
        input arid, araddr, arlen, arsize, arburst, arlock, arcache, arprot, arvalid, arready;
        input arqos, arregion, aruser;
        //R
        input rid, rdata, rresp, rlast, rvalid, rready;
        input ruser;
    endclocking

    //--------------------------------------------------------------------------
    // Modports
    //--------------------------------------------------------------------------
    
    // Master modport - for master agent/driver
    modport master (
        clocking master_cb,
        input aclk, arst
    );

    // Slave modport - for slave agent/driver
    modport slave (
        clocking slave_cb,
        input aclk, arst
    );

    // Monitor modport - for monitor
    modport monitor (
        clocking monitor_cb,
        input aclk, arst,
        input awid, awaddr, awlen, awsize, awburst, awlock, awcache, awprot,
        input awqos, awregion, awuser, awvalid, awready,
        input wdata, wstrb, wlast, wuser, wvalid, wready,
        input bid, bresp, buser, bvalid, bready,
        input arid, araddr, arlen, arsize, arburst, arlock, arcache, arprot,
        input arqos, arregion, aruser, arvalid, arready,
        input rid, rdata, rresp, rlast, ruser, rvalid, rready
    );

    // Passive monitor modport - for passive monitoring
    modport passive (
        input aclk, arst,
        input awid, awaddr, awlen, awsize, awburst, awlock, awcache, awprot,
        input awqos, awregion, awuser, awvalid, awready,
        input wdata, wstrb, wlast, wuser, wvalid, wready,
        input bid, bresp, buser, bvalid, bready,
        input arid, araddr, arlen, arsize, arburst, arlock, arcache, arprot,
        input arqos, arregion, aruser, arvalid, arready,
        input rid, rdata, rresp, rlast, ruser, rvalid, rready
    );

    //--------------------------------------------------------------------------
    // Assertions for Protocol Checking
    //--------------------------------------------------------------------------
    
    // Write address channel stability
    property p_awvalid_stable;
        @(posedge aclk) disable iff (arst)
        (awvalid && !awready) |=> $stable(awid) && $stable(awaddr) && 
                                   $stable(awlen) && $stable(awsize) && 
                                   $stable(awburst) && $stable(awvalid);
    endproperty
    assert property (p_awvalid_stable) else 
        $error("AXI Protocol Violation: Write address channel signals must remain stable when awvalid is high and awready is low");

    // Write data channel stability
    property p_wvalid_stable;
        @(posedge aclk) disable iff (arst)
        (wvalid && !wready) |=> $stable(wdata) && $stable(wstrb) && 
                                $stable(wlast) && $stable(wvalid);
    endproperty
    assert property (p_wvalid_stable) else 
        $error("AXI Protocol Violation: Write data channel signals must remain stable when wvalid is high and wready is low");

    // Read address channel stability
    property p_arvalid_stable;
        @(posedge aclk) disable iff (arst)
        (arvalid && !arready) |=> $stable(arid) && $stable(araddr) && 
                                   $stable(arlen) && $stable(arsize) && 
                                   $stable(arburst) && $stable(arvalid);
    endproperty
    assert property (p_arvalid_stable) else 
        $error("AXI Protocol Violation: Read address channel signals must remain stable when arvalid is high and arready is low");

    // Write response channel stability
    property p_bvalid_stable;
        @(posedge aclk) disable iff (arst)
        (bvalid && !bready) |=> $stable(bid) && $stable(bresp) && $stable(bvalid);
    endproperty
    assert property (p_bvalid_stable) else 
        $error("AXI Protocol Violation: Write response channel signals must remain stable when bvalid is high and bready is low");

    // Read data channel stability
    property p_rvalid_stable;
        @(posedge aclk) disable iff (arst)
        (rvalid && !rready) |=> $stable(rid) && $stable(rdata) && 
                                $stable(rresp) && $stable(rlast) && $stable(rvalid);
    endproperty
    assert property (p_rvalid_stable) else 
        $error("AXI Protocol Violation: Read data channel signals must remain stable when rvalid is high and rready is low");

    //--------------------------------------------------------------------------
    // Utility Tasks and Functions
    //--------------------------------------------------------------------------
    
    // Reset all signals
    task automatic reset_master_signals();
        awid     <= '0;
        awaddr   <= '0;
        awlen    <= '0;
        awsize   <= '0;
        awburst  <= '0;
        awlock   <= '0;
        awcache  <= '0;
        awprot   <= '0;
        awqos    <= '0;
        awregion <= '0;
        awuser   <= '0;
        awvalid  <= '0;

        wdata    <= '0;
        wstrb    <= '0;
        wlast    <= '0;
        wuser    <= '0;
        wvalid   <= '0;

        bready   <= '0;

        arid     <= '0;
        araddr   <= '0;
        arlen    <= '0;
        arsize   <= '0;
        arburst  <= '0;
        arlock   <= '0;
        arcache  <= '0;
        arprot   <= '0;
        arqos    <= '0;
        arregion <= '0;
        aruser   <= '0;
        arvalid  <= '0;

        rready   <= '0;
    endtask

    task automatic reset_slave_signals();
        awready  <= '0;
        wready   <= '0;

        bid      <= '0;
        bresp    <= '0;
        buser    <= '0;
        bvalid   <= '0;

        arready  <= '0;

        rid      <= '0;
        rdata    <= '0;
        rresp    <= '0;
        rlast    <= '0;
        ruser    <= '0;
        rvalid   <= '0;
    endtask    

    // Wait for specified number of clock cycles
    task automatic wait_clks(int num);
        repeat(num) @(posedge aclk);
    endtask

    //force arst HIGH, it can override driver
    task automatic assert_reset();
        force arst = 1'b1;
    endtask

    //release arst->0
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