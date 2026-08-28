`ifndef AXI_CONFIG_SV
`define AXI_CONFIG_SV

class axi_configuration extends uvm_object;

    `uvm_object_utils(axi_configuration)

    int data_width = 32;
    int strb_width = 4;
    int addr_width = 32;

    int handshake_timeout_cycles = 500;
    int idle_timeout_cycles = 5000;     //for slave AW and AR channel
    int unsigned slv_b_resp_delay_cycles[S_COUNT];  //delay for testing dut's write outstanding depth
    int unsigned slv_r_resp_delay_cycles[S_COUNT];  //delay for testing dut's read outstanding depth

    // Must match the two address regions instantiated in axi_crossbar_tb.
    bit [ADDR_WIDTH-1:0] slv_base_addr[S_COUNT];
    int unsigned        slv_addr_width[S_COUNT];

    function new(string name = "axi_configuration");
        super.new(name);
        slv_base_addr[0] = 32'h0000_0000;
        slv_base_addr[1] = 32'h0001_0000;
        slv_addr_width[0] = 16;
        slv_addr_width[1] = 16;
    endfunction

endclass

`endif
