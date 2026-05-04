set origin_dir [file normalize [file dirname [info script]]]
set project_dir [file normalize [file join $origin_dir ..]]

open_project [file join $project_dir pparser.xpr]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

synth_design -rtl -name rtl_1

set top_cell [get_cells -hierarchical -filter {NAME =~ *pparser_hw_static*}]
if {[llength $top_cell] > 0} {
    catch {show_schematic $top_cell}
}
