# Default DVE wave layout for the axi_crossbar UVM environment.

gui_set_time_units 1ps

gui_load_child_values {axi_crossbar_tb}
gui_load_child_values {axi_crossbar_tb.s00_axi_if}
gui_load_child_values {axi_crossbar_tb.s01_axi_if}
gui_load_child_values {axi_crossbar_tb.m00_axi_if}
gui_load_child_values {axi_crossbar_tb.m01_axi_if}
gui_load_child_values {axi_crossbar_tb.dut}

set _wave_session_group_1 global
if {[gui_sg_is_group -name "$_wave_session_group_1"]} {
    set _wave_session_group_1 [gui_sg_generate_new_name]
}
set Group1 "$_wave_session_group_1"
gui_sg_addsignal -group "$_wave_session_group_1" {
    {Sim:axi_crossbar_tb.clk}
    {Sim:axi_crossbar_tb.rst}
}

set _wave_session_group_2 s00_axi_upstream
if {[gui_sg_is_group -name "$_wave_session_group_2"]} {
    set _wave_session_group_2 [gui_sg_generate_new_name]
}
set Group2 "$_wave_session_group_2"
gui_sg_addsignal -group "$_wave_session_group_2" {
    {Sim:axi_crossbar_tb.s00_axi_if.awid}
    {Sim:axi_crossbar_tb.s00_axi_if.awaddr}
    {Sim:axi_crossbar_tb.s00_axi_if.awlen}
    {Sim:axi_crossbar_tb.s00_axi_if.awsize}
    {Sim:axi_crossbar_tb.s00_axi_if.awburst}
    {Sim:axi_crossbar_tb.s00_axi_if.awvalid}
    {Sim:axi_crossbar_tb.s00_axi_if.awready}
    {Sim:axi_crossbar_tb.s00_axi_if.wdata}
    {Sim:axi_crossbar_tb.s00_axi_if.wstrb}
    {Sim:axi_crossbar_tb.s00_axi_if.wlast}
    {Sim:axi_crossbar_tb.s00_axi_if.wvalid}
    {Sim:axi_crossbar_tb.s00_axi_if.wready}
    {Sim:axi_crossbar_tb.s00_axi_if.bid}
    {Sim:axi_crossbar_tb.s00_axi_if.bresp}
    {Sim:axi_crossbar_tb.s00_axi_if.bvalid}
    {Sim:axi_crossbar_tb.s00_axi_if.bready}
    {Sim:axi_crossbar_tb.s00_axi_if.arid}
    {Sim:axi_crossbar_tb.s00_axi_if.araddr}
    {Sim:axi_crossbar_tb.s00_axi_if.arlen}
    {Sim:axi_crossbar_tb.s00_axi_if.arsize}
    {Sim:axi_crossbar_tb.s00_axi_if.arburst}
    {Sim:axi_crossbar_tb.s00_axi_if.arvalid}
    {Sim:axi_crossbar_tb.s00_axi_if.arready}
    {Sim:axi_crossbar_tb.s00_axi_if.rid}
    {Sim:axi_crossbar_tb.s00_axi_if.rdata}
    {Sim:axi_crossbar_tb.s00_axi_if.rresp}
    {Sim:axi_crossbar_tb.s00_axi_if.rlast}
    {Sim:axi_crossbar_tb.s00_axi_if.rvalid}
    {Sim:axi_crossbar_tb.s00_axi_if.rready}
}

