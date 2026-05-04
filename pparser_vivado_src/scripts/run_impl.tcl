set project_dir [file normalize [file join [file dirname [info script]] ..]]
set report_dir [file join $project_dir reports]

file mkdir $report_dir
open_project [file join $project_dir "pparser.xpr"]

reset_run synth_1
reset_run impl_1

launch_runs synth_1 -jobs 4
wait_on_run synth_1

set synth_status [get_property STATUS [get_runs synth_1]]
puts "SYNTH_STATUS=$synth_status"
if {[string match "*Complete*" $synth_status] == 0} {
    error "synth_1 did not complete successfully: $synth_status"
}

launch_runs impl_1 -to_step route_design -jobs 4
wait_on_run impl_1

set impl_status [get_property STATUS [get_runs impl_1]]
puts "IMPL_STATUS=$impl_status"
if {[string match "*Complete*" $impl_status] == 0} {
    error "impl_1 did not complete successfully: $impl_status"
}

open_run impl_1
report_utilization -file [file join $report_dir pparser_utilization_impl.rpt]
report_timing_summary -file [file join $report_dir pparser_timing_summary_impl.rpt]
report_high_fanout_nets -fanout_greater_than 16 -file [file join $report_dir pparser_high_fanout_impl.rpt]
write_checkpoint -force [file join $report_dir pparser_impl_routed.dcp]

close_project
