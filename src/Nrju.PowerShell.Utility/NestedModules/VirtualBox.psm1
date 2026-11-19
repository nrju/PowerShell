using namespace System.Collections
using namespace System.Collections.Generic
using namespace System.Management.Automation
using namespace System.Management.Automation.Language

$ErrorActionPreference = 'Stop'

if(-not (Get-Command 'vboxmanage' -ErrorAction SilentlyContinue)) {
    Write-Error "The 'vboxmanage' executable is not found in PATH. " +
      "Please ensure VirtualBox is installed and its path is added to the PATH environment variable."
}

class VMNameCompleter: IArgumentCompleter {
    hidden [string] $state = $false

    VMNameCompleter([string] $state) {
        $this.state = $state
    }

    [IEnumerable[CompletionResult]] CompleteArgument(
        [string] $CommandName,
        [string] $parameterName,
        [string] $wordToComplete,
        [CommandAst] $commandAst,
        [IDictionary] $fakeBoundParameters) {

            $resultList = [List[CompletionResult]]::new()

            $s = $this.state

            Get-VirtualBoxVM |
                Where-Object { -not $s -or  $_.State -eq $s } |
                Where-Object Name -Like "$wordToComplete*" |
                ForEach-Object { $resultList.Add([CompletionResult]::new($_.Name)) }

            return $resultList
        }
}

class VMNameCompleterAttribute: ArgumentCompleterAttribute, IArgumentCompleterFactory {
    hidden [string] $state

    VMNameCompleterAttribute() {
    }

    VMNameCompleterAttribute([string] $state) {
        $this.state = $state
    }

    [IArgumentCompleter] Create() { return [VMNameCompleter]::new($this.state) }
}

class VMNameValidateSetGenerator: IValidateSetValuesGenerator {
    [string[]] GetValidValues() {
        return [string[]](Get-VirtualBoxVM | ForEach-Object { $_.Name })
    }
}

class OSTypeCompleter: IArgumentCompleter {
    [IEnumerable[CompletionResult]] CompleteArgument(
        [string] $CommandName,
        [string] $parameterName,
        [string] $wordToComplete,
        [CommandAst] $commandAst,
        [IDictionary] $fakeBoundParameters) {

            $resultList = [List[CompletionResult]]::new()

            Get-VirtualBoxOSType |
                Where-Object Id -Like "$wordToComplete*" |
                ForEach-Object { $resultList.Add([CompletionResult]::new($_.Id)) }

            return $resultList
        }
}

class OSTypeCompleterAttribute: ArgumentCompleterAttribute, IArgumentCompleterFactory {
    [IArgumentCompleter] Create() { return [OSTypeCompleter]::new() }
}

class OSTypeValidateSetGenerator: IValidateSetValuesGenerator {
    [string[]] GetValidValues() {
        return [string[]](Get-VirtualBoxOSType | ForEach-Object { $_.Id })
    }
}

<#
.SYNOPSIS
Get VirtualBox OS types.
#>
function Get-VirtualBoxOSType {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [SupportsWildcards()]
        [OSTypeCompleterAttribute()]
        [string[]]
        $Filter = '*'
)
    begin {

        $vbox = New-Object -ComObject VirtualBox.VirtualBox

        $all = $vbox.GuestOSTypes | ForEach-Object {
            [PSCustomObject]@{
                Id = $_.Id
                Description = $_.Description
                FamilyId = $_.FamilyId
                FamilyDescription = $_.FamilyDescription
            }
        }

        $filtered = @{}
    }

    process {

        $Filter | ForEach-Object {
            $f = $_
            $all | Where-Object {
                $_.Id -Like $f -or
                $_.Description -Like $f -or
                $_.FamilyId -Like $f -or
                $_.FamilyDescription -Like $f
            } | ForEach-Object { $filtered[$_.Id] = $_ }
        }
    }

    end {
        $filtered.Values | Sort-Object FamilyId, Id
    }
}

