# winds - Windows for Data Science

One-shot Windows provisioning for a data-science workstation. Run one script
on a fresh corporate machine and get R (with INLA, tidyverse, lme4,
alphaSimR), Rtools, Python, Positron, VS Code, Docker, Claude Code, OpenCode,
Ollama, C++/Fortran compilers, and an OpenBLAS-backed R for parallel linear
algebra — all idempotent, so re-running the script on an already-provisioned
machine is safe.

## Prerequisites

- Windows 10/11 with a local Administrator account.
- Internet access to `chocolatey.org`, `github.com`, `pypi.org`,
  `cloud.r-project.org`, `inla.r-inla-download.org`, and `npmjs.com`. Behind
  a corporate proxy, set `HTTP_PROXY`/`HTTPS_PROXY` before running, and make
  sure Chocolatey and pip are configured to use it if those hosts aren't
  reachable directly.
- PowerShell 5.1 (built into Windows) is enough to *start* the script — it
  installs PowerShell 7 for you as part of `00-prereqs`.

## Quick start

1. Clone or copy this repository onto the new machine.
2. Right-click PowerShell → **Run as Administrator**.
3. `cd` into the repo folder and run:

   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
   .\install.ps1
   ```

4. Grab coffee. A full run (everything, cold machine, decent connection)
   typically takes **30–60 minutes** — Rtools, MinGW, Docker Desktop, and
   INLA's compiled dependencies are the slowest parts. `install.ps1` prints
   a `==> Step name` banner before each stage so you can see where it is.
5. It finishes by running `diagnostics/diagnose.ps1` automatically and
   printing a PASS/FAIL table. Fix any `[FAIL]` line before trusting the
   machine for real work (see [Troubleshooting](#troubleshooting)).
6. Some installers (Docker Desktop, WSL2 components) may require a
   **reboot**. If Chocolatey reports exit code `1641` or `3010`, that's
   expected — reboot, then re-run `.\install.ps1`; every already-completed
   step is skipped automatically.

## Re-running on an already-provisioned machine

Every step checks current state before acting, so running `.\install.ps1`
again is safe and fast — it's the intended way to pick up config changes
(e.g. a new R package added to `r/install_packages.R`) without a full
reinstall:

- Chocolatey packages: `choco install` itself no-ops if the package is
  already at the requested version.
- OpenBLAS swap: skipped if the `.openblas_installed` marker exists next to
  `Rblas.dll`.
- R packages: `renv::restore()` from the committed lockfile — only installs
  what's missing/out of date.
- Python packages: reused from `requirements.lock.txt` once it exists.
- SSH key: skipped if `~/.ssh/id_ed25519` already exists.

## Usage

Skip specific stages with flags, e.g. on a machine that already has Docker:

```powershell
.\install.ps1 -SkipDocker
```

Run only R and Python setup on a machine that already has the IDEs/tools:

```powershell
.\install.ps1 -SkipIdes -SkipAiTools -SkipGitQuarto -SkipCompilers
```

| Flag | Skips |
|---|---|
| `-SkipCompilers` | Rtools, MinGW-w64 |
| `-SkipR` | R, OpenBLAS swap, R package restore |
| `-SkipPython` | Python, venv, pip install |
| `-SkipIdes` | VS Code, Docker Desktop, Positron |
| `-SkipDocker` | Just Docker Desktop, while still installing VS Code and Positron |
| `-SkipAiTools` | Node.js, Claude Code, OpenCode, Ollama |
| `-SkipGitQuarto` | Git, Git LFS, SSH key, Quarto, Pandoc, TinyTeX |
| `-SkipDiagnostics` | The automatic `diagnose.ps1` run at the end |

Modules can also be run individually if you only need one piece, e.g. to
pick up a `config.ps1` change to the Python package list without touching
anything else:

```powershell
.\modules\03-python.ps1
```

Run the diagnostic report on its own at any time, without reinstalling
anything:

```powershell
.\diagnostics\diagnose.ps1
```

## What gets installed

| Module | Contents |
|---|---|
| `modules/00-prereqs.ps1` | Chocolatey, PowerShell 7, Windows Terminal |
| `modules/01-compilers.ps1` | Rtools (R's build toolchain), standalone MinGW-w64 (gcc/g++/gfortran) |
| `modules/02-r.ps1` | R, OpenBLAS swap, R packages via `renv` |
| `modules/03-python.ps1` | Python, venv, packages via `pip` |
| `modules/04-ides.ps1` | VS Code, Docker Desktop, Positron |
| `modules/05-ai-tools.ps1` | Node.js, Claude Code, OpenCode, Ollama |
| `modules/06-git-quarto.ps1` | Git, Git LFS, SSH key, Quarto, Pandoc, TinyTeX |

Edit `config.ps1` to change package lists/versions — it's the only file you
should need to touch for routine updates (e.g. bumping the Python version,
adding a Chocolatey package, changing the Positron winget ID).

To add or remove an **R package**, edit `required_packages` in
`r/install_packages.R`, run `.\modules\02-r.ps1` (or the full
`install.ps1`), then commit the updated `r/renv.lock`.

To add or remove a **Python package**, edit `python/requirements.txt`,
delete `python/requirements.lock.txt` so it gets regenerated, run
`.\modules\03-python.ps1`, then commit the new lock file.

## Reproducibility

- **R**: `r/install_packages.R` runs `renv::restore()` if `r/renv.lock`
  exists, otherwise it installs the required packages and snapshots a new
  lockfile. Commit `r/renv.lock` after the first successful install so every
  future machine gets identical versions.
- **Python**: `modules/03-python.ps1` installs from `python/requirements.txt`
  on first run and freezes `python/requirements.lock.txt`. Once that lock
  file exists it's used on every subsequent run. Commit it for the same
  reason as above.

Practical workflow across machines: provision machine A, let both lockfiles
get generated, commit them to the repo. On machine B, `.\install.ps1` will
find the committed lockfiles and restore the exact same versions instead of
re-resolving latest-and-possibly-different ones.

## Troubleshooting

- **`This script must be run as Administrator`** — you launched PowerShell
  without elevation. Close it and reopen via "Run as Administrator".
- **`Rscript.exe not found on PATH after installing R`** /
  **`npm not found on PATH after installing Node.js`** — Chocolatey updated
  the machine-level PATH, but your current shell has the old one cached.
  Close the PowerShell window and start a new elevated one, then re-run
  `.\install.ps1` (already-completed steps are skipped).
- **`[FAIL] R OpenBLAS active`** in the diagnostic report — either the
  OpenBLAS download failed (check your connection to `github.com`/GitHub's
  API rate limit) or `La_library()` isn't reporting `openblas` in its path.
  Delete the `.openblas_installed` marker next to `Rblas.dll` in R's
  `bin/x64` folder and re-run `.\modules\02-r.ps1` to retry.
- **Reverting the BLAS swap**: copy `Rblas.dll.reference.bak` back over
  `Rblas.dll` (same for `Rlapack.dll`) in R's `bin/x64` folder, and delete
  the `.openblas_installed` marker.
- **INLA install fails** — it's a large binary package pulled from a
  non-CRAN repo; a flaky connection or corporate proxy blocking
  `inla.r-inla-download.org` is the usual cause. Re-run
  `Rscript r\install_packages.R` once connectivity is confirmed.
- **Docker Desktop needs WSL2 / a reboot** — this is a Windows requirement,
  not a bug in this repo. Follow the on-screen Docker prompt, reboot, and
  re-run `.\install.ps1`.
- **Corporate proxy / blocked GitHub API** — `modules/02-r.ps1` calls the
  GitHub REST API to find the latest OpenBLAS release; if that's blocked,
  the step logs a `[FAIL]` and leaves R on the reference BLAS rather than
  breaking the rest of the install.

## Gotchas

- **Rtools vs. MinGW PATH conflict**: don't add the standalone MinGW
  toolchain ahead of Rtools on the system PATH. R manages Rtools' PATH
  entries itself when compiling packages from source; mixing the two
  toolchains causes ABI mismatches (this bites INLA's compiled extras and
  alphaSimR's Rcpp code first).
- **INLA** isn't on CRAN — `install_packages.R` installs it from
  `https://inla.r-inla-download.org/R/stable` separately.
