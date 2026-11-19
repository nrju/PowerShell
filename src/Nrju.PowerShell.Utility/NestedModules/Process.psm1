$ErrorActionPreference = "Stop"

<#
.SYNOPSIS
Gets the current process.
#>
function Get-CurrentProcess {
    [System.Diagnostics.Process]::GetCurrentProcess()
}

<#
.SYNOPSIS
Gets the parent process.
#>
function Get-ParentProcess {
    Get-CurrentProcess | Select-Object -ExpandProperty Parent
}

Set-Alias gcp -Value Get-CurrentProcess
Set-Alias gpp -Value Get-ParentProcess
