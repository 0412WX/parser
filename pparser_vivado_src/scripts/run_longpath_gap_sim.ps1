$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectDir = [System.IO.Path]::GetFullPath((Join-Path $scriptDir ".."))
$vivadoBin = "E:\vivado\Vivado\2024.2\bin"
$camDir = Join-Path $projectDir "third_party\xilinx_cam"
$snapshotName = "pparser_longpath_gap_tb_snapshot"

function Invoke-VivadoStep {
    param(
        [string]$Tool,
        [string[]]$CommandArgs
    )

    & $Tool @CommandArgs
    if ($LASTEXITCODE -ne 0) {
        throw "$Tool failed with exit code $LASTEXITCODE"
    }
}

Push-Location $projectDir
try {
    Invoke-VivadoStep -Tool "$vivadoBin\xvhdl.bat" -CommandArgs @(
        "-work", "cam",
        (Join-Path $camDir "cam_init_file_pack_xst.vhd"),
        (Join-Path $camDir "cam_pkg.vhd"),
        (Join-Path $camDir "cam_input_ternary_ternenc.vhd"),
        (Join-Path $camDir "cam_input_ternary.vhd"),
        (Join-Path $camDir "cam_input.vhd"),
        (Join-Path $camDir "cam_decoder.vhd"),
        (Join-Path $camDir "cam_mem_srl16_wrcomp.vhd"),
        (Join-Path $camDir "cam_mem_srl16_ternwrcomp.vhd"),
        (Join-Path $camDir "cam_mem_srl16_block_word.vhd"),
        (Join-Path $camDir "cam_mem_srl16_block.vhd"),
        (Join-Path $camDir "cam_mem_srl16.vhd"),
        (Join-Path $camDir "dmem.vhd"),
        (Join-Path $camDir "cam_mem_blk_extdepth_prim.vhd"),
        (Join-Path $camDir "cam_mem_blk_extdepth.vhd"),
        (Join-Path $camDir "cam_mem_blk.vhd"),
        (Join-Path $camDir "cam_mem.vhd"),
        (Join-Path $camDir "cam_match_enc.vhd"),
        (Join-Path $camDir "cam_control.vhd"),
        (Join-Path $camDir "cam_regouts.vhd"),
        (Join-Path $camDir "cam_rtl.vhd"),
        (Join-Path $camDir "cam_top.vhd")
    )

    Invoke-VivadoStep -Tool "$vivadoBin\xvhdl.bat" -CommandArgs @(
        "$projectDir\rtl\pparser_stage0_cam_core.vhd",
        "$projectDir\rtl\pparser_stage1_cam_core.vhd"
    )

    Invoke-VivadoStep -Tool "$vivadoBin\xvlog.bat" -CommandArgs @(
        "-sv",
        "$projectDir\rtl\pparser_header_bram.v",
        "$projectDir\rtl\pparser_key_extractor.v",
        "$projectDir\rtl\pparser_action_table.v",
        "$projectDir\rtl\pparser_stage0_tcam.v",
        "$projectDir\rtl\pparser_stage1_tcam.v",
        "$projectDir\rtl\pparser_final_resolver.v",
        "$projectDir\rtl\pparser_phv_builder.v",
        "$projectDir\rtl\pparser_hw_static.v",
        "$projectDir\tb\pparser_longpath_gap_tb.v"
    )

    Invoke-VivadoStep -Tool "$vivadoBin\xelab.bat" -CommandArgs @(
        "work.pparser_longpath_gap_tb", "-L", "cam", "-L", "xpm", "-debug", "typical", "-s", $snapshotName
    )
    Invoke-VivadoStep -Tool "$vivadoBin\xsim.bat" -CommandArgs @($snapshotName, "-runall")
}
finally {
    Pop-Location
}
