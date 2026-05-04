set project_dir [file normalize [file join [file dirname [info script]] ..]]
open_project [file join $project_dir "pparser.xpr"]

set tb_file [file join $project_dir "tb" "pparser_single_short_tb.v"]
if {[llength [get_files -quiet $tb_file]] == 0} {
    add_files -fileset sim_1 $tb_file
}

set_property top pparser_single_short_tb [get_filesets sim_1]
update_compile_order -fileset sim_1

launch_simulation
restart
run all

close_sim
close_project
