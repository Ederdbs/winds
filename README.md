# winds - Windows for Data Science

One-shot Windows provisioning for a data-science workstation. Run one script on
a fresh corporate machine and get a complete, tuned environment — all
idempotent, so re-running it on an already-provisioned machine is safe.

- **R** with ~90 packages: INLA/inlabru/fmesher, tidyverse, lme4, MCMCglmm,
  AlphaSimR, AGHmatrix, bWGR, the sf/terra geospatial stack, and Bioconductor
  (impute, LEA, Rgraphviz, graph, EBImage) — on an **OpenBLAS** backend for
  multi-threaded linear algebra.
- **Python** with ~35 packages, plus **PyTorch** (CUDA wheels auto-selected
  when an NVIDIA GPU is present) and **TensorFlow**.
- **Larger-than-RAM tooling**: duckdb, polars, arrow/Parquet, fst, collapse,
  and file-backed matrices (bigstatsr/bigsnpr) for genomic-scale data.
- **Toolchains**: Rtools, MinGW-w64 (gcc/g++/gfortran), Graphviz.
- **IDEs & tools**: Positron, VS Code, Docker Desktop, Claude Code, OpenCode,
  Ollama, Git/Git LFS, Quarto/Pandoc/TinyTeX, PowerShell 7, Windows Terminal.
- **Windows tuning for large data**: Defender exclusions, power plan, long
  paths, renv cache — the changes that usually beat any library swap.
- **Verification**: a diagnostic pass that benchmarks BLAS, load-tests native
  packages, and proves CPU parallelism and GPU use rather than assuming them.

## Contents

