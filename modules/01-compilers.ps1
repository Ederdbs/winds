# Installs Rtools (R's own build toolchain) and a standalone MinGW-w64
# toolchain for general-purpose C++/Fortran compilation.

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
