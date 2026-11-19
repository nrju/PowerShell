$ErrorActionPreference = 'Stop'

function Assert-Windows {
    if(-not $IsWindows) {
        Write-Error "This function is only supported on Windows."
    }
}

$devenv = "$env:ProgramFiles\Microsoft Visual Studio\18\Community\Common7\IDE\devenv.exe"

function Assert-VisualStudioInstalled {
    if(-not (Test-Path $devenv)) {
        Write-Error "The 'devenv.exe' executable is not found. " +
            "Please ensure Visual Studio is installed and its path is added to the PATH environment variable."
    }
}

<#
.SYNOPSIS
'Smart' Visual Studio launcher.

.DESCRIPTION
Visual studio launcher.

Searches specified folders for `*.sln` and `*.slnx` files and opens these files in the Visual
Studio IDE.
#>
function Start-VisualStudio {
    [CmdletBinding()]
    param (
        # Path to look for solution files.
        [Parameter(Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string[]]
        $Path = '.',

        # Lookup subdirectories recursively.
        [switch]
        $Recurse,

        # Opens Visual Studio without any solution even if no one was found.
        [switch]
        $Force
    )

    begin {
        Assert-Windows
        Assert-VisualStudioInstalled
        $paths = @{}
    }

    process {
        $Path | Get-Item -ErrorAction SilentlyContinue |
            ForEach-Object {
                if($_ -is [System.IO.FileInfo] -and $_.Extension -in '.sln','.slnx') {
                    $_
                }
                if($_ -is [System.IO.DirectoryInfo]) {
                    Get-ChildItem $_ -File -Filter '*.sln' -Recurse:$Recurse
                    Get-ChildItem $_ -File -Filter '*.slnx' -Recurse:$Recurse
                }
            } |
            ForEach-Object {
                $paths[$_.FullName] = $true
            }
    }

    end {
        $StartProcessArgs = @{
            FilePath = $devenv
            # It's required for VS works properly
            Environment  = @{ PATH = "$env:ProgramFiles\dotnet" }
        }

        if($paths.Keys.Count) {
            $paths.Keys | ForEach-Object {
                $StartProcessArgs.ArgumentList = @($_)
                Start-Process @StartProcessArgs
            }
        }
        elseif ($Force) {
            Start-Process @StartProcessArgs
        }
        else {
            Write-Warning 'No solution file found.'
        }
    }
}

Set-Alias savs Start-VisualStudio
