#!pwsh
#Requires -Version 7

using namespace System.IO
using namespace System.Mangement.Automation

[CmdletBinding()]
[OutputType([Boolean])]
param(
    [Switch] $NoCargoTargetTempDir,
    [ArgumentCompletions("release", "debug")]
    [String] $Target = "release"
)

$Local:ErrorActionPreference = [ActionPreference]::Stop

$PS = $PSStyle

$Cargo = Get-Command -CommandType Application cargo
$Toolchain = 'x86_64-pc-windows-msvc'

$BaseDir = Get-Item $PSScriptRoot\..
# Updated to tmp based target dir
$TargetDir = $BaseDir

$LibName = 'libgodot_archive_rust'
$LibInstallDir = "$BaseDir\godot\gdnative\gdarchive\bin\win64"

$CargoArgs = @(
    'build'
    '--target'
    $Toolchain
)

if($Target -eq "release")
{
    $CargoArgs += "--release"
}

if(-not $NoCargoTargetTempDir)
{
    $TargetDir =
        if((Test-Path -PathType Leaf ENV:\CARGO_TARGET_DIR) -and
           (Test-Path -PathType Container $ENV:CARGO_TARGET_DIR) -and
           ((Get-Item $ENV:CARGO_TARGET_DIR).FullName.StartsWith((Get-Item ([Path]::GetTempPath())).FullName)))
        { $ENV:CARGO_TARGET_DIR }
        else
        { [Path]::GetTempFileName() -replace '\.[^.]+', '' }

    [void]((Test-Path -PathType Container $TargetDir) -or (New-Item -Type Directory $TargetDir))

    $ENV:CARGO_TARGET_DIR = (Get-Item $TargetDir).FullName

    $CargoArgs += @(
        '--target-dir'
        $TargetDir
    )
}

[void]((Test-Path -PathType Container $LibInstallDir) -or (New-Item -Type Directory $LibInstallDir))

[void](Push-Location $BaseDir)
Write-Host "$($PS.Foreground.Blue + $PS.Bold)build.target-dir$($PS.Reset + $PS.Foreground.Black) = '$($PS.Underline + $PS.Bold)${TargetDir}$($PS.UnderlineOff + $PS.BoldOff)'$($PS.Reset)"

& $Cargo @CargoArgs

if($LASTEXITCODE -ne 0)
{
    throw $LASTEXITCODE
}

$OutDir = Get-Item ${TargetDir}\${Toolchain}\${Target}
#[void](Open-Location $OutDir)

$builtDll = Get-Item ${OutDir}\*.dll

Copy-Item $builtDll "${LibInstallDir}\${LibName}.dll" -Verbose