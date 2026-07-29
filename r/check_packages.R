#!/usr/bin/env Rscript
# Load-tests the packages most likely to break on a fresh Windows machine.
# Being *installed* is not the same as being *loadable*: compiled packages can
# install cleanly and still fail to load against a swapped BLAS DLL, a missing
# MSVC/gfortran runtime, or a half-built native dependency.
#
# This is deliberately a curated subset, not the full package list -- these are
# the native/compiled ones that actually fail in practice. Pure-R packages that
# installed successfully will load.

key_packages <- c(
  "INLA", "inlabru", "fmesher",        # non-CRAN repo + its dependents
  "Matrix", "lme4", "MCMCglmm",        # BLAS/LAPACK-linked
  "AlphaSimR", "bWGR", "Rfast",        # Rcpp/RcppArmadillo-compiled
  "sf", "s2", "terra", "raster",       # bundled GDAL/PROJ/GEOS
  "arrow", "magick", "Cairo",          # bundled native libraries
  "Rsymphony",                         # bundled SYMPHONY
  "Rgraphviz", "EBImage", "impute", "LEA", "graph", # Bioconductor
  "duckdb", "fst", "qs2", "collapse", "vroom",      # compiled large-data stack
  "bigstatsr", "bigsnpr", "RSpectra", "irlba", "float",  # file-backed/truncated algebra
  "exactextractr", "stars", "odbc",    # rasters + ODBC driver manager
  "RcppParallel", "RcppEigen"          # parallel/linear-algebra headers
)

failed <- character(0)
for (pkg in key_packages) {
  ok <- suppressWarnings(suppressMessages(
    requireNamespace(pkg, quietly = TRUE)
  ))
  if (!ok) failed <- c(failed, pkg)
}

if (length(failed) > 0) {
  cat("Packages that failed to load:", paste(failed, collapse = ", "), "\n")
  cat(length(failed), "of", length(key_packages), "key packages FAILED to load\n")
  quit(status = 1)
}

cat("All", length(key_packages), "key R packages load successfully\n")
