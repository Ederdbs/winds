#!/usr/bin/env Rscript
# Bootstraps the project's R package environment with renv.
# Run from the repository root (install.ps1 / diagnose.ps1 already cd there).
#
# First run: renv is initialized, the packages below are installed, and the
# environment is snapshotted into r/renv.lock.
# Later runs: renv::restore() reproduces the exact versions from renv.lock.

required_packages <- c(
  "tidyverse",
  "lme4",
  "alphaSimR",
  "RhpcBLASctl"
)

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
  install.packages(required_packages, repos = "https://cloud.r-project.org")
}

# INLA is not distributed via CRAN, so it needs its own repository.
if (!requireNamespace("INLA", quietly = TRUE)) {
  message("Installing INLA from the r-inla repository")
  install.packages(
    "INLA",
    repos = c(inla = "https://inla.r-inla-download.org/R/stable", getOption("repos"))
  )
}

renv::snapshot(lockfile = lockfile, prompt = FALSE)
message("R environment ready. Commit r/renv.lock to reproduce this setup on other machines.")
