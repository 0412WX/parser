set project_dir [file normalize [file join [file dirname [info script]] ..]]
open_project [file join $project_dir "pparser.xpr"]
reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1

set run_status [get_property STATUS [get_runs synth_1]]
puts "SYNTH_STATUS=$run_status"

if {[string match "*Complete*" $run_status] == 0} {
    error "synth_1 did not complete successfully: $run_status"
}

close_project
