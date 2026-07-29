# Full post-install diagnostic: checks every tool is on PATH, confirms
# OpenBLAS is active in R, benchmarks matrix-multiply performance, and
# checks NumPy's BLAS backend. Writes a report to diagnostics/logs/.

. "$PSScriptRoot\..\modules\_helpers.ps1"
Set-Location "$PSScriptRoot\.."

$logDir = "$PSScriptRoot\logs"
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
$logFile = Join-Path $logDir "diagnose_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

$results = @()

function Add-Result($Name, $Pass, $Detail) {
    $script:results += [PSCustomObject]@{ Check = $Name; Pass = $Pass; Detail = $Detail }
}

function Test-Tool($Name, $Command, $VersionArgs = '--version') {
    if (Test-CommandExists $Command) {
        $version = (& $Command $VersionArgs 2>&1 | Select-Object -First 1)
        Add-Result $Name $true $version
    } else {
        Add-Result $Name $false "command '$Command' not found on PATH"
    }
}

Write-Step "Running full installation diagnostics"

Test-Tool "Chocolatey" "choco"
Test-Tool "PowerShell 7" "pwsh"
Test-Tool "Git" "git"
Test-Tool "Git LFS" "git-lfs"
Test-Tool "R" "Rscript"
Test-Tool "Python" "python"
Test-Tool "Node.js" "node"
Test-Tool "Claude Code" "claude"
Test-Tool "Ollama" "ollama"
Test-Tool "Docker" "docker"
Test-Tool "Quarto" "quarto"
Test-Tool "Pandoc" "pandoc"
Test-Tool "gcc (MinGW)" "gcc"
Test-Tool "gfortran (MinGW)" "gfortran"

# R: BLAS backend + matrix-multiply benchmark.
if (Test-CommandExists 'Rscript') {
    $benchOutput = & Rscript "r\benchmark.R" 2>&1
    $benchOutput | Out-String | Write-Host
    $benchPass = ($LASTEXITCODE -eq 0)
    Add-Result "R OpenBLAS active" $benchPass ($benchOutput -join ' | ')
}

# Python: confirm NumPy is linked against an optimized BLAS.
if (Test-CommandExists 'python') {
    $venvPython = ".venv\Scripts\python.exe"
    $pythonExe = if (Test-Path $venvPython) { $venvPython } else { 'python' }
    $npCheck = & $pythonExe -c "import numpy; numpy.show_config()" 2>&1
    $npPass = ($LASTEXITCODE -eq 0)
    Add-Result "NumPy BLAS config" $npPass (($npCheck | Select-Object -First 3) -join ' | ')
}

Write-Step "Diagnostic report"
$results | ForEach-Object {
    if ($_.Pass) { Write-Ok "$($_.Check): $($_.Detail)" } else { Write-Fail "$($_.Check): $($_.Detail)" }
}

$results | Format-Table -AutoSize | Out-String | Add-Content -Path $logFile
$results | ForEach-Object { "$($_.Check): $(if ($_.Pass) { 'PASS' } else { 'FAIL' }) - $($_.Detail)" } | Add-Content -Path $logFile

$failCount = ($results | Where-Object { -not $_.Pass }).Count
Write-Host "`nLog written to $logFile"
if ($failCount -gt 0) {
    Write-Fail "$failCount check(s) failed"
    exit 1
} else {
    Write-Ok "All checks passed"
}
