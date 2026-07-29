# Installs Rtools (R's own build toolchain), a standalone MinGW-w64 toolchain
# for general-purpose C++/Fortran compilation, and -- when an NVIDIA GPU is
# present -- the CUDA Toolkit for nvcc.

param([switch]$SkipCuda)

. "$PSScriptRoot\_helpers.ps1"
. "$PSScriptRoot\..\config.ps1"

Write-Step "Installing compilers (Rtools + standalone MinGW-w64)"
Invoke-ChocoInstall -Packages $Config.Compilers.ChocoPackages

# NOTE: Rtools manages its own PATH entries when R compiles packages from
# source. Do not manually prepend the standalone MinGW gcc/g++/gfortran to
# the system PATH ahead of Rtools' toolchain -- mixing the two causes ABI
# mismatches when building R packages from source (e.g. INLA extras,
# AlphaSimR's Rcpp code).
Write-Ok "Compilers installed (Rtools for R package builds, MinGW-w64 for standalone C++/Fortran)"

# --- CUDA Toolkit ----------------------------------------------------------
# Only useful with an NVIDIA GPU, and only needed for nvcc / CuPy / Numba's
# cuda target / Nsight -- torch and TF ship their own CUDA runtime. ~3 GB, so
# it is not installed speculatively on machines that cannot use it.
Write-Step "Checking for NVIDIA GPU (CUDA Toolkit)"

if ($SkipCuda) {
    Write-Skip "CUDA Toolkit skipped (-SkipCuda)"
} elseif (Test-CommandExists 'nvcc') {
    Write-Skip "CUDA Toolkit already installed ($((& nvcc --version | Select-String 'release') -replace '^\s+',''))"
} elseif (-not (Test-NvidiaGpu)) {
    Write-Skip "No NVIDIA GPU/driver detected -- CUDA Toolkit not installed"
} else {
    Write-Step "Installing CUDA Toolkit (~3 GB)"
    Invoke-ChocoInstall -Packages @($Config.Cuda.ChocoPackage) -Version $Config.Cuda.Version
    Update-SessionPath
    if (Test-CommandExists 'nvcc') {
        Write-Ok "CUDA Toolkit installed ($((& nvcc --version | Select-String 'release') -replace '^\s+',''))"
    } else {
        # The install itself succeeded (Invoke-ChocoInstall throws otherwise);
        # only the PATH entry is missing until the shell restarts.
        Write-Skip "CUDA Toolkit installed, but nvcc is not on PATH yet -- restart the shell"
    }
}
