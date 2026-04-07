# Begin_DVE_Session_Save_Info
# DVE view(Wave.1 ) session
# Saved on 2025-12-04
# Toplevel windows open: 2
# 	TopLevel.1
# 	TopLevel.2
#   Wave.1: 33 signals
# End_DVE_Session_Save_Info

# DVE version: O-2018.09-SP2_Full64
# DVE build date: Feb 28 2019 23:39:41


#<Session mode="View" path="/home/host/Desktop/axiram/ahb-axi/axi/uvm/sim/axiram_debug_wave.do.tcl" type="Debug">

#<Database>

gui_set_time_units 1ps
#</Database>

# DVE View/pane content session: 

# Begin_DVE_Session_Save_Info (Wave.1)
# DVE wave signals session
# Saved on 2025-12-04
# 33 signals
# End_DVE_Session_Save_Info

# DVE version: O-2018.09-SP2_Full64
# DVE build date: Feb 28 2019 23:39:41


#Add necessary scopes
gui_load_child_values {axiram_tb.axi_if_inst}
gui_load_child_values {axiram_tb.dut}

gui_set_time_units 1ps

# Group 1: Global signals (clk & rst)
set _wave_session_group_1 global
if {[gui_sg_is_group -name "$_wave_session_group_1"]} {
    set _wave_session_group_1 [gui_sg_generate_new_name]
}
set Group1 "$_wave_session_group_1"

gui_sg_addsignal -group "$_wave_session_group_1" { {Sim:axiram_tb.axi_if_inst.aclk} {Sim:axiram_tb.axi_if_inst.arst} }

# Group 2: Write Address Channel (AW)
set _wave_session_group_2 AW_channel
if {[gui_sg_is_group -name "$_wave_session_group_2"]} {
    set _wave_session_group_2 [gui_sg_generate_new_name]
}
set Group2 "$_wave_session_group_2"

gui_sg_addsignal -group "$_wave_session_group_2" { {Sim:axiram_tb.axi_if_inst.awid} {Sim:axiram_tb.axi_if_inst.awaddr} {Sim:axiram_tb.axi_if_inst.awlen} {Sim:axiram_tb.axi_if_inst.awsize} {Sim:axiram_tb.axi_if_inst.awburst} {Sim:axiram_tb.axi_if_inst.awlock} {Sim:axiram_tb.axi_if_inst.awcache} {Sim:axiram_tb.axi_if_inst.awprot} {Sim:axiram_tb.axi_if_inst.awvalid} {Sim:axiram_tb.axi_if_inst.awready} }

# Group 3: Write Data Channel (W)
set _wave_session_group_3 W_channel
if {[gui_sg_is_group -name "$_wave_session_group_3"]} {
    set _wave_session_group_3 [gui_sg_generate_new_name]
}
set Group3 "$_wave_session_group_3"

gui_sg_addsignal -group "$_wave_session_group_3" { {Sim:axiram_tb.axi_if_inst.wdata} {Sim:axiram_tb.axi_if_inst.wstrb} {Sim:axiram_tb.axi_if_inst.wlast} {Sim:axiram_tb.axi_if_inst.wvalid} {Sim:axiram_tb.axi_if_inst.wready} }

# Group 4: Write Response Channel (B)
set _wave_session_group_4 B_channel
if {[gui_sg_is_group -name "$_wave_session_group_4"]} {
    set _wave_session_group_4 [gui_sg_generate_new_name]
}
set Group4 "$_wave_session_group_4"

gui_sg_addsignal -group "$_wave_session_group_4" { {Sim:axiram_tb.axi_if_inst.bid} {Sim:axiram_tb.axi_if_inst.bresp} {Sim:axiram_tb.axi_if_inst.bvalid} {Sim:axiram_tb.axi_if_inst.bready} }

# Group 5: Read Address Channel (AR)
set _wave_session_group_5 AR_channel
if {[gui_sg_is_group -name "$_wave_session_group_5"]} {
    set _wave_session_group_5 [gui_sg_generate_new_name]
}
set Group5 "$_wave_session_group_5"

gui_sg_addsignal -group "$_wave_session_group_5" { {Sim:axiram_tb.axi_if_inst.arid} {Sim:axiram_tb.axi_if_inst.araddr} {Sim:axiram_tb.axi_if_inst.arlen} {Sim:axiram_tb.axi_if_inst.arsize} {Sim:axiram_tb.axi_if_inst.arburst} {Sim:axiram_tb.axi_if_inst.arlock} {Sim:axiram_tb.axi_if_inst.arcache} {Sim:axiram_tb.axi_if_inst.arprot} {Sim:axiram_tb.axi_if_inst.arvalid} {Sim:axiram_tb.axi_if_inst.arready} }

# Group 6: Read Data Channel (R)
set _wave_session_group_6 R_channel
if {[gui_sg_is_group -name "$_wave_session_group_6"]} {
    set _wave_session_group_6 [gui_sg_generate_new_name]
}
set Group6 "$_wave_session_group_6"

gui_sg_addsignal -group "$_wave_session_group_6" { {Sim:axiram_tb.axi_if_inst.rid} {Sim:axiram_tb.axi_if_inst.rdata} {Sim:axiram_tb.axi_if_inst.rresp} {Sim:axiram_tb.axi_if_inst.rlast} {Sim:axiram_tb.axi_if_inst.rvalid} {Sim:axiram_tb.axi_if_inst.rready} }