set _wave_session_group_3 m00_axi_downstream
if {[gui_sg_is_group -name "$_wave_session_group_3"]} {
    set _wave_session_group_3 [gui_sg_generate_new_name]
}
set Group3 "$_wave_session_group_3"
gui_sg_addsignal -group "$_wave_session_group_3" {
    {Sim:axi_crossbar_tb.m00_axi_if.awid}
    {Sim:axi_crossbar_tb.m00_axi_if.awaddr}
    {Sim:axi_crossbar_tb.m00_axi_if.awlen}
    {Sim:axi_crossbar_tb.m00_axi_if.awsize}
    {Sim:axi_crossbar_tb.m00_axi_if.awburst}
    {Sim:axi_crossbar_tb.m00_axi_if.awvalid}
    {Sim:axi_crossbar_tb.m00_axi_if.awready}
    {Sim:axi_crossbar_tb.m00_axi_if.wdata}
    {Sim:axi_crossbar_tb.m00_axi_if.wstrb}
    {Sim:axi_crossbar_tb.m00_axi_if.wlast}
    {Sim:axi_crossbar_tb.m00_axi_if.wvalid}
    {Sim:axi_crossbar_tb.m00_axi_if.wready}
    {Sim:axi_crossbar_tb.m00_axi_if.bid}
    {Sim:axi_crossbar_tb.m00_axi_if.bresp}
    {Sim:axi_crossbar_tb.m00_axi_if.bvalid}
    {Sim:axi_crossbar_tb.m00_axi_if.bready}
    {Sim:axi_crossbar_tb.m00_axi_if.arid}
    {Sim:axi_crossbar_tb.m00_axi_if.araddr}
    {Sim:axi_crossbar_tb.m00_axi_if.arlen}
    {Sim:axi_crossbar_tb.m00_axi_if.arsize}
    {Sim:axi_crossbar_tb.m00_axi_if.arburst}
    {Sim:axi_crossbar_tb.m00_axi_if.arvalid}
    {Sim:axi_crossbar_tb.m00_axi_if.arready}
    {Sim:axi_crossbar_tb.m00_axi_if.rid}
    {Sim:axi_crossbar_tb.m00_axi_if.rdata}
    {Sim:axi_crossbar_tb.m00_axi_if.rresp}
    {Sim:axi_crossbar_tb.m00_axi_if.rlast}
    {Sim:axi_crossbar_tb.m00_axi_if.rvalid}
    {Sim:axi_crossbar_tb.m00_axi_if.rready}
}

set _wave_session_group_4 s01_axi_upstream
if {[gui_sg_is_group -name "$_wave_session_group_4"]} {
    set _wave_session_group_4 [gui_sg_generate_new_name]
}
set Group4 "$_wave_session_group_4"
gui_sg_addsignal -group "$_wave_session_group_4" {
    {Sim:axi_crossbar_tb.s01_axi_if.awid}
    {Sim:axi_crossbar_tb.s01_axi_if.awaddr}
    {Sim:axi_crossbar_tb.s01_axi_if.awlen}
    {Sim:axi_crossbar_tb.s01_axi_if.awsize}
    {Sim:axi_crossbar_tb.s01_axi_if.awburst}
    {Sim:axi_crossbar_tb.s01_axi_if.awvalid}
    {Sim:axi_crossbar_tb.s01_axi_if.awready}
    {Sim:axi_crossbar_tb.s01_axi_if.wdata}
    {Sim:axi_crossbar_tb.s01_axi_if.wstrb}
    {Sim:axi_crossbar_tb.s01_axi_if.wlast}
    {Sim:axi_crossbar_tb.s01_axi_if.wvalid}
    {Sim:axi_crossbar_tb.s01_axi_if.wready}
    {Sim:axi_crossbar_tb.s01_axi_if.bid}
    {Sim:axi_crossbar_tb.s01_axi_if.bresp}
    {Sim:axi_crossbar_tb.s01_axi_if.bvalid}
    {Sim:axi_crossbar_tb.s01_axi_if.bready}
    {Sim:axi_crossbar_tb.s01_axi_if.arid}
    {Sim:axi_crossbar_tb.s01_axi_if.araddr}
    {Sim:axi_crossbar_tb.s01_axi_if.arlen}
    {Sim:axi_crossbar_tb.s01_axi_if.arsize}
    {Sim:axi_crossbar_tb.s01_axi_if.arburst}
    {Sim:axi_crossbar_tb.s01_axi_if.arvalid}
    {Sim:axi_crossbar_tb.s01_axi_if.arready}
    {Sim:axi_crossbar_tb.s01_axi_if.rid}
    {Sim:axi_crossbar_tb.s01_axi_if.rdata}
    {Sim:axi_crossbar_tb.s01_axi_if.rresp}
    {Sim:axi_crossbar_tb.s01_axi_if.rlast}
    {Sim:axi_crossbar_tb.s01_axi_if.rvalid}
    {Sim:axi_crossbar_tb.s01_axi_if.rready}
}

