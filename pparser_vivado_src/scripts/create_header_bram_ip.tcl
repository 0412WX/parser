set project_dir [file normalize [file join [file dirname [info script]] ..]]
set ip_dir [file join $project_dir ip]
set ip_name "pparser_header_bram_ip"
file mkdir $ip_dir

create_ip -name blk_mem_gen -vendor xilinx.com -library ip -version 8.4 -module_name $ip_name -dir $ip_dir

set_property -dict [list \
    CONFIG.Memory_Type {Simple_Dual_Port_RAM} \
    CONFIG.Interface_Type {Native} \
    CONFIG.Write_Width_A {2048} \
    CONFIG.Write_Depth_A {32} \
    CONFIG.Read_Width_A {2048} \
    CONFIG.Read_Width_B {2048} \
    CONFIG.Enable_A {Use_ENA_Pin} \
    CONFIG.Enable_B {Use_ENB_Pin} \
    CONFIG.Register_PortA_Output_of_Memory_Primitives {false} \
    CONFIG.Register_PortB_Output_of_Memory_Primitives {false} \
    CONFIG.Use_RSTB_Pin {false} \
    CONFIG.Reset_Type {SYNC} \
    CONFIG.Port_A_Clock {100} \
    CONFIG.Port_B_Clock {100} \
    CONFIG.Port_A_Enable_Rate {100} \
    CONFIG.Port_B_Enable_Rate {100} \
    CONFIG.Port_A_Write_Rate {100} \
    CONFIG.Port_B_Write_Rate {0} \
    CONFIG.Use_Byte_Write_Enable {false} \
    CONFIG.Byte_Size {9} \
    CONFIG.Load_Init_File {false} \
    CONFIG.Assume_Synchronous_Clk {true} \
    CONFIG.Operating_Mode_B {READ_FIRST} \
    CONFIG.Algorithm {Minimum_Area} \
    CONFIG.Primitive {8kx2} \
    CONFIG.PRIM_type_to_Implement {BRAM} \
] [get_ips $ip_name]

generate_target all [get_ips $ip_name]
export_ip_user_files -of_objects [get_ips $ip_name] -no_script -sync -force -quiet
create_ip_run [get_ips $ip_name]
