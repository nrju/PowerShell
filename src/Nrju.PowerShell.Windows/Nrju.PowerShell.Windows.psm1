$ErrorActionPreference = 'Stop'

if(-not $IsWindows) {
    Write-Error "This module is only supported on Windows."
}
