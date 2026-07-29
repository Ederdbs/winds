# Installs R, swaps its reference BLAS/LAPACK for a multi-threaded OpenBLAS
# build, and restores the R package environment via renv.

. "$PSScriptRoot\_helpers.ps1"
. "$PSScriptRoot\..\config.ps1"

Write-Step "Installing R"
Invoke-ChocoInstall -Packages $Config.R.ChocoPackages

Write-Step "Installing R package system dependencies"
Invoke-ChocoInstall -Packages $Config.R.SystemChocoPackages

if (-not (Test-CommandExists 'Rscript')) {
    throw "Rscript.exe not found on PATH after installing R. Restart the shell and re-run this script."
}

$rBinDir = (& Rscript -e "cat(R.home('bin'))" | Out-String).Trim()
Write-Host "  R bin directory: $rBinDir" -ForegroundColor Yellow

function Install-OpenBlasForR {
    param([Parameter(Mandatory)][string]$RBinDir)

    $blasDll = Join-Path $RBinDir 'Rblas.dll'
    $lapackDll = Join-Path $RBinDir 'Rlapack.dll'
    $marker = Join-Path $RBinDir '.openblas_installed'

    if (Test-Path $marker) {
        Write-Skip "OpenBLAS already installed for this R"
        return
    }

    Write-Host "  Fetching latest OpenBLAS Windows release..." -ForegroundColor Yellow
    $release = Invoke-RestMethod "https://api.github.com/repos/$($Config.OpenBlas.GitHubRepo)/releases/latest"
    $asset = $release.assets | Where-Object { $_.name -like $Config.OpenBlas.AssetPattern } | Select-Object -First 1
    if (-not $asset) {
        Write-Fail "No matching OpenBLAS Windows x64 asset found, keeping reference BLAS"
        return
    }

    $tmpDir = Join-Path $env:TEMP "openblas_$(Get-Random)"
    New-Item -ItemType Directory -Path $tmpDir | Out-Null
    $zipPath = Join-Path $tmpDir $asset.name
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath
    Expand-Archive -Path $zipPath -DestinationPath $tmpDir -Force

    $openBlasDll = Get-ChildItem -Path $tmpDir -Filter 'libopenblas*.dll' -Recurse | Select-Object -First 1
    if (-not $openBlasDll) {
        Write-Fail "libopenblas.dll not found in downloaded archive, keeping reference BLAS"
        Remove-Item $tmpDir -Recurse -Force
        return
    }

    # Back up the reference BLAS/LAPACK before overwriting them.
    if (-not (Test-Path "$blasDll.reference.bak")) { Copy-Item $blasDll "$blasDll.reference.bak" }
    if (-not (Test-Path "$lapackDll.reference.bak")) { Copy-Item $lapackDll "$lapackDll.reference.bak" }

    # OpenBLAS bundles its own LAPACK implementation, so the same DLL replaces both.
    Copy-Item $openBlasDll.FullName $blasDll -Force
    Copy-Item $openBlasDll.FullName $lapackDll -Force

    Set-Content -Path $marker -Value (Get-Date -Format 'o')
    Remove-Item $tmpDir -Recurse -Force
    Write-Ok "OpenBLAS installed as R's BLAS/LAPACK backend"
}

Write-Step "Switching R's BLAS/LAPACK to OpenBLAS"
Install-OpenBlasForR -RBinDir $rBinDir

Write-Step "Restoring R package environment (renv)"
& Rscript "$PSScriptRoot\..\r\install_packages.R"
Write-Ok "R environment ready"
