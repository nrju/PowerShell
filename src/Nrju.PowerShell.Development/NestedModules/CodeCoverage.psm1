$ErrorActionPreference = 'Stop'

function Assert-ReportGeneratorInstalled {
    if (-not (Get-Command reportgenerator -ErrorAction SilentlyContinue)) {
        throw "ReportGenerator is not installed. " +
            "Please install it from https://github.com/danielpalme/ReportGenerator."
    }
}

<#
.SYNOPSIS
Generates a code coverage report from the coverage files.
#>
function New-CodeCoverageReport {
    [CmdletBinding()]
    param (
        # The root path to the coverage files.
        [Parameter(Position = 0)]
        [string]
        $Path = (Get-Location).Path,

        # The output directory for the report. If not specified, a temporary directory will be used.
        [Parameter(Position = 1)]
        [string]
        $OutDir,

        # If specified, the report will be generated silently and the path to the index.html file
        # will be outputted.
        [switch]
        $Silent
    )

    Assert-ReportGeneratorInstalled

    if(-not $OutDir) {
        $p = [System.IO.Path]
        $OutDir = Join-Path $p::GetTempPath() $p::GetRandomFileName()
    }

    $stderr = (reportgenerator "-reports:$Path/**/coverage.*" `
        -targetdir:$OutDir -reporttypes:Html 2>&1)

    if($?) {
        $indexhtml = Join-Path $OutDir 'index.html'

        if($Silent) {
            Write-Output $indexhtml
        }
        else {
            Invoke-Item $indexhtml
        }
    }
    else {
        Write-Error ("", $stderr | Out-String)
    }
}

Set-Alias nccr New-CodeCoverageReport
