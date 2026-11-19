using namespace System.Collections
using namespace System.Collections.Generic
using namespace System.Management.Automation
using namespace System.Management.Automation.Language
using namespace System.Security.Principal

$ErrorActionPreference = 'Stop'

$EnvRegKey = @{
    System = "HKLM:\System\CurrentControlSet\Control\Session Manager\Environment"
    User = "HKCU:\Environment"
}

class EnvironmentVariableCompleter: IArgumentCompleter {
    [IEnumerable[CompletionResult]] CompleteArgument(
        [string] $CommandName,
        [string] $parameterName,
        [string] $wordToComplete,
        [CommandAst] $commandAst,
        [IDictionary] $fakeBoundParameters) {

            $resultList = [List[CompletionResult]]::new()

            $scope = $fakeBoundParameters.Scope ?? 'System','User'

            Get-EnvironmentVariable -Scope $scope |
                Where-Object Name -Like "$wordToComplete*" |
                ForEach-Object { $resultList.Add([CompletionResult]::new($_.Name)) }

            return $resultList
    }
}

class EnvironmentVariableCompleterAttribute: ArgumentCompleterAttribute, IArgumentCompleterFactory {
    [IArgumentCompleter] Create() { return [EnvironmentVariableCompleter]::new() }
}

<#
Gets environment variable(s).
#>
function Get-EnvironmentVariable {
    [CmdletBinding()]
    param (
        # The name of environment variable to get. Wildcards are supported.
        # If not specified, all variables will be returned.
        [Parameter(Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [SupportsWildcards()]
        [EnvironmentVariableCompleterAttribute()]
        [string[]]
        $Name = '*',

        # The scope(s) of environment variables to return.
        [Parameter()]
        [ValidateSet('System', 'User')]
        [string[]]
        $Scope
    )

    begin {
        if(-not $Scope) {
            $Scope = 'System', 'User'
        }

        $all = $Scope | ForEach-Object {
            $regScope = $_
            $regKeyPath = $EnvRegKey[$regScope]
            $regKey = Get-Item $regKeyPath

            $regKey.GetValueNames() | ForEach-Object {
                $regValueName = $_
                $regValue = $regKey.GetValue($regValueName, $null, 1)

                [PSCustomObject]@{
                    Scope = $regScope
                    Name = $regValueName
                    Value = $regValue
                }
            }
        }

        $filtered = @{}
    }

    process {
        $Name | ForEach-Object {
            $all | Where-Object Name -Like $_ |
                ForEach-Object { $filtered["$($_.Scope)/$($_.Name)"] = $_ }
        }
    }

    end {
        $filtered.Values | Sort-Object Scope, Name
    }
}

<#
Updates or creates environment variable(s).
#>
function Set-EnvironmentVariable {
    [CmdletBinding()]
    param (
        # The name of an environment variable to set.
        [Parameter(Mandatory, Position = 0)]
        [EnvironmentVariableCompleterAttribute()]
        [string]
        $Name,

        # The value of an environment variable to set.
        [Parameter(Mandatory)]
        [string]
        $Value,

        # The scope of an environment variable to set.
        [Parameter()]
        [ValidateSet('System', 'User')]
        [string]
        $Scope = 'User'
    )

    $regKeyPath = $EnvRegKey[$Scope]
    Set-ItemProperty $regKeyPath -Name $Name -Value $Value -Type ExpandString
}

<#
Deletes environment variable(s).
#>
function Remove-EnvironmentVariable {
    [CmdletBinding()]
    param (
        # The name of an environment variable to remove.
        [Parameter(Mandatory, Position = 0)]
        [EnvironmentVariableCompleterAttribute()]
        [string]
        $Name,

        # The scope of an environment variable to remove.
        [Parameter()]
        [ValidateSet('System', 'User')]
        [string]
        $Scope = 'User'
    )

    $regKeyPath = $EnvRegKey[$Scope]
    Remove-ItemProperty $regKeyPath -Name $Name

}

<#
.SYNOPSIS
    Resets the PATH environment variable to its default value.
#>
function Reset-PathEnvironmentVariable {
    [CmdletBinding()]
    param (
        # The scope of the PATH environment variable to reset.
        [Parameter()]
        [ValidateSet('System', 'User')]
        [string[]]
        $Scope = @('System', 'User')
    )

    if($Scope -contains 'System') {
        $principal = [WindowsPrincipal][WindowsIdentity]::GetCurrent()
        $isAdmin = $principal.IsInRole([WindowsBuiltInRole]::Administrator)

        if(-not $isAdmin) {
            throw "Resetting the system PATH requires administrative privileges. " +
                "Please run PowerShell as an administrator."
        }
    }

    $systemPathValue = '%SystemRoot%\System32;%SystemRoot%;%SystemRoot%\System32\Wbem'
    $userPathValue = "%USERPROFILE%\bin"

    if($Scope -contains 'System') {
        $regKeyPath = $EnvRegKey['System']
        Set-ItemProperty $regKeyPath -Name 'Path' -Value $systemPathValue -Type ExpandString
    }

    if($Scope -contains 'User') {
        $regKeyPath = $EnvRegKey['User']
        Set-ItemProperty $regKeyPath -Name 'Path' -Value $userPathValue -Type ExpandString
    }
}

Set-Alias genv Get-EnvironmentVariable
Set-Alias senv Set-EnvironmentVariable
Set-Alias renv Remove-EnvironmentVariable
Set-Alias rspath Reset-PathEnvironmentVariable