set _wave_session_group_5 m01_axi_downstream
if {[gui_sg_is_group -name "$_wave_session_group_5"]} {
    set _wave_session_group_5 [gui_sg_generate_new_name]
}
set Group5 "$_wave_session_group_5"
gui_sg_addsignal -group "$_wave_session_group_5" {
    {Sim:axi_crossbar_tb.m01_axi_if.awid}
    {Sim:axi_crossbar_tb.m01_axi_if.awaddr}
    {Sim:axi_crossbar_tb.m01_axi_if.awlen}
    {Sim:axi_crossbar_tb.m01_axi_if.awsize}
    {Sim:axi_crossbar_tb.m01_axi_if.awburst}
    {Sim:axi_crossbar_tb.m01_axi_if.awvalid}
    {Sim:axi_crossbar_tb.m01_axi_if.awready}
    {Sim:axi_crossbar_tb.m01_axi_if.wdata}
    {Sim:axi_crossbar_tb.m01_axi_if.wstrb}
    {Sim:axi_crossbar_tb.m01_axi_if.wlast}
    {Sim:axi_crossbar_tb.m01_axi_if.wvalid}
    {Sim:axi_crossbar_tb.m01_axi_if.wready}
    {Sim:axi_crossbar_tb.m01_axi_if.bid}
    {Sim:axi_crossbar_tb.m01_axi_if.bresp}
    {Sim:axi_crossbar_tb.m01_axi_if.bvalid}
    {Sim:axi_crossbar_tb.m01_axi_if.bready}
    {Sim:axi_crossbar_tb.m01_axi_if.arid}
    {Sim:axi_crossbar_tb.m01_axi_if.araddr}
    {Sim:axi_crossbar_tb.m01_axi_if.arlen}
    {Sim:axi_crossbar_tb.m01_axi_if.arsize}
    {Sim:axi_crossbar_tb.m01_axi_if.arburst}
    {Sim:axi_crossbar_tb.m01_axi_if.arvalid}
    {Sim:axi_crossbar_tb.m01_axi_if.arready}
    {Sim:axi_crossbar_tb.m01_axi_if.rid}
    {Sim:axi_crossbar_tb.m01_axi_if.rdata}
    {Sim:axi_crossbar_tb.m01_axi_if.rresp}
    {Sim:axi_crossbar_tb.m01_axi_if.rlast}
    {Sim:axi_crossbar_tb.m01_axi_if.rvalid}
    {Sim:axi_crossbar_tb.m01_axi_if.rready}
}

set _wave_session_group_6 dut_ctrl
if {[gui_sg_is_group -name "$_wave_session_group_6"]} {
    set _wave_session_group_6 [gui_sg_generate_new_name]
}
set Group6 "$_wave_session_group_6"
gui_sg_addsignal -group "$_wave_session_group_6" {
    {Sim:axi_crossbar_tb.dut.clk}
    {Sim:axi_crossbar_tb.dut.rst}
}

if {![info exists useOldWindow]} {
    set useOldWindow true
}
if {$useOldWindow && [string first "Wave" [gui_get_current_window -view]] == 0} {
    set Wave.1 [gui_get_current_window -view]
} else {
    set Wave.1 [lindex [gui_get_window_ids -type Wave] 0]
    if {[string first "Wave" ${Wave.1}] != 0} {
        gui_open_window Wave
        set Wave.1 [gui_get_current_window -view]
    }
}

set origGroupCreationState [gui_list_create_group_when_add -wave]
gui_list_create_group_when_add -wave -disable
gui_list_add_group -id ${Wave.1} -after {New Group} [list ${Group1}]
gui_list_add_group -id ${Wave.1} -after {New Group} [list ${Group2}]
gui_list_add_group -id ${Wave.1} -after {New Group} [list ${Group3}]
gui_list_add_group -id ${Wave.1} -after {New Group} [list ${Group4}]
gui_list_add_group -id ${Wave.1} -after {New Group} [list ${Group5}]
gui_list_add_group -id ${Wave.1} -after {New Group} [list ${Group6}]
gui_list_select -id ${Wave.1} {axi_crossbar_tb.clk }
gui_seek_criteria -id ${Wave.1} {Any Edge}
gui_show_grid -id ${Wave.1} -enable false

if {$origGroupCreationState} {
    gui_list_create_group_when_add -wave -enable
}
