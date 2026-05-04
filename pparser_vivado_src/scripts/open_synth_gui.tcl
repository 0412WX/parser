set origin_dir [file normalize [file dirname [info script]]]
set project_dir [file normalize [file join $origin_dir ..]]
set report_dir [file join $project_dir reports]

open_project [file join $project_dir pparser.xpr]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

if {[file exists [file join $report_dir pparser_synth_generic_7series.dcp]]} {
    open_checkpoint [file join $report_dir pparser_synth_generic_7series.dcp]
} elseif {[llength [get_runs synth_1 -quiet]] > 0} {
    if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
        launch_runs synth_1 -jobs 4
        wait_on_run synth_1
    }
    open_run synth_1
}

catch {report_utilization}
catch {report_timing_summary}
