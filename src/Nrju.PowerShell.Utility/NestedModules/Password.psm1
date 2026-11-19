$ErrorActionPreference = "Stop"

[Flags()]
Enum CharKind {
    None = 0
    UpperCase = 1
    LowerCase = 2
    Digit = 4
    Symbol = 8
    All = 15
}

$CharKindChars = @{
    [CharKind]::UpperCase = 'A'..'Z'
    [CharKind]::LowerCase = 'a'..'z'
    [CharKind]::Digit = [char[]](48..57)
    [CharKind]::Symbol = [char[]](33..47 + 58..64 + 91..96 + 123..126)
}

Class CharKindValuesGenerator : System.Management.Automation.IValidateSetValuesGenerator {
    [string[]] GetValidValues() {
        return ($Script:PasswordCharKind.Keys)
    }
}

<#
.SYNOPSIS
Validates the strength of a password.
#>
function Test-PasswordStrength {
    [CmdletBinding()]
    param (
        # The password(s) to validate.
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [SecureString[]]
        $Password,

        # Minimum required length of the password.
        [Parameter()]
        [int]
        [ValidateRange(1, [int]::MaxValue)]
        $MinLength = 8,

        # Required character kinds in the password.
        [Parameter()]
        [CharKind]
        $RequiredCharKind = [CharKind]::All
    )

    process {
        $Password | ConvertFrom-SecureString -AsPlainText |
            ForEach-Object {
                # Check min length requirements
                if($_.Length -lt $MinLength) {
                    return $false
                }

                foreach($charKind in $CharKindChars.Keys) {
                    if($charKind -band $RequiredCharKind) {
                        # The char from this $charKind set must be found in the password
                        $ok = $false
                        foreach($c in $_.GetEnumerator()) {
                            if($CharKindChars[$charKind].Contains($c)) {
                                $ok = $true
                                break
                            }
                        }
                        if(-not $ok) {
                            return $false
                        }
                    }
                }

                return $true
            }
    }
}

<#
.SYNOPSIS
Generates a random password.
#>
function Get-RandomPassword {
    [CmdletBinding()]
    [OutputType([SecureString], [string])]
    param (
        # Length of the generated password.
        [Parameter()]
        [ValidateRange(8, [int]::MaxValue)]
        [int]
        $Length = 16,

        # Number of passwords to generate.
        [Parameter()]
        [ValidateRange(1, [int]::MaxValue)]
        [int]
        $Count = 1,

        # Required character kinds in the generated password.
        [Parameter()]
        [CharKind]
        # Character kinds to use.
        $RequiredCharKind = [CharKind]::All,

        # Optional characters to exclude from the generated password.
        [Parameter()]
        [string]
        # Characters to exclude.
        $ExcludedChars = "",

        # Return the generated password(s) as plain text instead of SecureString.
        [switch]
        $AsPlainText
    )

    $chars = $CharKindChars.GetEnumerator() |
        Where-Object { $_.Key -band $RequiredCharKind } |
        ForEach-Object { $_.Value } |
        Where-Object { -not $ExcludedChars.Contains($_) }

    for($i = 0; $i -lt $Count; $i++) {
        while($true) {
            $candidate = Get-Random -Minimum 0 -Maximum $chars.Length -Count $Length |
                ForEach-Object { $chars[$_] } | Join-String |
                ConvertTo-SecureString -AsPlainText -Force

            if(Test-PasswordStrength $candidate -MinLength $Length -RequiredCharKind $RequiredCharKind) {
                $AsPlainText ? (ConvertFrom-SecureString $candidate -AsPlainText) : $candidate
                break
            }
        }
    }
}

Set-Alias tpwd Test-PasswordStrength
Set-Alias gpwd Get-RandomPassword
