$ErrorActionPreference = "Stop"

<#
.SYNOPSIS
    Resets windows system tray settings to default.
#>
function Reset-SystemTray {
    Stop-Process -Name 'explorer' -Force

    Remove-Item 'HKCU:\Control Panel\NotifyIconSettings' -Recurse -Force -ErrorAction Continue

    Remove-ItemProperty `
        'HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\TrayNotify\' `
            -Name 'IconStreams','PastIconsStream' -ErrorAction Continue

    Start-Process 'explorer'
}
