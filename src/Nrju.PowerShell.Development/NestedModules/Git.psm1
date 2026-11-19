$ErrorActionPreference = 'Stop'

function Assert-GitInstalled {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw "Git is not installed or not found in PATH."
    }
}

<#
.SYNOPSIS
Removes ignored files from the working tree.
#>
function Clear-GitIgnoredFiles {
    [CmdletBinding()]
    param (
        # If specified, untracked files will be removed as well.
        # By default, only ignored files are removed.
        [switch]
        $Untracked
    )

    Assert-GitInstalled
    $x = $Untracked ? "-x" : "-X"
    git clean -df $x -e '!.vs' -e '!*.suo' -e '!.vscode/*'
}

<#
.SYNOPSIS
Starts a new Git flow by creating and pushing a new branch.
#>
function Start-GitFlow {
    [CmdletBinding()]
    param (
        # The name of the new branch to create and push. This parameter is mandatory.
        [Parameter(Mandatory, Position = 0)]
        [string]
        $Name,

        # The base branch to create the new branch from.
        # If not specified, the current branch will be used as the base.
        [Parameter()]
        [string]
        $Base
    )

    Assert-GitInstalled

    if(-not $Base) {
        $Base = (git branch --show-current)
    }

    git checkout $Base -b $Name &&
        git push -u origin $Name
}

Set-Alias clgi Clear-GitIgnoredFiles
Set-Alias sagf Start-GitFlow
