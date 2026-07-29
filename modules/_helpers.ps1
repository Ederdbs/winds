# Shared helpers used by every module. Dot-source this first.

function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal $id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-CommandExists {
    param([Parameter(Mandatory)][string]$Name)
    [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Write-Step($Message) {
    Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Write-Ok($Message) { Write-Host "  [OK] $Message" -ForegroundColor Green }
function Write-Skip($Message) { Write-Host "  [SKIP] $Message" -ForegroundColor DarkGray }
function Write-Fail($Message) { Write-Host "  [FAIL] $Message" -ForegroundColor Red }

function Test-NvidiaGpu {
    # nvidia-smi only exists once the NVIDIA driver is installed, which is what
    # actually matters for CUDA -- a card with no driver is not usable.
    if (-not (Test-CommandExists 'nvidia-smi')) { return $false }
    nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader 2>&1 |
        ForEach-Object { Write-Host "  NVIDIA: $_" -ForegroundColor Yellow }
    return ($LASTEXITCODE -eq 0)
}

function Update-SessionPath {
    # choco updates the machine PATH, but the running process keeps its old
    # copy -- refresh so tools installed a moment ago resolve without a restart.
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [Environment]::GetEnvironmentVariable('Path', 'User')
}

function Invoke-ChocoInstall {
    param(
        [Parameter(Mandatory)][string[]]$Packages,
        # Pin an exact package version; empty means whatever choco ships as latest.
        [string]$Version
    )
    $versionArg = if ($Version) { @("--version=$Version") } else { @() }
    foreach ($pkg in $Packages) {
        Write-Host "  choco install $pkg $versionArg" -ForegroundColor Yellow
        choco install $pkg -y --no-progress --limit-output @versionArg
        # 1641/3010 = success but a reboot is pending/recommended, not a real failure.
        if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 1641 -and $LASTEXITCODE -ne 3010) {
            throw "Chocolatey failed to install '$pkg' (exit code $LASTEXITCODE)."
        }
    }
}
