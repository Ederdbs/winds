#!/usr/bin/env Rscript
# Benchmarks BLAS/LAPACK matrix-multiply performance and reports which
# BLAS library is actually loaded. Exits with status 1 if OpenBLAS is not
# active, so diagnose.ps1 can flag it as a failed check.

cat("R version:", R.version.string, "\n")

blas_path <- La_library()
cat("BLAS library path:", blas_path, "\n")
cat("Detected CPU cores:", parallel::detectCores(), "\n")

n <- 2000
set.seed(1)
A <- matrix(rnorm(n * n), n, n)
B <- matrix(rnorm(n * n), n, n)

t0 <- Sys.time()
C <- A %*% B
elapsed <- as.numeric(Sys.time() - t0, units = "secs")

gflops <- (2 * n^3) / elapsed / 1e9
cat(sprintf("Matrix multiply %dx%d: %.3f sec (%.2f GFLOPS)\n", n, n, elapsed, gflops))

is_openblas <- grepl("openblas", tolower(blas_path))
cat("OpenBLAS active:", is_openblas, "\n")

if (!is_openblas) {
  quit(status = 1)
}
