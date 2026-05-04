set origin_dir [file normalize [file dirname [info script]]]
set project_dir [file normalize [file join $origin_dir ..]]

open_project [file join $project_dir pparser.xpr]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
open_elaborated_design
