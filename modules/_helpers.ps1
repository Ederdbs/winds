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

function Invoke-ChocoInstall {
    param([Parameter(Mandatory)][string[]]$Packages)
    foreach ($pkg in $Packages) {
        Write-Host "  choco install $pkg" -ForegroundColor Yellow
        choco install $pkg -y --no-progress --limit-output
        # 1641/3010 = success but a reboot is pending/recommended, not a real failure.
        if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 1641 -and $LASTEXITCODE -ne 3010) {
            throw "Chocolatey failed to install '$pkg' (exit code $LASTEXITCODE)."
        }
    }
}
