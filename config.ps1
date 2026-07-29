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
        # System dependency for the Rgraphviz Bioconductor package.
        SystemChocoPackages = @('graphviz')
    }
    Python = @{
        ChocoPackages = @('python3')
        VenvPath      = "$PSScriptRoot\.venv"
    }
    Optimize = @{
        # renv cache on a stable path is reused across projects and machine
        # rebuilds. Point this at your fastest local disk (not a network share
        # and not a OneDrive-synced folder).
        RenvCachePath        = "$env:LOCALAPPDATA\renv\cache"
        # Extra folders to exclude from Defender scanning -- add your data
        # directories here, e.g. @('C:\work\data', 'D:\datasets').
        ExtraExclusionPaths  = @()
    }
    Ml = @{
        # PyTorch on Windows defaults to CPU-ONLY wheels on PyPI. CUDA builds
        # live on a separate index, so the URL below is what actually gets you
        # a GPU-capable torch. Variants offered: cu118, cu126, cu128.
        # Pick one matching your NVIDIA driver (newer variant = newer driver
        # required); check https://pytorch.org/get-started/locally/ if unsure.
        TorchCudaIndex   = 'https://download.pytorch.org/whl/cu126'
        TorchPackages    = @('torch', 'torchvision', 'torchaudio')

        # TensorFlow 2.10 was the LAST release supporting GPU on native
        # Windows; 2.11+ is CPU-only there and GPU requires WSL2. We install
        # current TensorFlow (CPU on Windows) rather than pinning the ancient
        # 2.10 -- see the README "GPU support" section for the WSL2 route.
        TensorFlowPackage = 'tensorflow'
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
