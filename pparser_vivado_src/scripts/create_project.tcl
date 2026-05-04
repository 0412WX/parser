set origin_dir [file normalize [file dirname [info script]]]
set project_dir [file normalize [file join $origin_dir ..]]
set proj_name "pparser"
set cam_dir [file join $project_dir third_party xilinx_cam]
set target_part "xc7a200tfbg676-2"

create_project $proj_name $project_dir -part $target_part -force

set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
set_property source_mgmt_mode All [current_project]

source [file join $origin_dir "create_header_bram_ip.tcl"]

set cam_files [list \
    [file join $cam_dir cam_init_file_pack_xst.vhd] \
    [file join $cam_dir cam_pkg.vhd] \
    [file join $cam_dir cam_input_ternary_ternenc.vhd] \
    [file join $cam_dir cam_input_ternary.vhd] \
    [file join $cam_dir cam_input.vhd] \
    [file join $cam_dir cam_decoder.vhd] \
    [file join $cam_dir cam_mem_srl16_wrcomp.vhd] \
    [file join $cam_dir cam_mem_srl16_ternwrcomp.vhd] \
    [file join $cam_dir cam_mem_srl16_block_word.vhd] \
    [file join $cam_dir cam_mem_srl16_block.vhd] \
    [file join $cam_dir cam_mem_srl16.vhd] \
    [file join $cam_dir dmem.vhd] \
    [file join $cam_dir cam_mem_blk_extdepth_prim.vhd] \
    [file join $cam_dir cam_mem_blk_extdepth.vhd] \
    [file join $cam_dir cam_mem_blk.vhd] \
    [file join $cam_dir cam_mem.vhd] \
    [file join $cam_dir cam_match_enc.vhd] \
    [file join $cam_dir cam_control.vhd] \
    [file join $cam_dir cam_regouts.vhd] \
    [file join $cam_dir cam_rtl.vhd] \
    [file join $cam_dir cam_top.vhd] \
]
add_files -fileset sources_1 $cam_files
set_property library cam [get_files $cam_files]

add_files -fileset sources_1 [list \
    [file join $project_dir rtl pparser_header_bram.v] \
    [file join $project_dir rtl pparser_rule_bram.v] \
    [file join $project_dir rtl pparser_key_extractor.v] \
    [file join $project_dir rtl pparser_action_table.v] \
    [file join $project_dir rtl pparser_stage0_tcam.v] \
    [file join $project_dir rtl pparser_stage1_tcam.v] \
    [file join $project_dir rtl pparser_final_resolver.v] \
    [file join $project_dir rtl pparser_phv_builder.v] \
    [file join $project_dir rtl pparser_hw_static.v] \
    [file join $project_dir rtl pparser_stage0_cam_data.mif] \
    [file join $project_dir rtl pparser_stage0_cam_mask.mif] \
    [file join $project_dir rtl pparser_stage1_cam_data.mif] \
    [file join $project_dir rtl pparser_stage1_cam_mask.mif] \
    [file join $project_dir rtl pparser_stage0_desc.mem] \
    [file join $project_dir rtl pparser_stage1_desc.mem] \
    [file join $project_dir rtl pparser_action_table.mem] \
]

add_files -fileset sources_1 [list \
    [file join $project_dir rtl pparser_stage0_cam_core.vhd] \
    [file join $project_dir rtl pparser_stage1_cam_core.vhd] \
]

add_files -fileset constrs_1 [list \
    [file join $project_dir xdc pparser_hw_static.xdc] \
]

add_files -fileset sim_1 [list \
    [file join $project_dir tb pparser_hw_static_tb.v] \
    [file join $project_dir tb pparser_shortpath_gap_tb.v] \
    [file join $project_dir tb pparser_longpath_gap_tb.v] \
    [file join $project_dir tb pparser_cam_smoke_tb.v] \
    [file join $project_dir tb pparser_single_short_tb.v] \
    [file join $project_dir tb pparser_single_long_tb.v] \
    [file join $project_dir tb pparser_multi_short_tb.v] \
    [file join $project_dir tb pparser_debug_tb.v] \
]

set_property top pparser_hw_static [get_filesets sources_1]
set_property top pparser_shortpath_gap_tb [get_filesets sim_1]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
close_project
