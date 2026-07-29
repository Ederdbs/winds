# Central configuration: the one place to edit when adding/removing packages
# or bumping versions for a new machine.

$Config = @{
    Prereqs = @{
        ChocoPackages = @('powershell-core', 'microsoft-windows-terminal')
    }
    Compilers = @{
        # rtools: toolchain R uses internally to compile packages from source.
        # mingw: standalone gcc/g++/gfortran for general C++/Fortran work.
        ChocoPackages = @('rtools', 'mingw')
    }
    R = @{
        ChocoPackages = @('r.project')
    }
    Python = @{
        ChocoPackages = @('python3')
        VenvPath      = "$PSScriptRoot\.venv"
    }
    Ides = @{
        ChocoPackages       = @('vscode', 'docker-desktop')
        PositronWingetId    = 'Posit-PBC.Positron'
    }
    AiTools = @{
        ChocoPackages = @('nodejs-lts', 'ollama')
    }
    GitQuarto = @{
        ChocoPackages = @('git', 'git-lfs', 'quarto', 'pandoc')
    }
    OpenBlas = @{
        GitHubRepo   = 'OpenMathLib/OpenBLAS'
        AssetPattern = '*x64*.zip'
    }
}
