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

# CUDA Toolkit: only meaningful on an NVIDIA machine, so a CPU-only box gets no
# FAIL for a toolkit it was never supposed to install.
if (Test-CommandExists 'nvidia-smi') {
    if (Test-CommandExists 'nvcc') {
        Add-Result "CUDA Toolkit (nvcc)" $true ((& nvcc --version | Select-String 'release') -replace '^\s+', '')
    } else {
        Add-Result "CUDA Toolkit (nvcc)" $false "nvcc not on PATH -- run install.ps1 without -SkipCuda, or restart the shell"
    }
}

# R: BLAS backend + matrix-multiply benchmark.
if (Test-CommandExists 'Rscript') {
    $benchOutput = & Rscript "r\benchmark.R" 2>&1
    $benchOutput | Out-String | Write-Host
    $benchPass = ($LASTEXITCODE -eq 0)
    Add-Result "R OpenBLAS active" $benchPass ($benchOutput -join ' | ')
}

# R: confirm the packages that are most likely to break actually LOAD.
# "Installed" is not the same as "loadable" -- compiled packages can install
# fine and then fail to load against a swapped BLAS DLL or a missing runtime.
if (Test-CommandExists 'Rscript') {
    $loadCheck = & Rscript "r\check_packages.R" 2>&1
    $loadPass = ($LASTEXITCODE -eq 0)
    $loadCheck | Out-String | Write-Host
    Add-Result "R key packages load" $loadPass ($loadCheck | Select-Object -Last 1)
}

# Python: confirm NumPy is linked against an optimized BLAS.
if (Test-CommandExists 'python') {
    $venvPython = ".venv\Scripts\python.exe"
    $pythonExe = if (Test-Path $venvPython) { $venvPython } else { 'python' }
    $npCheck = & $pythonExe -c "import numpy; numpy.show_config()" 2>&1
    $npPass = ($LASTEXITCODE -eq 0)
    Add-Result "NumPy BLAS config" $npPass (($npCheck | Select-Object -First 3) -join ' | ')
}

# ML: PyTorch/TensorFlow CPU parallelism and GPU. Reported as a single check;
# full timings are printed above and captured in the log.
$venvPython = ".venv\Scripts\python.exe"
if (Test-Path $venvPython) {
    $mlArgs = @("python\ml_benchmark.py")
    if (Test-CommandExists 'nvidia-smi') { $mlArgs += '--expect-gpu' }
    $mlOutput = & $venvPython @mlArgs 2>&1
    $mlPass = ($LASTEXITCODE -eq 0)
    $mlOutput | Out-String | Write-Host
    $mlOutput | Out-String | Add-Content -Path $logFile
    Add-Result "ML libraries (torch/TF)" $mlPass (($mlOutput | Select-String 'speedup|FAIL:' | Select-Object -First 3) -join ' | ')
}

# Windows tuning (Tier 0). These are reported so a policy-blocked tweak is
# visible rather than silently costing you throughput.
$repoRoot = (Resolve-Path "$PSScriptRoot\..").Path

if (Get-Command Get-MpPreference -ErrorAction SilentlyContinue) {
    $excluded = @()
    try { $excluded = (Get-MpPreference -ErrorAction Stop).ExclusionPath } catch { }
    $isExcluded = $excluded -contains $repoRoot
    Add-Result "Defender exclusion (repo)" $isExcluded $(if ($isExcluded) { $repoRoot } else { "not excluded -- costs 2-5x on large-file I/O" })
}

$plan = (powercfg /getactivescheme 2>&1 | Out-String).Trim()
Add-Result "Power plan" ($plan -notmatch 'Balanced') $plan

try {
    $lp = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name LongPathsEnabled -ErrorAction Stop).LongPathsEnabled
} catch { $lp = 0 }
Add-Result "Long paths enabled" ($lp -eq 1) $(if ($lp -eq 1) { "enabled" } else { "disabled -- renv paths can exceed MAX_PATH" })

$notSynced = ($repoRoot -notlike '*OneDrive*')
Add-Result "Not OneDrive-synced" $notSynced $(if ($notSynced) { $repoRoot } else { "repo is inside OneDrive -- datasets will be uploaded" })

$renvCache = [Environment]::GetEnvironmentVariable('RENV_PATHS_CACHE', 'User')
Add-Result "renv cache configured" ([bool]$renvCache) $(if ($renvCache) { $renvCache } else { "unset -- packages get rebuilt on every machine" })

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
