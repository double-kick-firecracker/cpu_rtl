set search_path [list . \
    ../tsmc65lp/std/TSMCHOME/digital/Front_End/timing_power_noise/NLDM/tcbn65lp_220a \
    ../tsmc65lp/sram/ts1n65lpll2048x64m8_220a/SYNOPSYS \
    ../rtl \
    ../rtl/includes]

set target_library [list tcbn65lpwcz0d9.db]
set link_library [list * tcbn65lpwcz0d9.db  ts1n65lpll2048x64m8_220a_ss1p08v125c.db]
set RTL_PATH      "../rtl"
set UNMAPPED_PATH "./unmapped"
set MAPPED_PATH   "./mapped"
set REPORT_PATH   "./report"

# |===========================================================
# |STEP 1: Read & elaborate the RTL design file list & check
# |===========================================================
set	TOP_MODULE	riscv

set RTL_FILES [glob $RTL_PATH/*.v]
#set RTL_FILES [glob $RTL_PATH/*.sv]

analyze        -format verilog $RTL_FILES
#analyze        -format sverilog $RTL_FILES

elaborate      $TOP_MODULE     -architecture verilog
#elaborate      $TOP_MODULE     -architecture sverilog

current_design $TOP_MODULE

if {[link] == 0} {
	echo "Your Link has errors !";
	exit;
}
 
if {[check_design] == 0} {
	echo "Your check design has errors !";
	exit;
}
 
# |===========================================================
# |STEP 2: reset design
# |===========================================================
reset_design
 
 
# |===========================================================
# |STEP 3: Write unmapped ddc file
# |===========================================================
uniquify
set uniquify_naming_style "%s_%d"
write -f ddc -hierarchy -output ${UNMAPPED_PATH}/${TOP_MODULE}.ddc
 
 
# |===========================================================
# |STEP 4: define clocks (ns)
# |===========================================================
set       CLK_PORT              clk
set       CLK_PERIOD            5
set       CLK_SKEW	        	[expr {$CLK_PERIOD*0.05}]
set       CLK_TRANS         	[expr {$CLK_PERIOD*0.01}]
set       CLK_SRC_LATENCY   	[expr {$CLK_PERIOD*0.1 }]
set       CLK_LATENCY       	[expr {$CLK_PERIOD*0.1 }]

if {[find port [list $CLK_PORT]] != [list]} {
    set	CLK_NAME	$CLK_PORT
    create_clock	-period	$CLK_PERIOD	-name	$CLK_NAME	[get_ports $CLK_NAME]
    set_ideal_network 							            [get_ports $CLK_NAME]
    set_dont_touch_network						            [get_ports $CLK_NAME]
    set_drive 	0			 			                    [get_ports $CLK_NAME]
} else {
    set	CLK_NAME	VCLK
    create_clock	-period	$CLK_PERIOD	-name	$CLK_NAME
}

set_clock_uncertainty   -setup       	$CLK_SKEW		    [get_clocks $CLK_NAME]
set_clock_transition	-max         	$CLK_TRANS      	[get_clocks $CLK_NAME]
set_clock_latency       -source -max 	$CLK_SRC_LATENCY	[get_clocks $CLK_NAME]
set_clock_latency       -max         	$CLK_LATENCY    	[get_clocks $CLK_NAME]

 
# |===========================================================
# |STEP 5: define reset
# |===========================================================
set RST_PORT            rst
set_ideal_network		[get_ports $RST_PORT]
set_dont_touch_network	[get_ports $RST_PORT]
set_drive		0       [get_ports $RST_PORT]
 
 
# |===========================================================
# |STEP 6: set input delay using timing budget
# |Assume a weak cell to drive the input pins
# |===========================================================
set	LIB_NAME            tcbn65lpwcz0d9.db
# set WIRE_LOAD_MODEL     tsmc090_wl10
# set	DRIVE_CELL 		    INVX1
# set DRIVE_PIN 		    Y
set OPERATE_CONDITION	WCZ0D9COM

set	ALL_INPUT_EXCEPT_CLK	[remove_from_collection [all_inputs]	[get_ports "$CLK_NAME"]]
set	INPUT_DELAY             [expr {$CLK_PERIOD*0.6}]
 
set_input_delay		        $INPUT_DELAY	-clock	$CLK_NAME	$ALL_INPUT_EXCEPT_CLK
# set_input_delay -min	0		-clock 	$CLK_NAME	$ALL_INPUT_EXCEPT_CLK
# set_driving_cell -lib_cell	$DRIVE_CELL 	-pin	$DRIVE_PIN	$ALL_INPUT_EXCEPT_CLK

 
# |===========================================================
# |STEP 7: set output delay 
# |===========================================================
set OUTPUT_DELAY    [expr {$CLK_PERIOD*0.6}]
# set MAX_LOAD        [expr {[load_of $LIB_NAME/INVX8/A] * 10}]
 
set_output_delay	$OUTPUT_DELAY	-clock	$CLK_NAME	[all_outputs]
# set_load            [expr {$MAX_LOAD * 3}]	    		[all_outputs]
set_isolate_ports 	-type	        buffer      		[all_outputs]
 
 
# |===========================================================
# |STEP 8: set max delay for comb logic 
# |===========================================================
# set_input_delay	[expr $CLK_PERIOD * 0.1]	-clock	$CLK_NAME	-add_delay	[get_ports I_1]
# set_output_delay	[expr $CLK_PERIOD * 0.1]	-clock	$CLK_NAME	-add_delay	[get_ports O_1]
 
 
# |===========================================================
# |STEP 9: set operating condition & wire load model 
# |===========================================================
# set_operating_conditions	-max	$OPERATE_CONDITION	-max_library	$LIB_NAME
set auto_wire_load_selection true
# set_wire_load_model         -name   $WIRE_LOAD_MODEL    -library        $LIB_NAME


# |===========================================================
# |STEP 10: set area constraint (Let DC try its best) 
# |===========================================================
set_max_area	0
 
# |===========================================================
# |STEP 11: set DRC constraint 
# |===========================================================
# set	MAX_CAPACITANCE		[expr {[load_of $LIB_NAME/NAND4X2/Y] * 5}]
# set_max_capacitance		$MAX_CAPACITANCE $ALL_INPUT_EXCEPT_CLK
 
 
# |===========================================================
# |STEP 12: set group path
# |Avoid getting stack on one path
# |===========================================================
# group_path	-name	$CLK_NAME	-weight	5	 	-critical_range	[expr {$CLK_PERIOD * 0.1}] 
# group_path	-name	INPUTS		-from	[all_inputs]	-critical_range	[expr {$CLK_PERIOD * 0.1}] 
# group_path	-name	$CLK_NAME	-to	[all_outputs]	-critical_range	[expr {$CLK_PERIOD * 0.1}] 
# group_path	-name	$CLK_NAME	-from	[all_inputs]	-to		[all_outputs]		-critical_range  [expr {$CLK_PERIOD * 0.1}]
# report_path_group


# |===========================================================
# |STEP 13: Elimate the multiple-port inter-connect &
# |			define name style
# |===========================================================
# set_app_var	verilogout_no_tri	true
# set_app_var	verilogout_show_unconnected_pins	true
# set_app_var	bus_naming_style	{%s[%d]}
# simplify_constants	-boundary_optimization
# set_boundary_optimization	[current_design]	true
# set_fix_multiple_port_nets -all	-buffer_constants


# |===========================================================
# |STEP 14: timing exception define
# |===========================================================
# set_false_path -from [get_clocks I_CLK_100M] -to [get_clocks I_CLK_100M]
# set ALL_CLKS [all_clocks]
# foreach_in_collection CUR_CLK $ALL_CLKS 
# {
# 	set OTHER_CLKS [remove_from_collection [all_clocks] $CUR_CLK]
# 	set_false_path -from $CUR_CLK $OTHER_CLKS
# }
 
# set_false_path -from [get_clocks I_CLK_100M] -to [get_clocks I_CLK_100M]
# set_false_path -from [get_clocks I_CLK_100M] -to [get_clocks I_CLK_100M]
 
# set_disable_timing TOP/U1 -from a -to y
# set_case_analysis 0 [get_ports sel_i]
 
# set_multicycle_path -setup 6 -from FFA/CP -through ADD/out -to FFB/D
# set_multicycle_path -hold 5 -from FFA/CP -through ADD/out -to FFB/D
# set_multicycle_path -setup 2 -to FFB/D
# set_multicycle_path -hold 1 -to FFB/D

# |===========================================================
# |STEP 15: compile flow
# |===========================================================
# ungroup -flatten -all
 
# 1st-pass compile
# compile -map_effort high -area_effort high
# compile -map_effort high -area_effort high -boundary_optimization
compile -map_effort high -area_effort high -scan
 
# simplify_constants -boundary_optimization
# set_fix_multiple_port_nets -all -buffer_constants
 
# compile -map_effort high -area_effort high -incremental_mapping -scan
 
# 2nd-pass compile
# compile -map_effort high -area_effort high -incremental_mapping -boundary_optimization
# compile_ultra -incr


# |===========================================================
# |STEP 16: write post-process files
# |===========================================================
# change_names -rules verilog -hierarchy
# remove-unconnected_ports [get_cells -hierarchy *] -blast_buses

write -f	ddc     -hierarchy -output	$MAPPED_PATH/${TOP_MODULE}.ddc
write -f	verilog -hierarchy -output 	$MAPPED_PATH/${TOP_MODULE}.v
write_sdc 				                $MAPPED_PATH/${TOP_MODULE}.sdc
write_sdf			                	$MAPPED_PATH/${TOP_MODULE}.sdf
 
# |===========================================================
# |STEP 17: generate report files
# |===========================================================
redirect    -tee    -file   ${REPORT_PATH}/check_design.txt     	{check_design}
redirect    -tee    -file   ${REPORT_PATH}/check_timing.txt     	{check_timing}
redirect    -tee    -file   ${REPORT_PATH}/check_setup.txt       	{report_timing -delay_type  max}
redirect    -tee    -file   ${REPORT_PATH}/check_hold.txt           {report_timing -delay_type  min}
redirect    -tee    -file   ${REPORT_PATH}/report_area.txt      	{report_area -hierarchy}
redirect    -tee    -file   ${REPORT_PATH}/report_cell.txt      	{report_cell}
redirect    -tee    -file   ${REPORT_PATH}/report_power.txt      	{report_power}
redirect    -tee    -file   ${REPORT_PATH}/report_constraint.txt	{report_constraint -all_violators}


quit


