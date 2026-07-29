#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Provisions a Windows data-science workstation: R, Python, compilers,
    IDEs, AI CLIs and supporting tools, then runs a full diagnostic.

.EXAMPLE
    .\install.ps1
    .\install.ps1 -SkipDocker -SkipDiagnostics
#>
param(
    [switch]$SkipCompilers,
    [switch]$SkipR,
    [switch]$SkipPython,
    [switch]$SkipMl,
    [switch]$SkipIdes,
    [switch]$SkipAiTools,
    [switch]$SkipGitQuarto,
    [switch]$SkipOptimize,
    [switch]$SkipDocker,
    [switch]$SkipDiagnostics
)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

. "$PSScriptRoot\modules\_helpers.ps1"

if (-not (Test-IsAdmin)) {
    throw "This script must be run as Administrator (DLL swaps and system-level installs require elevation)."
}

& "$PSScriptRoot\modules\00-prereqs.ps1"
if (-not $SkipCompilers) { & "$PSScriptRoot\modules\01-compilers.ps1" }
if (-not $SkipR)         { & "$PSScriptRoot\modules\02-r.ps1" }
if (-not $SkipPython)    { & "$PSScriptRoot\modules\03-python.ps1" }
if (-not $SkipIdes)      { & "$PSScriptRoot\modules\04-ides.ps1" -SkipDocker:$SkipDocker }
if (-not $SkipAiTools)   { & "$PSScriptRoot\modules\05-ai-tools.ps1" }
if (-not $SkipGitQuarto) { & "$PSScriptRoot\modules\06-git-quarto.ps1" }
# After Python: 07-ml needs the venv that 03-python creates.
if (-not $SkipMl -and -not $SkipPython) { & "$PSScriptRoot\modules\07-ml.ps1" }
# Last: 08-optimize excludes the R library and venv from Defender, so it wants
# them to exist already.
if (-not $SkipOptimize) { & "$PSScriptRoot\modules\08-optimize.ps1" }

if (-not $SkipDiagnostics) {
    & "$PSScriptRoot\diagnostics\diagnose.ps1"
}
