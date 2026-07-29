# Windows-level tuning for large-dataset work. These usually beat any library
# change: AV scanning and CPU throttling cost more than a faster dataframe.
#
# Everything here is best-effort by design. Corporate images frequently lock
# Defender (Tamper Protection), power plans and the registry via Group Policy,
# so each step warns and continues rather than failing the whole install.

. "$PSScriptRoot\_helpers.ps1"
. "$PSScriptRoot\..\config.ps1"

$repoRoot = Resolve-Path "$PSScriptRoot\.."

# --- Defender exclusions ---------------------------------------------------
# Real-time scanning inspects every file read/write. On large datasets and
# package installs this is commonly a 2-5x I/O penalty.
Write-Step "Adding Windows Defender exclusions"

$exclusions = @($repoRoot.Path)
if (Test-CommandExists 'Rscript') {
    $rLib = (& Rscript -e "cat(.libPaths()[1])" 2>$null | Out-String).Trim()
    if ($rLib) { $exclusions += $rLib }
}
$venv = $Config.Python.VenvPath
if (Test-Path $venv) { $exclusions += $venv }
if ($Config.Optimize.ExtraExclusionPaths) { $exclusions += $Config.Optimize.ExtraExclusionPaths }

if (Get-Command Add-MpPreference -ErrorAction SilentlyContinue) {
    $current = @()
    try { $current = (Get-MpPreference -ErrorAction Stop).ExclusionPath } catch { }
    foreach ($path in ($exclusions | Where-Object { $_ } | Select-Object -Unique)) {
        if ($current -contains $path) {
            Write-Skip "Already excluded: $path"
            continue
        }
        try {
            Add-MpPreference -ExclusionPath $path -ErrorAction Stop
            Write-Ok "Excluded: $path"
        } catch {
            Write-Fail "Could not exclude '$path' -- likely blocked by Tamper Protection or Group Policy"
            Write-Host "  Ask IT to exclude your data/library folders; this is the single biggest I/O win." -ForegroundColor Yellow
        }
    }
} else {
    Write-Skip "Defender cmdlets unavailable (third-party AV?) -- exclude your data folders manually"
}

# --- Power plan -----------------------------------------------------------
# The Balanced plan throttles CPU clocks, which shows up on long MCMC/INLA runs.
Write-Step "Setting High performance power plan"
try {
    powercfg /setactive SCHEME_MIN 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Ok "High performance power plan active"
    } else {
        Write-Skip "Power plan unchanged (policy-managed, or the plan is unavailable on this device)"
    }
} catch {
    Write-Skip "Could not change power plan: $($_.Exception.Message)"
}

# --- Long path support ----------------------------------------------------
# The 260-character MAX_PATH limit breaks renv and deeply nested dependencies.
Write-Step "Enabling long path support"
$fsKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem'
try {
    $currentLongPaths = (Get-ItemProperty -Path $fsKey -Name LongPathsEnabled -ErrorAction Stop).LongPathsEnabled
} catch {
    $currentLongPaths = 0
}
if ($currentLongPaths -eq 1) {
    Write-Skip "Long paths already enabled"
} else {
    try {
        Set-ItemProperty -Path $fsKey -Name LongPathsEnabled -Value 1 -Type DWord -ErrorAction Stop
        Write-Ok "Long paths enabled (takes effect after reboot)"
    } catch {
        Write-Fail "Could not enable long paths -- blocked by Group Policy"
    }
}

# --- renv cache -----------------------------------------------------------
# A cache on a stable path is reused across projects AND machine rebuilds,
# which is the whole point when you reprovision often.
Write-Step "Configuring renv package cache"
$cachePath = $Config.Optimize.RenvCachePath
if ([Environment]::GetEnvironmentVariable('RENV_PATHS_CACHE', 'User') -eq $cachePath) {
    Write-Skip "RENV_PATHS_CACHE already set to $cachePath"
} else {
    New-Item -ItemType Directory -Path $cachePath -Force | Out-Null
    [Environment]::SetEnvironmentVariable('RENV_PATHS_CACHE', $cachePath, 'User')
    $env:RENV_PATHS_CACHE = $cachePath
    Write-Ok "RENV_PATHS_CACHE set to $cachePath"
}

# --- .Rprofile ------------------------------------------------------------
# Ncpus parallelizes source installs, which matters with 90+ packages.
#
# Deliberately NOT setting OMP_NUM_THREADS globally: that would cripple the
# OpenBLAS threading module 02 just enabled. Oversubscription is fixed inside
# parallel workers instead -- see the snippet written below.
Write-Step "Configuring .Rprofile"
$rProfile = Join-Path ([Environment]::GetFolderPath('MyDocuments')) '.Rprofile'
$marker = '# --- added by winds provisioning ---'

if ((Test-Path $rProfile) -and (Select-String -Path $rProfile -Pattern ([regex]::Escape($marker)) -Quiet)) {
    Write-Skip ".Rprofile already configured"
} elseif (Test-Path $rProfile) {
    Write-Fail "$rProfile already exists and was left untouched"
    Write-Host "  Add this manually:" -ForegroundColor Yellow
    Write-Host "    options(Ncpus = parallel::detectCores())" -ForegroundColor Yellow
} else {
    @"
$marker
# Parallelize package source installs.
options(Ncpus = parallel::detectCores())
# Show a progress bar for long downloads.
options(timeout = max(600, getOption("timeout")))
"@ | Set-Content -Path $rProfile -Encoding UTF8
    Write-Ok "Created $rProfile"
}

# --- OneDrive check -------------------------------------------------------
# Corporate Windows often applies OneDrive Known Folder Move to Documents,
# which silently uploads every dataset you touch.
Write-Step "Checking for OneDrive-synced working directory"
if ($repoRoot.Path -like '*OneDrive*' -or $env:OneDrive) {
    if ($repoRoot.Path -like '*OneDrive*') {
        Write-Fail "This repo is inside a OneDrive-synced folder: $($repoRoot.Path)"
        Write-Host "  Large datasets here get uploaded, destroying I/O and filling your quota." -ForegroundColor Yellow
        Write-Host "  Move your data (ideally this repo too) somewhere like C:\work." -ForegroundColor Yellow
    } else {
        Write-Skip "OneDrive is present but this repo is outside it -- keep datasets out of synced folders"
    }
} else {
    Write-Ok "Working directory is not OneDrive-synced"
}

Write-Step "Thread oversubscription reminder"
Write-Host @"
  OpenBLAS is now multi-threaded, so nested parallelism can oversubscribe:
  8 foreach workers x 8 BLAS threads = 64 threads on 8 cores, SLOWER than serial.
  Inside parallel workers, pin BLAS to one thread:

    library(RhpcBLASctl)
    cl <- parallel::makeCluster(parallel::detectCores())
    parallel::clusterEvalQ(cl, RhpcBLASctl::blas_set_num_threads(1))

  And set data.table threads deliberately: data.table::setDTthreads(0) uses all.
"@ -ForegroundColor Yellow

Write-Ok "Windows optimization pass complete"
