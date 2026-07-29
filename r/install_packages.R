#!/usr/bin/env Rscript
# Bootstraps the project's R package environment with renv.
# Run from the repository root (install.ps1 / diagnose.ps1 already cd there).
#
# First run: renv is initialized, the packages below are installed, and the
# environment is snapshotted into r/renv.lock.
# Later runs: renv::restore() reproduces the exact versions from renv.lock.
#
# A few names in the original request were ambiguous/typo'd; interpreted as:
#   wf -> wk (WKT/WKB parsing, a dependency of sf/s2), ggmisc -> ggpmisc.
# Fix these in the lists below if the intended package was something else.

cran_packages <- c(
  "tidyverse", "dplyr", "readr", "glue", "here", "fs", "jsonlite", "cli", "logger",
  "Rcpp", "RcppArmadillo", "RcppDE", "cpp11",
  "Matrix", "data.table", "Rfast", "bit64", "arrow",
  "lme4", "MCMCglmm", "AGHmatrix", "bWGR", "alphaSimR", "quantreg", "car",
  "MCMCpack", "GA", "numDeriv", "reshape2",
  "fields", "terra", "geosphere", "sf", "s2", "wk", "sp", "raster",
  "Cairo", "systemfonts", "magick",
  "ggplot2", "ggrepel", "ggpubr", "ggpmisc", "factoextra", "FactoMineR",
  "plotly", "shiny", "DT", "rmarkdown", "knitr",
  "foreach", "doParallel", "future", "furrr", "future.apply", "progressr",
  "bigrquery", "openxlsx", "httr2",
  "remotes", "devtools", "testthat", "covr", "optparse",
  "Rsymphony", "RhpcBLASctl"
)

# Bioconductor packages (installed via BiocManager, not install.packages).
bioc_packages <- c("impute", "LEA", "Rgraphviz", "graph", "EBImage")

if (!requireNamespace("renv", quietly = TRUE)) {
  install.packages("renv", repos = "https://cloud.r-project.org")
}

renv::consent(provided = TRUE)

lockfile <- "r/renv.lock"

if (file.exists(lockfile)) {
  message("Restoring R packages from ", lockfile)
  renv::restore(lockfile = lockfile, prompt = FALSE)
} else {
  message("No lockfile found, bootstrapping the R environment for the first time")
  renv::init(bare = TRUE)

  if (!requireNamespace("BiocManager", quietly = TRUE)) {
    install.packages("BiocManager", repos = "https://cloud.r-project.org")
  }

  install.packages(cran_packages, repos = "https://cloud.r-project.org")
  BiocManager::install(bioc_packages, update = FALSE, ask = FALSE)
}

# INLA is not distributed via CRAN, so it needs its own repository. Installed
# before inlabru/fmesher, which depend on it.
if (!requireNamespace("INLA", quietly = TRUE)) {
  message("Installing INLA from the r-inla repository")
  install.packages(
    "INLA",
    repos = c(inla = "https://inla.r-inla-download.org/R/stable", getOption("repos"))
  )
}

if (!requireNamespace("fmesher", quietly = TRUE)) {
  install.packages("fmesher", repos = "https://cloud.r-project.org")
}

if (!requireNamespace("inlabru", quietly = TRUE)) {
  install.packages("inlabru", repos = "https://cloud.r-project.org")
}

renv::snapshot(lockfile = lockfile, prompt = FALSE)
message("R environment ready. Commit r/renv.lock to reproduce this setup on other machines.")