- **OpenBLAS swap**: `modules/02-r.ps1` downloads the latest OpenBLAS Windows
  release and replaces `Rblas.dll`/`Rlapack.dll` in R's `bin/x64` (OpenBLAS
  bundles its own LAPACK, so one DLL covers both). The original DLLs are
  backed up as `*.reference.bak` next to them if you ever need to revert.
- **Positron** has no Chocolatey package yet, so it's installed via
  `winget`. If `winget` is unavailable, install it manually from
  https://github.com/posit-dev/positron/releases.
- Chocolatey exit codes `1641`/`3010` mean "success, reboot pending" — the
  scripts treat those as success, not failure.

## Verifying the install

`diagnostics/diagnose.ps1` (run automatically at the end of `install.ps1`)
checks every tool is on PATH, runs `r/benchmark.R` to confirm OpenBLAS is
active and report matrix-multiply throughput, and checks NumPy's BLAS
backend. Example output:

```
==> Diagnostic report
  [OK] Chocolatey: Chocolatey v2.3.0
  [OK] R: R scripting front-end version 4.4.1 (...)
  [OK] R OpenBLAS active: OpenBLAS active: TRUE
  [OK] NumPy BLAS config: openblas64_ ...
  [FAIL] Docker: command 'docker' not found on PATH
...
Log written to diagnostics\logs\diagnose_20260729_143210.log
2 check(s) failed
```

A timestamped copy of every run is kept in `diagnostics/logs/` so you can
compare provisioning results across machines over time. The script exits
with code `1` if any check fails, so it can be wired into CI or a scheduled
task if you want periodic health checks on a long-lived machine.
