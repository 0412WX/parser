set project_dir "C:/Users/DELL/Desktop/Traffic-Light-Controller-using-Verilog-master/pparser_vivado_src"
set report_dir [file join $project_dir reports]

file mkdir $report_dir

read_verilog [list \
    [file join $project_dir rtl pparser_key_extractor.v] \
    [file join $project_dir rtl pparser_action_table.v] \
    [file join $project_dir rtl pparser_stage0_tcam.v] \
    [file join $project_dir rtl pparser_stage1_tcam.v] \
    [file join $project_dir rtl pparser_final_resolver.v] \
    [file join $project_dir rtl pparser_phv_builder.v] \
    [file join $project_dir rtl pparser_hw_static.v] \
]

read_xdc [file join $project_dir xdc pparser_hw_static.xdc]

synth_design -top pparser_hw_static -part xc7vx690tffg1761-3

report_utilization -file [file join $report_dir pparser_utilization_synth.rpt]
report_timing_summary -file [file join $report_dir pparser_timing_summary_synth.rpt]
report_high_fanout_nets -fanout_greater_than 16 -file [file join $report_dir pparser_high_fanout_synth.rpt]

write_checkpoint -force [file join $report_dir pparser_synth.dcp]
