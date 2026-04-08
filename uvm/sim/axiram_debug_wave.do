# Basic wave setup for crossbar smoke environment

gui_load_child_values {axiram_tb}
gui_load_child_values {axiram_tb.s00_axi_if_inst}
gui_load_child_values {axiram_tb.s01_axi_if_inst}
gui_load_child_values {axiram_tb.m00_axi_if_inst}
gui_load_child_values {axiram_tb.m01_axi_if_inst}
gui_load_child_values {axiram_tb.dut}

gui_sg_create CLK_RST
set _grp_clk_rst [gui_sg_get -name CLK_RST]
gui_sg_addsignal -group "$_grp_clk_rst" { {Sim:axiram_tb.clk} {Sim:axiram_tb.rst} }

gui_sg_create S00_AXI
gui_sg_create S01_AXI
gui_sg_create M00_AXI
gui_sg_create M01_AXI

set _grp_s00 [gui_sg_get -name S00_AXI]
set _grp_s01 [gui_sg_get -name S01_AXI]
set _grp_m00 [gui_sg_get -name M00_AXI]
set _grp_m01 [gui_sg_get -name M01_AXI]

gui_sg_addsignal -group "$_grp_s00" { {Sim:axiram_tb.s00_axi_if_inst.awaddr} {Sim:axiram_tb.s00_axi_if_inst.awvalid} {Sim:axiram_tb.s00_axi_if_inst.awready} {Sim:axiram_tb.s00_axi_if_inst.wdata} {Sim:axiram_tb.s00_axi_if_inst.wvalid} {Sim:axiram_tb.s00_axi_if_inst.wready} {Sim:axiram_tb.s00_axi_if_inst.bresp} {Sim:axiram_tb.s00_axi_if_inst.bvalid} {Sim:axiram_tb.s00_axi_if_inst.araddr} {Sim:axiram_tb.s00_axi_if_inst.arvalid} {Sim:axiram_tb.s00_axi_if_inst.arready} {Sim:axiram_tb.s00_axi_if_inst.rdata} {Sim:axiram_tb.s00_axi_if_inst.rvalid} {Sim:axiram_tb.s00_axi_if_inst.rlast} }

gui_sg_addsignal -group "$_grp_s01" { {Sim:axiram_tb.s01_axi_if_inst.awaddr} {Sim:axiram_tb.s01_axi_if_inst.awvalid} {Sim:axiram_tb.s01_axi_if_inst.awready} {Sim:axiram_tb.s01_axi_if_inst.wdata} {Sim:axiram_tb.s01_axi_if_inst.wvalid} {Sim:axiram_tb.s01_axi_if_inst.wready} {Sim:axiram_tb.s01_axi_if_inst.bresp} {Sim:axiram_tb.s01_axi_if_inst.bvalid} {Sim:axiram_tb.s01_axi_if_inst.araddr} {Sim:axiram_tb.s01_axi_if_inst.arvalid} {Sim:axiram_tb.s01_axi_if_inst.arready} {Sim:axiram_tb.s01_axi_if_inst.rdata} {Sim:axiram_tb.s01_axi_if_inst.rvalid} {Sim:axiram_tb.s01_axi_if_inst.rlast} }

gui_sg_addsignal -group "$_grp_m00" { {Sim:axiram_tb.m00_axi_if_inst.awaddr} {Sim:axiram_tb.m00_axi_if_inst.awvalid} {Sim:axiram_tb.m00_axi_if_inst.awready} {Sim:axiram_tb.m00_axi_if_inst.wdata} {Sim:axiram_tb.m00_axi_if_inst.wvalid} {Sim:axiram_tb.m00_axi_if_inst.wready} {Sim:axiram_tb.m00_axi_if_inst.bresp} {Sim:axiram_tb.m00_axi_if_inst.bvalid} {Sim:axiram_tb.m00_axi_if_inst.araddr} {Sim:axiram_tb.m00_axi_if_inst.arvalid} {Sim:axiram_tb.m00_axi_if_inst.arready} {Sim:axiram_tb.m00_axi_if_inst.rdata} {Sim:axiram_tb.m00_axi_if_inst.rvalid} {Sim:axiram_tb.m00_axi_if_inst.rlast} }

gui_sg_addsignal -group "$_grp_m01" { {Sim:axiram_tb.m01_axi_if_inst.awaddr} {Sim:axiram_tb.m01_axi_if_inst.awvalid} {Sim:axiram_tb.m01_axi_if_inst.awready} {Sim:axiram_tb.m01_axi_if_inst.wdata} {Sim:axiram_tb.m01_axi_if_inst.wvalid} {Sim:axiram_tb.m01_axi_if_inst.wready} {Sim:axiram_tb.m01_axi_if_inst.bresp} {Sim:axiram_tb.m01_axi_if_inst.bvalid} {Sim:axiram_tb.m01_axi_if_inst.araddr} {Sim:axiram_tb.m01_axi_if_inst.arvalid} {Sim:axiram_tb.m01_axi_if_inst.arready} {Sim:axiram_tb.m01_axi_if_inst.rdata} {Sim:axiram_tb.m01_axi_if_inst.rvalid} {Sim:axiram_tb.m01_axi_if_inst.rlast} }
