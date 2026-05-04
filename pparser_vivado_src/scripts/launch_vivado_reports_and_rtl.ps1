$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectDir = [System.IO.Path]::GetFullPath((Join-Path $scriptDir ".."))
$vivadoBin = "E:\vivado\Vivado\2024.2\bin"

Push-Location $projectDir
try {
    & "$vivadoBin\vivado.bat" -mode batch -source (Join-Path $scriptDir "create_project.tcl")
    if ($LASTEXITCODE -ne 0) {
        throw "vivado project creation failed with exit code $LASTEXITCODE"
    }

    Start-Process -FilePath "$vivadoBin\vivado.bat" -WorkingDirectory $projectDir -ArgumentList @(
        "-source", (Join-Path $scriptDir "open_synth_gui.tcl")
    )

    Start-Sleep -Seconds 2

    Start-Process -FilePath "$vivadoBin\vivado.bat" -WorkingDirectory $projectDir -ArgumentList @(
        "-source", (Join-Path $scriptDir "open_rtl_schematic_gui.tcl")
    )
}
finally {
    Pop-Location
}