- [Prerequisites](#prerequisites) · [Quick start](#quick-start) ·
  [Re-running](#re-running-on-an-already-provisioned-machine) ·
  [Usage & flags](#usage) · [What gets installed](#what-gets-installed)
- [Working with large datasets on Windows](#working-with-large-datasets-on-windows)
  — Windows tuning, thread oversubscription, the out-of-memory toolkit
- [GPU support](#gpu-support-read-this-before-expecting-gpu-training)
  — **read before expecting GPU training**
- [Licensing](#licensing) — **Docker Desktop is not free for larger orgs**
- [Reproducibility](#reproducibility) · [Troubleshooting](#troubleshooting) ·
  [Gotchas](#gotchas) · [Verifying the install](#verifying-the-install)

## Prerequisites

- Windows 10/11 with a local Administrator account.
- **~40 GB free disk space** and 8 GB RAM minimum. The PyTorch/TensorFlow
  wheels, Docker Desktop, Rtools/MinGW and TinyTeX dominate that; use
  `-SkipMl` to cut roughly 5–10 GB.
- Internet access to `chocolatey.org`, `github.com`, `pypi.org`,
  `cloud.r-project.org`, `bioconductor.org`, `inla.r-inla-download.org`,
  `download.pytorch.org`, and `npmjs.com`. Behind
  a corporate proxy, set `HTTP_PROXY`/`HTTPS_PROXY` before running, and make
  sure Chocolatey and pip are configured to use it if those hosts aren't
  reachable directly.
- PowerShell 5.1 (built into Windows) is enough to *start* the script — it
  installs PowerShell 7 for you as part of `00-prereqs`.

## Quick start

1. Right-click PowerShell → **Run as Administrator**.

2. Get this repository onto the machine. On a *fresh* Windows install Git
   isn't there yet (this repo installs it in module 06), so pick whichever
   applies:

   **If Git is already available:**

   ```powershell
   cd $env:USERPROFILE
   git clone https://github.com/Ederdbs/winds.git
   cd winds
   ```

   **If Git is not installed yet** — bootstrap it with `winget`, which ships
   with Windows 10/11:

   ```powershell
   winget install --id Git.Git --silent --accept-package-agreements --accept-source-agreements
   $env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
   cd $env:USERPROFILE
   git clone https://github.com/Ederdbs/winds.git
   cd winds
   ```

   **No Git and no winget** — download and extract the ZIP instead:

   ```powershell
   cd $env:USERPROFILE
   Invoke-WebRequest -Uri https://github.com/Ederdbs/winds/archive/refs/heads/main.zip -OutFile winds.zip
   Expand-Archive .\winds.zip -DestinationPath . -Force
   cd winds-main
   ```

3. From the repo folder, run:

   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
   .\install.ps1
   ```

4. Grab coffee. A full run (everything, cold machine, decent connection)
   typically takes **45–90 minutes** — Rtools, MinGW, Docker Desktop, INLA's
   compiled dependencies and the PyTorch/TensorFlow wheels (several GB) are
   the slowest parts. Add `-SkipMl` to skip the ML download if you don't need
   it. `install.ps1` prints a `==> Step name` banner before each stage so you
   can see where it is.
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
- PyTorch/TensorFlow: `pip install --upgrade` no-ops when already current.
  Note these are deliberately **not** in `requirements.txt` — the correct
  torch wheel is machine-specific (CUDA variant vs CPU), so pinning it in a
  shared lockfile would push the wrong build onto the next machine.
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
| `-SkipPython` | Python, venv, pip install — also skips the ML stage, which needs the venv |
| `-SkipMl` | PyTorch, TensorFlow and the ML benchmark (saves a multi-GB download) |
| `-SkipIdes` | VS Code, Docker Desktop, Positron |
| `-SkipDocker` | Just Docker Desktop, while still installing VS Code and Positron |
| `-SkipAiTools` | Node.js, Claude Code, OpenCode, Ollama |
| `-SkipGitQuarto` | Git, Git LFS, SSH key, Quarto, Pandoc, TinyTeX |
| `-SkipOptimize` | The Windows tuning pass (Defender exclusions, power plan, long paths, renv cache) |
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
| `modules/07-ml.ps1` | PyTorch (CUDA or CPU wheels, auto-detected), TensorFlow, GPU/parallelism benchmark |
| `modules/08-optimize.ps1` | Windows tuning for large data: Defender exclusions, power plan, long paths, renv cache, `.Rprofile`, OneDrive check |

### Repository layout

```
install.ps1              Orchestrator: runs modules 00-08, then diagnostics
config.ps1               Central package lists, CUDA index, tuning paths
modules/
  _helpers.ps1           Shared: admin check, choco wrapper, logging
  00-prereqs.ps1 ... 08-optimize.ps1
r/
  install_packages.R     renv restore/bootstrap; verifies nothing is missing
  check_packages.R       Load-tests 37 native packages (installed != loadable)
  benchmark.R            Matrix-multiply throughput; confirms OpenBLAS is live
  renv.lock              Pinned R versions (commit this)
python/
  requirements.txt       Package list (edit this)
  requirements.lock.txt  Frozen versions (generated; commit this)
  ml_benchmark.py        CPU-parallelism and GPU verification
diagnostics/
  diagnose.ps1           Full PASS/FAIL report
  logs/                  Timestamped run history (gitignored)
```

`config.ps1` is the only file you should need to touch for routine updates:

| Key | Controls |
|---|---|
| `<Stage>.ChocoPackages` | Chocolatey packages per stage |
| `R.SystemChocoPackages` | System deps installed alongside R (Graphviz) |
| `Python.VenvPath` | Where the virtual environment lives |
| `Ml.TorchCudaIndex` | CUDA wheel variant (`cu118`/`cu126`/`cu128`) |
| `Ml.TensorFlowPackage` | TensorFlow package/pin |
| `Optimize.RenvCachePath` | Shared renv cache location |
| `Optimize.ExtraExclusionPaths` | **Add your data folders here** for Defender exclusions |
| `Ides.PositronWingetId` | Positron's winget ID |
| `OpenBlas.GitHubRepo` / `AssetPattern` | Which OpenBLAS release to fetch |

R packages come from three sources, each installed by
`r/install_packages.R`: `cran_packages` (CRAN, most of the list — Rcpp,
tidyverse, sf/terra/raster geospatial stack, ggplot2 ecosystem, MCMCglmm,
AlphaSimR, the duckdb/fst/collapse large-data stack, bigstatsr/bigsnpr and
profiling tools — see [Working with large datasets](#working-with-large-datasets-on-windows)),
`bioc_packages` (Bioconductor, via `BiocManager::install`
— `impute`, `LEA`, `Rgraphviz`, `graph`, `EBImage`), and INLA/fmesher/inlabru
(INLA's own repository, installed in that order since inlabru depends on
INLA).

**System dependencies**: `install_packages.R` sets
`options(pkgType = "binary")`, and on Windows the CRAN/Bioconductor binaries
bundle the native libraries these packages need — GDAL/PROJ/GEOS for
`sf`/`s2`/`terra`/`raster`, ImageMagick for `magick`, SYMPHONY for
`Rsymphony`, plus Cairo and Arrow. So no separate system-library install is
required. That pin matters: R's default `"both"` can silently fall back to a
source build that *does* need those libraries present, which is the usual
cause of mystery failures on a fresh machine. Chocolatey also installs
Graphviz (`$Config.R.SystemChocoPackages`) — `Rgraphviz`'s binary bundles its
own copy, so this is for the standalone `dot` CLI rather than a hard
requirement.

`parallel` and `splines` are **base R** — they ship with R and are
deliberately absent from the lists (`install.packages` errors on them).
`tidyr` arrives via `tidyverse`.

To add or remove an **R package**, edit the relevant list in
`r/install_packages.R`, run `.\modules\02-r.ps1` (or the full
`install.ps1`), then commit the updated `r/renv.lock`.

To add or remove a **Python package**, edit `python/requirements.txt`,
delete `python/requirements.lock.txt` so it gets regenerated, run
`.\modules\03-python.ps1`, then commit the new lock file.

## Working with large datasets on Windows

### Windows tuning (`modules/08-optimize.ps1`)

These generally beat any library change — AV scanning and CPU throttling cost
more than a faster dataframe. Every step is **best-effort**: corporate images
often lock these via Group Policy or Tamper Protection, so each one warns and
continues instead of failing the install. `diagnose.ps1` re-checks them, so a
blocked tweak shows up as a `[FAIL]` rather than silently costing throughput.

| Tweak | Why |
|---|---|
| **Defender exclusions** for the repo, R library and venv | Real-time scanning inspects every file read/write — commonly a **2–5x** I/O penalty on large datasets and package installs. The single biggest win here. Add your data folders to `$Config.Optimize.ExtraExclusionPaths`. |
| **High performance power plan** | The Balanced plan throttles CPU clocks; visible on long MCMC/INLA runs. |
| **Long path support** | The 260-char `MAX_PATH` limit breaks `renv` and deeply nested dependency paths. Needs a reboot. |
| **`RENV_PATHS_CACHE`** | A cache on a stable path is reused across projects *and* machine rebuilds — the point when you reprovision often. |
| **`.Rprofile`** with `options(Ncpus = detectCores())` | Parallel source installs; matters with 90+ packages. Created only if you don't already have one — an existing `.Rprofile` is never modified, the snippet is printed instead. |
| **OneDrive check** | Corporate Windows often applies OneDrive Known Folder Move to `Documents`, silently uploading every dataset you touch. Keep data (ideally this repo) somewhere like `C:\work`. |

### ⚠️ Thread oversubscription

Module 02 makes OpenBLAS multi-threaded, which means nested parallelism can
now work against you: 8 `foreach` workers × 8 BLAS threads each = 64 threads
on 8 cores, **slower than serial**. Pin BLAS to one thread inside workers:

```r
library(RhpcBLASctl)
cl <- parallel::makeCluster(parallel::detectCores())
parallel::clusterEvalQ(cl, RhpcBLASctl::blas_set_num_threads(1))
```

`OMP_NUM_THREADS` is deliberately **not** set globally — that would cripple the
OpenBLAS threading we just enabled. Fix it at the worker level, as above. Set
`data.table::setDTthreads()` deliberately too (`0` = all cores).

### The larger-than-RAM toolkit

| Tool | Where | Use it for |
|---|---|---|
| **duckdb** | R + Python | The workhorse. Out-of-core SQL over Parquet/CSV **larger than RAM**, no server. In R it plugs into `dplyr`, so tidyverse syntax keeps working on data that doesn't fit in memory. |
| **polars** | Python | Multithreaded Rust dataframes with a streaming engine; largely replaces pandas on big files. |
| **arrow** / **pyarrow** / **nanoparquet** | R + Python | Parquet — use it instead of CSV for anything large. |
| **fst**, **qs2** | R | Replace `saveRDS`. `fst` reads single columns without loading the whole file. |
| **collapse**, **dtplyr**, **vroom** | R | Fast grouped stats; `dplyr` syntax on a `data.table` engine; lazy reading of huge delimited files. |
| **zarr**, **h5py**, **xarray** | Python | Chunked and labeled N-d arrays. |
| **connectorx**, **odbc**/**DBI**, **fastexcel** | Python / R | Fast pulls from corporate SQL databases, and a Rust reader for large xlsx. |

### Genomic-scale matrices

Aimed at your `AGHmatrix`/`bWGR`/`AlphaSimR` work:

- **bigstatsr** / **bigsnpr** — file-backed memory-mapped matrices (FBM) for
  marker data past RAM.
- **RSpectra** / **irlba** — truncated eigendecomposition/SVD. A full `eigen()`
  on a large kinship matrix isn't feasible; truncated is routine.
- **float** — single-precision matrices, halving memory where float64 is overkill.
- **PLINK 2** is *not* installed here on purpose: Chocolatey's `plink` package
  is PuTTY's SSH tool, not the genomics one. Download it from
  https://www.cog-genomics.org/plink/2.0/ — `bigsnpr` interoperates with it.

### Profiling — measure before optimizing

R: **profvis** (visual profiler), **bench** (precise timing), **lobstr**
(find memory bloat), **RcppParallel**/**RcppEigen**.
Python: **scalene** (CPU+GPU+memory together), **line_profiler**,
**memory-profiler**, **bottleneck**/**numexpr**.

Also installed: **uv**, a much faster pip/venv replacement — useful when you
rebuild machines often.

## GPU support (read this before expecting GPU training)

`modules/07-ml.ps1` detects your hardware with `nvidia-smi` and installs
accordingly. Two Windows-specific facts drive everything here:

**PyTorch — GPU works natively.** But the default PyPI wheel on Windows is
**CPU-only**; CUDA builds live on a separate index. A plain
`pip install torch` silently gives you no GPU. The module installs from
`$Config.Ml.TorchCudaIndex` when an NVIDIA GPU is found, and falls back to CPU
wheels (with a warning) if the CUDA wheel won't install. You do **not** need
the multi-GB CUDA Toolkit — the wheels bundle their own CUDA runtime and
cuDNN, so a current NVIDIA driver is enough. Install the Toolkit only if you
need `nvcc` to compile custom kernels.

**TensorFlow — GPU does not work on native Windows, at all.** TensorFlow
2.10 was the last release supporting GPU on native Windows; from 2.11 onward
it is CPU-only there. This is Google's decision, not a gap in this script. The
options are:

1. **Run TensorFlow inside WSL2** — the supported route for TF on GPU on a
   Windows machine, and the one to use for real training work.
2. Pin `tensorflow<2.11` — *not* done here on purpose: it requires Python
   ≤3.10 and has years of unpatched security fixes.
3. `tensorflow-directml-plugin` — vendor-neutral (works with AMD/Intel too)
   but lags upstream considerably.

So on a native-Windows box expect **PyTorch on GPU, TensorFlow on CPU**. If
your heavy work is TensorFlow, do it in WSL2 (`-SkipDocker` still installs
WSL2 components via Docker Desktop, or enable WSL2 directly with
`wsl --install`).

To change the CUDA variant, edit `TorchCudaIndex` in `config.ps1` — `cu118`,
`cu126` and `cu128` are offered; a newer variant needs a newer driver. Check
https://pytorch.org/get-started/locally/ if unsure.

### What the ML benchmark actually verifies

`python/ml_benchmark.py` measures rather than trusts. Reporting
`torch.get_num_threads() == 16` only proves what torch *intends* — a machine
with a broken OpenMP/MKL setup reports 16 threads and still scales at 1.0x.
So it times an identical 4096² matmul at 1 thread vs all cores and reports the
observed speedup, failing below 1.5x on a multi-core box. For the GPU it calls
`torch.cuda.synchronize()` before stopping the clock, because CUDA is
asynchronous and without it you'd time the kernel *launch*, not the work.

It exits non-zero when an NVIDIA GPU is present but `torch.cuda.is_available()`
is `False` — the signature of CPU-only wheels having been installed by
mistake, which is otherwise very easy to miss.

## Licensing

Everything here is free of charge to install, but three items carry
conditions worth knowing in a corporate environment:

| Item | License | Catch |
|---|---|---|
| **Docker Desktop** | Proprietary | ⚠️ **Free only for individuals, education, open source, and small business — "fewer than 250 employees AND less than $10 million in annual revenue."** Above either threshold, commercial use requires a paid subscription. |
| **Claude Code** | Proprietary | ⚠️ The CLI installs free, but using it requires a paid Anthropic plan or pay-per-use API credits. |
| **OpenCode** | Open source | CLI is free; it needs a model provider — either a paid API key or a local model via Ollama (free). |
| **VS Code** | Microsoft EULA | The Chocolatey `vscode` package is Microsoft's branded build: free of charge and proprietary (telemetry included), not the MIT `code-oss` source build. |
| **Positron** | Elastic License 2.0 | Free for personal, academic, and commercial use; you may not host it as a service to third parties. Source-available, not OSI-open-source. |
| **bigrquery** (R) | Open source | Package is free; the Google BigQuery *service* it talks to is billed per query/storage. |
| **Ollama models** | Varies | Ollama itself is MIT. Individual models carry their own terms (e.g. Llama's community license has restrictions at very large scale) — check the model card. |

If your employer exceeds Docker's thresholds, swap Docker Desktop for a
license-free alternative — **Podman Desktop** or **Rancher Desktop** (both
Apache 2.0), or the Docker CLI/Engine directly inside WSL2, which is not
covered by the Docker Desktop license. Remove `docker-desktop` from
`$Config.Ides.ChocoPackages` (or always run with `-SkipDocker`) and install
your chosen replacement instead.

PyTorch (BSD-3) and TensorFlow (Apache-2.0) are both free and open source. The
CUDA runtime and cuDNN bundled inside the PyTorch wheels are NVIDIA
proprietary but free to use and redistribute under NVIDIA's terms — no
subscription, no license key.

Everything else is genuinely free and open source: R (GPL), Python (PSF),
OpenBLAS (BSD), Rtools/MinGW-w64/gcc/gfortran (GPL), Git (GPL-2), Git LFS
(MIT), Quarto (MIT), Pandoc (GPL), TinyTeX/TeX Live (free), Node.js (MIT),
PowerShell 7 (MIT), Windows Terminal (MIT), Chocolatey (Apache-2.0, community
edition), Graphviz (EPL), and every R and Python package in the lists
(GPL/MIT/BSD/Apache/Artistic-2.0 — `AlphaSimR` MIT, `MCMCpack` GPL-3,
`factoextra` GPL-2, `Rsymphony` EPL, INLA GPL).

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
- **`Rgraphviz` install fails** — its Bioconductor binary bundles Graphviz, so
  this is usually a source-build fallback. Confirm
  `options(pkgType = "binary")` took effect, then retry with
  `BiocManager::install("Rgraphviz", update = FALSE, ask = FALSE)`. The
  Chocolatey `graphviz` package provides the standalone `dot` CLI and is not
  required by the R package.
- **A Bioconductor package fails to install** (`impute`, `LEA`,
  `Rgraphviz`, `graph`, `EBImage`) — check `BiocManager::valid()` output for
  version mismatches against your R version, then retry with
  `BiocManager::install("<package>", update = FALSE, ask = FALSE)`.
- **`[FAIL] torch cannot see the installed NVIDIA GPU`** — CPU-only wheels
  got installed. Reinstall explicitly:
  `.venv\Scripts\pip install --force-reinstall torch torchvision torchaudio
  --index-url https://download.pytorch.org/whl/cu126`. If that fails, your
  driver is likely too old for that CUDA variant — try `cu118`.
- **`[FAIL] torch CPU parallelism only 1.0x`** — threading isn't working.
  Check `OMP_NUM_THREADS` isn't pinned to 1 in your environment (some
  corporate images set it), then re-run the benchmark.
- **TensorFlow reports 0 GPUs** — expected on native Windows, see
  [GPU support](#gpu-support-read-this-before-expecting-gpu-training). Not a
  bug; use WSL2 for TensorFlow on GPU.
- **`[FAIL] Defender exclusion` / `Long paths` / `Power plan`** — these are
  policy-locked on many corporate images. The install continues deliberately;
  ask IT to exclude your data and library folders, since that's the largest
  single I/O win available.
- **`pip install` fails resolving the Python list** — `numba` sometimes lags
  NumPy releases, and TensorFlow pins NumPy too, so the resolver can conflict.
  pip reports which packages disagree; the usual fix is to drop `numba` (or
  pin NumPy) and re-run `.\modules\03-python.ps1`.
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
  AlphaSimR's Rcpp code first).
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
performs five classes of check:

1. **Tools on PATH** — R, Python, Git, Docker, Ollama, Claude Code, compilers,
   Quarto, Pandoc, with versions.
2. **BLAS** — `r/benchmark.R` confirms OpenBLAS is actually the loaded backend
   and reports matrix-multiply throughput in GFLOPS.
3. **R packages** — `r/check_packages.R` load-tests 37 compiled/native packages.
4. **ML** — `python/ml_benchmark.py` measures CPU thread scaling and GPU
   compute (see [GPU support](#gpu-support-read-this-before-expecting-gpu-training)).
5. **Windows tuning** — re-checks the Tier 0 tweaks (Defender exclusion, power
   plan, long paths, OneDrive, renv cache) so a policy-blocked one is visible
   instead of silently costing throughput.

Two separate R checks, because they catch different failures:

- `r/install_packages.R` verifies every expected package is **installed** and
  exits non-zero listing any gaps. A batch `install.packages()` only *warns*
  on a failed build, so without this a machine could report healthy with a
  dozen packages missing.
- `r/check_packages.R` verifies the risky packages actually **load**.
  Installed is not loadable — a compiled package can install cleanly and then
  fail against the swapped BLAS DLL or a missing runtime.

Example output:

```
==> Diagnostic report
  [OK] Chocolatey: Chocolatey v2.3.0
  [OK] R: R scripting front-end version 4.4.1 (...)
  [OK] R OpenBLAS active: OpenBLAS active: TRUE
  [OK] R key packages load: All 37 key R packages load successfully
  [OK] Defender exclusion (repo): C:\work\winds
  [FAIL] Long paths enabled: disabled -- renv paths can exceed MAX_PATH
  [OK] NumPy BLAS config: openblas64_ ...
  [OK] ML libraries (torch/TF): CPU parallel speedup: 7.41x | GPU vs CPU speedup: 38.2x
  [FAIL] Docker: command 'docker' not found on PATH
...
Log written to diagnostics\logs\diagnose_20260729_143210.log
2 check(s) failed
```

A timestamped copy of every run is kept in `diagnostics/logs/` so you can
compare provisioning results across machines over time. The script exits
with code `1` if any check fails, so it can be wired into CI or a scheduled
task if you want periodic health checks on a long-lived machine.
