$ErrorActionPreference = 'Stop'

function Assert-CodeInstalled {
    if (-not (Get-Command code -ErrorAction SilentlyContinue)) {
        throw "Visual Studio Code is not installed or not in the PATH."
    }
}

<#
.SYNOPSIS
Opens the specified paths in Visual Studio Code.
.DESCRIPTION
Opens one or more file or folder paths in VS Code in separate windows.
If no paths are specified, opens the current directory.
Supports wildcard patterns and accepts input from the pipeline.
Supports opening remote paths via SSH using the Remote - SSH extension.
#>
function Start-VSCode {
    [CmdletBinding()]
    param (
        # Path(s) to open in VS Code. Can be a file or folder path. Supports wildcards and pipeline input.
        [Parameter(Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName,
            ParameterSetName = 'ByPath')]
        [SupportsWildcards()]
        [string[]]
        $Path = '.',

        # Remote host to connect to via SSH. Must be used with -RemotePath.
        [Parameter(Mandatory, ParameterSetName = 'Remote')]
        [string]
        $RemoteHost,

        # Path on the remote host to open in VS Code. Must be used with -RemoteHost.
        [Parameter(Mandatory, ParameterSetName = 'Remote')]
        [string]
        $RemotePath
    )

    begin {
        Assert-CodeInstalled

        if($PSCmdlet.ParameterSetName -eq 'ByPath') {
            $paths = @{}
        }
    }

    process {
        if($PSCmdlet.ParameterSetName -eq 'ByPath') {
            $Path | Get-Item -ErrorAction SilentlyContinue |
                ForEach-Object { $paths[$_.FullName] = $true }
        }
    }

    end {
        if($PSCmdlet.ParameterSetName -eq 'ByPath') {
            $paths.Keys | ForEach-Object { code -n $_ }
        }

        if($PSCmdlet.ParameterSetName -eq 'Remote') {
            code --folder-uri "vscode-remote://ssh-remote+$RemoteHost/$RemotePath" -n
        }
    }
}

Set-Alias sacode Start-VSCode
