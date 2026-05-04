set origin_dir [file normalize [file dirname [info script]]]
set project_dir [file normalize [file join $origin_dir ..]]
open_project [file join $project_dir pparser.xpr]
update_compile_order -fileset sim_1
launch_simulation
add_wave /pparser_hw_static_tb/clk
add_wave /pparser_hw_static_tb/rst
add_wave /pparser_hw_static_tb/in_valid
add_wave /pparser_hw_static_tb/in_ready
add_wave /pparser_hw_static_tb/in_header
add_wave /pparser_hw_static_tb/out_valid
add_wave /pparser_hw_static_tb/out_ready
add_wave /pparser_hw_static_tb/out_path_id
add_wave /pparser_hw_static_tb/out_error
add_wave /pparser_hw_static_tb/out_phv
add_wave /pparser_hw_static_tb/dut/s0_valid
add_wave /pparser_hw_static_tb/dut/s1_valid
add_wave /pparser_hw_static_tb/dut/s2_valid
add_wave /pparser_hw_static_tb/dut/s3_valid
add_wave /pparser_hw_static_tb/dut/s4_valid
add_wave /pparser_hw_static_tb/dut/s5_valid
add_wave /pparser_hw_static_tb/dut/s6_valid
add_wave /pparser_hw_static_tb/dut/s1_stage0_key
add_wave /pparser_hw_static_tb/dut/s2_stage0_addr
add_wave /pparser_hw_static_tb/dut/s3_stage1_key
add_wave /pparser_hw_static_tb/dut/s4_stage1_addr
add_wave /pparser_hw_static_tb/dut/s5_path_id
add_wave /pparser_hw_static_tb/dut/s6_path_id
run all
