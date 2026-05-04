set origin_dir [file normalize [file dirname [info script]]]
set project_dir [file normalize [file join $origin_dir ..]]
set report_dir [file join $project_dir reports]

open_project [file join $project_dir pparser.xpr]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

if {[file exists [file join $report_dir pparser_synth_generic_7series.dcp]]} {
    open_checkpoint [file join $report_dir pparser_synth_generic_7series.dcp]
} else {
    launch_runs synth_1 -jobs 4
    wait_on_run synth_1
    open_run synth_1
}

catch {report_utilization}
catch {report_timing_summary}

open_elaborated_design
set top_cell [get_cells -hierarchical pparser_hw_static]
if {[llength $top_cell] > 0} {
    catch {show_schematic $top_cell}
}