<#
.SYNOPSIS
Get VirtualBox VMs.
#>
function Get-VirtualBoxVM {
    [CmdletBinding()]
    param (
        # The name or id of VM to get. Wildcards are supported.
        # If not specified, all VMs will be returned.
        [Parameter(Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [SupportsWildcards()]
        [VMNameCompleterAttribute()]
        [string[]]
        $Name = '*'
    )

    begin {
        $all = vboxmanage list vms | ForEach-Object {
            if($_ -match '^"(.*)" \{(.*)\}$') {
                [pscustomobject]@{
                    Id = [guid]$Matches[2]
                    Name = $Matches[1]
                }
            }
        }

        $filteredIds = @{}
    }

    process {
        $Name | ForEach-Object {
            $n = $_
            $all | Where-Object { $_.Name -Like $n } |
                ForEach-Object { $filteredIds[$_.Id] = $true }
        }
    }

    end {
        $filteredIds.Keys | ForEach-Object {
            $vmProperties = @{}

            vboxmanage showvminfo ($_.Guid) --machinereadable | ForEach-Object {
                $p = $_.Split('=', 2)
                if($p.Length -eq 2) {
                    $vmProperties[$p[0].Trim()] = $p[1].Trim('"', " ")
                }
            }

            [PSCustomObject]@{
                Id = $vmProperties['UUID']
                Name = $vmProperties['name']
                State = $vmProperties['VMState']
                OSType = $vmProperties['ostype']
                Memory = $vmProperties['memory']
                CPUs = $vmProperties['cpus']
                CfgFile = $vmProperties['CfgFile'] -replace '\\\\', '\'
            }
        } | Sort-Object Name
    }
}

<#
.SYNOPSIS
Starts a specified VirtualBox VM.
#>
function Start-VirtualBoxVM {
    [CmdletBinding()]
    param (
        # The name or id of VM to start.
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [VMNameCompleterAttribute("poweroff")]
        [string[]]
        $Name,

        # Parameter help description
        [Parameter()]
        [string]
        [ValidateSet('Gui', 'Headless', 'SDL', 'Separate')]
        $Type = 'Headless'
    )

    process {
        $Name | ForEach-Object {
            vboxmanage startvm "--type=$($Type.ToLower())" $_
        }
    }
}

<#
.SYNOPSIS
Unregisters a specified VirtualBox VM.
#>
function Remove-VirtualBoxVM {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        # The name or id of VM to unregister.
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [SupportsWildcards()]
        [VMNameCompleterAttribute()]
        [string[]]
        $Name,


        # If specified, the VM's files will be deleted from disk as well.
        [switch]
        $DeleteFiles,

        # Suppress confirmation prompt when unregistering the VM.
        [switch]
        $Force

    )

    begin {
        $all = Get-VirtualBoxVM
        $filtered = @{}
    }

    process {
        $Name | ForEach-Object {
            $n = $_
            $all | Where-Object Name -Like $n |
                ForEach-Object { $filtered[$_.Name] = $_ }
        }
    }

    end {
        $del = @()

        # If $DeleteFiles is specified, always prompt for confirmation
        if($DeleteFiles) {
            $del += '--delete'
            $ConfirmPreference = 'Low'
        }

        # If $Force is specified and confirmation is not already required,
        # suppress confirmation prompt
        if($Force -and -not $Confirm) {
            $ConfirmPreference = 'None'
        }

        $filtered.Values | ForEach-Object {
            if($PSCmdlet.ShouldProcess($_.Name, "Unregister VirtualBox VM")) {
                vboxmanage unregistervm $_.Name $del
            }
        }
    }
}

<#
.SYNOPSIS
Clones a specified VirtualBox VM.
#>
function Copy-VirtualBoxVM {
    [CmdletBinding()]
    param (
        # The name or id of VM to clone.
        [Parameter(Mandatory, Position = 0)]
        [ValidateSet([VMNameValidateSetGenerator])]
        [string]
        $Name,

        # Name of the new VM.
        [Parameter(Mandatory, Position = 1)]
        [string]
        $NewName,

        # BIOS DMI serial number to set for the new VM.
        [Parameter()]
        [string]
        $Serial
    )

    if(-not $Serial) {
        $Serial = $NewName.ToLower()
    }

    $cloneArgs = @($Name, "--name=$NewName", "--register")

    vboxmanage snapshot $Name list --machinereadable | ForEach-Object {
        if($_ -match '^CurrentSnapshot="(.*)"$') {
            $cloneArgs += "--snapshot=$($Matches[1])"
        }
    }

    vboxmanage clonevm $cloneArgs
    vboxmanage setextradata $NewName "VBoxInternal/Devices/efi/0/Config/DmiSystemSerial" $Serial
}

<#
.SYNOPSIS
Updates a specified VirtualBox VM.
#>
function Update-VirtualBoxVM {
    [CmdletBinding()]
    param (
        # The name or id of VM to set OS type for.
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [SupportsWildcards()]
        [VMNameCompleterAttribute()]
        [string[]]
        $Name,

        # The OS type to set for the VM.
        [Parameter()]
        [ValidateSet([OSTypeValidateSetGenerator])]
        [string]
        $OSType
    )

    begin {
        $all = Get-VirtualBoxVM
        $filtered = @{}
    }

    process {
        $Name | ForEach-Object {
            $n = $_
            $all | Where-Object Name -Like $n |
                ForEach-Object { $filtered[$_.Id] = $_ }
        }
    }

    end {
        $filtered.Keys | ForEach-Object {
            if($OSType) {
                vboxmanage modifyvm $_ --ostype $OSType
            }
        }
    }
}

<#
.SYNOPSIS
Compact the specified VirtualBox disk image.
#>
function Optimize-VirtualBoxDisk {
    [CmdletBinding()]
    param (
        # The path to the VirtualBox disk image file.
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [SupportsWildcards()]
        [string[]]
        $Path
    )

    begin {
        $paths = @{}
    }

    process {
        $Path | Get-Item -ErrorAction SilentlyContinue |
            ForEach-Object { $paths[$_.FullName] = $true }
    }

    end {
        $paths.Keys | ForEach-Object {
            vboxmanage modifymedium disk $_ --compact
        }
    }
}

function Show-VirtualBoxVM {
    [CmdletBinding()]
    param (
        # The name or id of VM to show.
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [SupportsWildcards()]
        [VMNameCompleterAttribute("running")]
        [string[]]
        $Name
    )

    begin {
        $vbox = New-Object -ComObject VirtualBox.VirtualBox
        $all = $vbox.machines
        $filtered = @{}
    }

    process {
        $Name | ForEach-Object {
            $n = $_
            $all | Where-Object { $_.Name -Like $n -and $_.State -eq 6 } |
                ForEach-Object { $filtered[$_.Id] = $_ }
        }
    }

    end {
        $filtered.Values | ForEach-Object {
            $_.showConsoleWindow()
        }
    }
}

Set-Alias 'gvbvm' 'Get-VirtualBoxVM'
Set-Alias 'savbvm' 'Start-VirtualBoxVM'
Set-Alias 'cpvbvm' 'Copy-VirtualBoxVM'
Set-Alias 'rvbvm' 'Remove-VirtualBoxVM'
Set-Alias 'upvbvm' 'Update-VirtualBoxVM'
