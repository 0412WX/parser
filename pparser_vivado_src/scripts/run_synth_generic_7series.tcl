set project_dir "C:/Users/DELL/Desktop/Traffic-Light-Controller-using-Verilog-master/pparser_vivado_src"
set report_dir [file join $project_dir reports]
set target_part "xc7a35tcpg236-1"

file mkdir $report_dir
cd $project_dir

set cam_dir [file join $project_dir third_party xilinx_cam]

read_vhdl -library cam [file join $cam_dir cam_init_file_pack_xst.vhd]
read_vhdl -library cam [file join $cam_dir cam_pkg.vhd]
read_vhdl -library cam [list \
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

read_vhdl [list \
    [file join $project_dir rtl pparser_stage0_cam_core.vhd] \
    [file join $project_dir rtl pparser_stage1_cam_core.vhd] \
]

read_verilog [list \
    [file join $project_dir rtl pparser_header_bram.v] \
    [file join $project_dir rtl pparser_key_extractor.v] \
    [file join $project_dir rtl pparser_action_table.v] \
    [file join $project_dir rtl pparser_stage0_tcam.v] \
    [file join $project_dir rtl pparser_stage1_tcam.v] \
    [file join $project_dir rtl pparser_final_resolver.v] \
    [file join $project_dir rtl pparser_phv_builder.v] \
    [file join $project_dir rtl pparser_hw_static.v] \
]

read_xdc [file join $project_dir xdc pparser_hw_static.xdc]

synth_design -top pparser_hw_static -part $target_part

report_utilization -file [file join $report_dir pparser_utilization_synth_generic_7series.rpt]
report_timing_summary -file [file join $report_dir pparser_timing_summary_synth_generic_7series.rpt]
report_high_fanout_nets -fanout_greater_than 16 -file [file join $report_dir pparser_high_fanout_synth_generic_7series.rpt]

write_checkpoint -force [file join $report_dir pparser_synth_generic_7series.dcp]
