`timescale 1ns/1ps

module rkv_axiram_tb;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import lvc_axi_pkg::*;
  import rkv_axiram_pkg::*;

  // Parameters matching DUT
  parameter DATA_WIDTH = 32;
  parameter ADDR_WIDTH = 16;
  parameter STRB_WIDTH = DATA_WIDTH/8;
  parameter ID_WIDTH   = 8;

  // Clock and reset signals
  logic clk;
  logic rst;

  // Clock generation
  initial begin
    clk = 0;
    forever #5ns clk = ~clk; // 100MHz clock
  end

  // Reset generation
  initial begin
    rst = 1'b1;
    repeat(20) @(posedge clk);
    rst = 1'b0;
  end

  // DUT instantiation
  axi_ram #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .STRB_WIDTH(STRB_WIDTH),
    .ID_WIDTH(ID_WIDTH),
    .PIPELINE_OUTPUT(0)
  ) dut (
    .clk(clk),
    .rst(rst),
    // Write Address Channel
    .s_axi_awid(axi_if.awid),
    .s_axi_awaddr(axi_if.awaddr),
    .s_axi_awlen(axi_if.awlen),
    .s_axi_awsize(axi_if.awsize),
    .s_axi_awburst(axi_if.awburst),
    .s_axi_awlock(axi_if.awlock),
    .s_axi_awcache(axi_if.awcache),
    .s_axi_awprot(axi_if.awprot),
    .s_axi_awvalid(axi_if.awvalid),
    .s_axi_awready(axi_if.awready),
    // Write Data Channel
    .s_axi_wdata(axi_if.wdata),
    .s_axi_wstrb(axi_if.wstrb),
    .s_axi_wlast(axi_if.wlast),
    .s_axi_wvalid(axi_if.wvalid),
    .s_axi_wready(axi_if.wready),
    // Write Response Channel
    .s_axi_bid(axi_if.bid),
    .s_axi_bresp(axi_if.bresp),
    .s_axi_bvalid(axi_if.bvalid),
    .s_axi_bready(axi_if.bready),
    // Read Address Channel
    .s_axi_arid(axi_if.arid),
    .s_axi_araddr(axi_if.araddr),
    .s_axi_arlen(axi_if.arlen),
    .s_axi_arsize(axi_if.arsize),
    .s_axi_arburst(axi_if.arburst),
    .s_axi_arlock(axi_if.arlock),
    .s_axi_arcache(axi_if.arcache),
    .s_axi_arprot(axi_if.arprot),
    .s_axi_arvalid(axi_if.arvalid),
    .s_axi_arready(axi_if.arready),
    // Read Data Channel
    .s_axi_rid(axi_if.rid),
    .s_axi_rdata(axi_if.rdata),
    .s_axi_rresp(axi_if.rresp),
    .s_axi_rlast(axi_if.rlast),
    .s_axi_rvalid(axi_if.rvalid),
    .s_axi_rready(axi_if.rready)
  );

  // AXI Interface instantiation
  lvc_axi_if #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .ID_WIDTH(ID_WIDTH),
    .STRB_WIDTH(STRB_WIDTH)
  ) axi_if (
    .clk(clk),
    .rst(rst)
  );

  // TB Interface instantiation
  rkv_axiram_if axiram_if();
  
  // Connect TB interface signals
  assign axiram_if.clk = clk;
  assign axiram_if.rst = rst;

  // UVM configuration and test start
  initial begin
    // Set AXI interface
    uvm_config_db#(virtual lvc_axi_if)::set(uvm_root::get(), "uvm_test_top.env.axi_mst", "vif", axi_if);
    
    // Set TB interface
    uvm_config_db#(virtual rkv_axiram_if)::set(uvm_root::get(), "uvm_test_top", "vif", axiram_if);
    uvm_config_db#(virtual rkv_axiram_if)::set(uvm_root::get(), "uvm_test_top.env", "vif", axiram_if);
    uvm_config_db#(virtual rkv_axiram_if)::set(uvm_root::get(), "uvm_test_top.env.virt_sqr", "vif", axiram_if);
    
    // Run test
    run_test();
  end

  // Waveform dump
  initial begin
    $dumpfile("axiram_tb.vcd");
    $dumpvars(0, rkv_axiram_tb);
  end

endmodule