# Group 7: DUT internal signals
set _wave_session_group_7 dut
if {[gui_sg_is_group -name "$_wave_session_group_7"]} {
    set _wave_session_group_7 [gui_sg_generate_new_name]
}
set Group7 "$_wave_session_group_7"

gui_sg_addsignal -group "$_wave_session_group_7" { {Sim:axiram_tb.dut.clk} {Sim:axiram_tb.dut.rst} {Sim:axiram_tb.dut.s_axi_awid} {Sim:axiram_tb.dut.s_axi_awaddr} {Sim:axiram_tb.dut.s_axi_awlen} {Sim:axiram_tb.dut.s_axi_awsize} {Sim:axiram_tb.dut.s_axi_awburst} {Sim:axiram_tb.dut.s_axi_awlock} {Sim:axiram_tb.dut.s_axi_awcache} {Sim:axiram_tb.dut.s_axi_awprot} {Sim:axiram_tb.dut.s_axi_awvalid} {Sim:axiram_tb.dut.s_axi_awready} {Sim:axiram_tb.dut.s_axi_wdata} {Sim:axiram_tb.dut.s_axi_wstrb} {Sim:axiram_tb.dut.s_axi_wlast} {Sim:axiram_tb.dut.s_axi_wvalid} {Sim:axiram_tb.dut.s_axi_wready} {Sim:axiram_tb.dut.s_axi_bid} {Sim:axiram_tb.dut.s_axi_bresp} {Sim:axiram_tb.dut.s_axi_bvalid} {Sim:axiram_tb.dut.s_axi_bready} {Sim:axiram_tb.dut.s_axi_arid} {Sim:axiram_tb.dut.s_axi_araddr} {Sim:axiram_tb.dut.s_axi_arlen} {Sim:axiram_tb.dut.s_axi_arsize} {Sim:axiram_tb.dut.s_axi_arburst} {Sim:axiram_tb.dut.s_axi_arlock} {Sim:axiram_tb.dut.s_axi_arcache} {Sim:axiram_tb.dut.s_axi_arprot} {Sim:axiram_tb.dut.s_axi_arvalid} {Sim:axiram_tb.dut.s_axi_arready} {Sim:axiram_tb.dut.s_axi_rid} {Sim:axiram_tb.dut.s_axi_rdata} {Sim:axiram_tb.dut.s_axi_rresp} {Sim:axiram_tb.dut.s_axi_rlast} {Sim:axiram_tb.dut.s_axi_rvalid} {Sim:axiram_tb.dut.s_axi_rready} }
if {![info exists useOldWindow]} { 
	set useOldWindow true
}
if {$useOldWindow && [string first "Wave" [gui_get_current_window -view]]==0} { 
	set Wave.1 [gui_get_current_window -view] 
} else {
	set Wave.1 [lindex [gui_get_window_ids -type Wave] 0]
if {[string first "Wave" ${Wave.1}]!=0} {
gui_open_window Wave
set Wave.1 [ gui_get_current_window -view ]
}
}

set groupExD [gui_get_pref_value -category Wave -key exclusiveSG]
gui_set_pref_value -category Wave -key exclusiveSG -value {false}
set origWaveHeight [gui_get_pref_value -category Wave -key waveRowHeight]
gui_list_set_height -id Wave -height 25
set origGroupCreationState [gui_list_create_group_when_add -wave]
gui_list_create_group_when_add -wave -disable
gui_marker_set_ref -id ${Wave.1}  C1
gui_wv_zoom_timerange -id ${Wave.1} 0 1354000
gui_list_add_group -id ${Wave.1} -after {New Group} [list ${Group1}]
gui_list_add_group -id ${Wave.1} -after {New Group} [list ${Group2}]
gui_list_add_group -id ${Wave.1} -after {New Group} [list ${Group3}]
gui_list_add_group -id ${Wave.1} -after {New Group} [list ${Group4}]
gui_list_add_group -id ${Wave.1} -after {New Group} [list ${Group5}]
gui_list_add_group -id ${Wave.1} -after {New Group} [list ${Group6}]
gui_list_add_group -id ${Wave.1} -after {New Group} [list ${Group7}]
gui_list_select -id ${Wave.1} {axiram_tb.axi_if_inst.aclk }
gui_seek_criteria -id ${Wave.1} {Any Edge}


gui_set_pref_value -category Wave -key exclusiveSG -value $groupExD
gui_list_set_height -id Wave -height $origWaveHeight
if {$origGroupCreationState} {
	gui_list_create_group_when_add -wave -enable
}
if { $groupExD } {
 gui_msg_report -code DVWW028
}
gui_list_set_filter -id ${Wave.1} -list { {Buffer 1} {Input 1} {Others 1} {Linkage 1} {Output 1} {Parameter 1} {All 1} {Aggregate 1} {LibBaseMember 1} {Event 1} {Assertion 1} {Constant 1} {Interface 1} {BaseMembers 1} {Signal 1} {$unit 1} {Inout 1} {Variable 1} }
gui_list_set_filter -id ${Wave.1} -text {*}
gui_list_set_insertion_bar  -id ${Wave.1} -group ${Group7}  -item {axiram_tb.dut.s_axi_rready} -position below

gui_marker_move -id ${Wave.1} {C1} 1347172
gui_view_scroll -id ${Wave.1} -vertical -set 0
gui_show_grid -id ${Wave.1} -enable false
#</Session>
