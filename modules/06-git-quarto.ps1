# Installs Git, Git LFS, Quarto and Pandoc; generates an SSH key if missing;
# installs TinyTeX via Quarto for PDF report rendering.

. "$PSScriptRoot\_helpers.ps1"
. "$PSScriptRoot\..\config.ps1"

Write-Step "Installing Git, Quarto and Pandoc"
Invoke-ChocoInstall -Packages $Config.GitQuarto.ChocoPackages

if (Test-CommandExists 'git') {
    git lfs install
}

$sshKey = "$env:USERPROFILE\.ssh\id_ed25519"
if (-not (Test-Path $sshKey)) {
    Write-Host "  Generating SSH key ($sshKey)" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path "$env:USERPROFILE\.ssh" -Force | Out-Null
    ssh-keygen -t ed25519 -f $sshKey -N '""' -C "$env:USERNAME@$env:COMPUTERNAME"
} else {
    Write-Skip "SSH key already exists"
}

if (Test-CommandExists 'quarto') {
    Write-Step "Installing TinyTeX via Quarto"
    quarto install tinytex --update-path
}

Write-Ok "Git/Quarto tooling ready"
