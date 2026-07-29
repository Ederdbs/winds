# Installs PyTorch and TensorFlow into the project venv, picking CUDA or CPU
# wheels based on whether an NVIDIA GPU is actually present on this machine.

. "$PSScriptRoot\_helpers.ps1"
. "$PSScriptRoot\..\config.ps1"

$venvPath = $Config.Python.VenvPath
$pip = Join-Path $venvPath 'Scripts\pip.exe'

if (-not (Test-Path $pip)) {
    throw "Python venv not found at $venvPath. Run modules\03-python.ps1 first."
}

Write-Step "Detecting GPU hardware"

# Report every adapter Windows knows about (covers AMD/Intel too), then check
# specifically for a working NVIDIA stack.
Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue |
    ForEach-Object { Write-Host "  GPU: $($_.Name) (driver $($_.DriverVersion))" -ForegroundColor Yellow }

$hasNvidia = Test-NvidiaGpu

if ($hasNvidia) {
    Write-Ok "NVIDIA GPU detected -- installing CUDA-enabled PyTorch"
} else {
    Write-Skip "No NVIDIA GPU/driver detected -- installing CPU-only PyTorch"
}

Write-Step "Installing PyTorch"
# The pip wheels bundle their own CUDA runtime and cuDNN, so the multi-GB
# CUDA Toolkit is NOT required -- a current NVIDIA driver is enough. (Install
# the Toolkit only if you need nvcc to compile custom CUDA kernels.)
if ($hasNvidia) {
    & $pip install --upgrade $Config.Ml.TorchPackages --index-url $Config.Ml.TorchCudaIndex
    if ($LASTEXITCODE -ne 0) {
        Write-Fail "CUDA wheel install failed (driver may be too old for this CUDA variant)"
        Write-Host "  Falling back to CPU-only PyTorch. Adjust TorchCudaIndex in config.ps1 to retry." -ForegroundColor Yellow
        & $pip install --upgrade $Config.Ml.TorchPackages
    }
} else {
    & $pip install --upgrade $Config.Ml.TorchPackages
}
if ($LASTEXITCODE -ne 0) { throw "PyTorch installation failed." }

Write-Step "Installing TensorFlow"
& $pip install --upgrade $Config.Ml.TensorFlowPackage
if ($LASTEXITCODE -ne 0) { throw "TensorFlow installation failed." }

if ($hasNvidia) {
    Write-Host "  NOTE: TensorFlow will run CPU-only here. GPU support on native" -ForegroundColor Yellow
    Write-Host "  Windows ended with TF 2.10; use WSL2 for TensorFlow on GPU." -ForegroundColor Yellow
}

Write-Step "Benchmarking ML libraries (CPU parallelism + GPU)"
$python = Join-Path $venvPath 'Scripts\python.exe'
$benchArgs = @("$PSScriptRoot\..\python\ml_benchmark.py")
if ($hasNvidia) { $benchArgs += '--expect-gpu' }
& $python @benchArgs
if ($LASTEXITCODE -ne 0) {
    throw "ML benchmark reported a problem (see output above)."
}

Write-Ok "PyTorch and TensorFlow installed and verified"
