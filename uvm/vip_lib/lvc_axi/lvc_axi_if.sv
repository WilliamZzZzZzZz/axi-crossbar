`ifndef LVC_AXI_IF_SV
`define LVC_AXI_IF_SV

interface lvc_axi_if #(
  parameter int ADDR_WIDTH = 32,
  parameter int DATA_WIDTH = 32,
  parameter int ID_WIDTH   = 8,
  parameter int STRB_WIDTH = DATA_WIDTH/8
)(
  input logic clk,
  input logic rst
);

  // Write Address Channel
  logic [ID_WIDTH-1:0]    awid;
  logic [ADDR_WIDTH-1:0]  awaddr;
  logic [7:0]             awlen;
  logic [2:0]             awsize;
  logic [1:0]             awburst;
  logic                   awlock;
  logic [3:0]             awcache;
  logic [2:0]             awprot;
  logic                   awvalid;
  logic                   awready;

  // Write Data Channel
  logic [DATA_WIDTH-1:0]  wdata;
  logic [STRB_WIDTH-1:0]  wstrb;
  logic                   wlast;
  logic                   wvalid;
  logic                   wready;

  // Write Response Channel
  logic [ID_WIDTH-1:0]    bid;
  logic [1:0]             bresp;
  logic                   bvalid;
  logic                   bready;

  // Read Address Channel
  logic [ID_WIDTH-1:0]    arid;
  logic [ADDR_WIDTH-1:0]  araddr;
  logic [7:0]             arlen;
  logic [2:0]             arsize;
  logic [1:0]             arburst;
  logic                   arlock;
  logic [3:0]             arcache;
  logic [2:0]             arprot;
  logic                   arvalid;
  logic                   arready;

  // Read Data Channel
  logic [ID_WIDTH-1:0]    rid;
  logic [DATA_WIDTH-1:0]  rdata;
  logic [1:0]             rresp;
  logic                   rlast;
  logic                   rvalid;
  logic                   rready;

  // Clocking block for Master driver
  clocking master_cb @(posedge clk);
    default input #1ns output #1ns;
    // Write Address Channel
    output awid, awaddr, awlen, awsize, awburst, awlock, awcache, awprot, awvalid;
    input  awready;
    // Write Data Channel
    output wdata, wstrb, wlast, wvalid;
    input  wready;
    // Write Response Channel
    input  bid, bresp, bvalid;
    output bready;
    // Read Address Channel
    output arid, araddr, arlen, arsize, arburst, arlock, arcache, arprot, arvalid;
    input  arready;
    // Read Data Channel
    input  rid, rdata, rresp, rlast, rvalid;
    output rready;
  endclocking

  // Clocking block for Monitor
  clocking monitor_cb @(posedge clk);
    default input #1ns output #1ns;
    // Write Address Channel
    input awid, awaddr, awlen, awsize, awburst, awlock, awcache, awprot, awvalid, awready;
    // Write Data Channel
    input wdata, wstrb, wlast, wvalid, wready;
    // Write Response Channel
    input bid, bresp, bvalid, bready;
    // Read Address Channel
    input arid, araddr, arlen, arsize, arburst, arlock, arcache, arprot, arvalid, arready;
    // Read Data Channel
    input rid, rdata, rresp, rlast, rvalid, rready;
  endclocking

  // Modport for Master
  modport master_mp (clocking master_cb, input clk, rst);

  // Modport for Monitor
  modport monitor_mp (clocking monitor_cb, input clk, rst);

  // Wait for clock edge
  task automatic wait_clks(int num);
    repeat(num) @(posedge clk);
  endtask

  // Wait for reset deassertion
  task automatic wait_reset_done();
    @(negedge rst);
  endtask

endinterface

`endif // LVC_AXI_IF_SV
