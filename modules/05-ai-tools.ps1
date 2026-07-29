# Installs Node.js (required by the CLI tools below), Ollama, Claude Code
# and OpenCode.

. "$PSScriptRoot\_helpers.ps1"
. "$PSScriptRoot\..\config.ps1"

Write-Step "Installing AI tooling (Node.js, Ollama)"
Invoke-ChocoInstall -Packages $Config.AiTools.ChocoPackages

if (-not (Test-CommandExists 'npm')) {
    throw "npm not found on PATH after installing Node.js. Restart the shell and re-run this script."
}

Write-Step "Installing Claude Code and OpenCode CLIs"
npm install -g @anthropic-ai/claude-code
npm install -g opencode-ai

Write-Ok "AI tools installed (claude, opencode, ollama)"
