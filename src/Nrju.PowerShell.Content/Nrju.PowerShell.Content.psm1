$ErrorActionPreference = "Stop"

<#
.SYNOPSIS
Compare the content of two files.
#>
function Compare-Content {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0)]
        [string]
        $ReferencePath,

        [Parameter(Mandatory, Position = 1)]
        [string]
        $DifferencePath
    )

    $c1 = Get-Content -LiteralPath $ReferencePath
    $c2 = Get-Content -LiteralPath $DifferencePath
    Compare-Object $c1 $c2
}

<#
.SYNOPSIS
Updates the content of a file.
#>
function Update-Content {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [SupportsWildcards()]
        [string[]]
        # The path to the file to update.
        $Path,

        [Parameter(Position = 1, Mandatory)]
        [scriptblock]
        # The script block to execute for every line of the file.
        # The line will be replaced with the output of this block
        # if output is empty the line will be removed.
        $Process,

        [Parameter()]
        [scriptblock]
        # The script block to execute before processing the file.
        $Begin = {},

        [Parameter()]
        [scriptblock]
        # The script block to execute  after processing the file.
        $End = {}
    )

    begin {
        $paths = @{}
    }

    process {
        $Path | Get-Item -ErrorAction SilentlyContinue |
            Where-Object { $_ -is [System.IO.FileInfo] } |
            ForEach-Object { $paths[$_.FullName] = $true }
    }

    end {
        $paths.Keys | ForEach-Object {
            $tmp = [System.IO.Path]::GetTempFileName()

            Get-Content $_ |
                ForEach-Object -Begin $Begin -Process $Process -End $End |
                Out-File $tmp -Force

            Move-Item $tmp $_ -Force
        }
    }
}

<#
.SYNOPSIS
Updates the EOL characters of a file.
#>
function Update-ContentEol {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [SupportsWildcards()]
        [string[]]
        # The path to the file to update.
        $Path,

        [Parameter(Mandatory)]
        [ValidateSet("Unix", "Dos")]
        [string]
        # The EOL type (Dos or Unix).
        $Eol
    )

    begin {
        switch($Eol) {
            'Unix' {
                $el = "`n"
            }
            'Dos' {
                $el = "`r`n"
            }
        }
    }

    process {
        $Path | Get-Item -ErrorAction SilentlyContinue |
            Where-Object { $_ -is [System.IO.FileInfo] } |
            Select-Object -ExpandProperty FullName -Unique |
            ForEach-Object {
                $tmp = New-TemporaryFile

                Get-Content $_ | ForEach-Object {
                    Add-Content $tmp -Value "$_$el" -NoNewline
                }

                Move-Item $tmp $_ -Force
            }
    }
}

<#
.SYNOPSIS
Updates the EOL characters of a file to Unix format.
#>
function Update-ContentEolToUnix {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [SupportsWildcards()]
        [string[]]
        # The path to the file to update.
        $Path
    )

    process {
        $Path | Update-ContentEol -Eol 'Unix'
    }
}

<#
.SYNOPSIS
Updates the EOL characters of a file to Dos format.
#>
function Update-ContentEolToDos {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [SupportsWildcards()]
        [string[]]
        # The path to the file to update.
        $Path
    )

    process {
        $Path | Update-ContentEol -Eol 'Dos'
    }
}

Set-Alias fdiff Compare-Content
Set-Alias udc Update-Content
Set-Alias sed Update-Content
Set-Alias udeol Update-ContentEol
Set-Alias dos2unix Update-ContentEolToUnix
Set-Alias unix2dos Update-ContentEolToDos
