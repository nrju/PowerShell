$ErrorActionPreference = 'Stop'

if(-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
    Write-Error 'The `ffmpeg` command not found.'
}

<#
.SYNOPSIS
Converts a specified input video file to the Jellyfin-optimized format.
#>
function ConvertTo-JellyfinVideo {
    [CmdletBinding()]
    param (
        # The input media file path.
        [Parameter(Mandatory, Position = 0)]
        [string]
        $Path,

        # The output media file path.
        [Parameter(Mandatory)]
        [string]
        $OutFile,

        # The list of stream indices to include to the output.
        # If empty, all video and audio streams are included.
        [Parameter()]
        [int[]]
        $Stream,

        # Subtitle stream to extract in the form like:
        # @{"en.srt" = 7}
        [Parameter()]
        [hashtable]
        $Subtitle
    )

    #
    # Video/audio extraction and conversion
    #

    $mapArgList  =
        $Stream ?
            ($Stream | ForEach-Object { "-map", "0:$_" }) :
            @('-map', '0:v', '-map', '0:a')

    ffmpeg -i $Path `
        -c:v libx264 -preset veryfast -crf 23 `
        -profile:v high -level 4.1 -pix_fmt yuv420p `
        -vf "scale=-2:720" `
        -c:a aac -b:a 192k -ac 2 -ar 48000 `
        $mapArgList `
        $OutFile

    #
    # Subtitles extraction
    #

    if($Subtitle) {
        foreach($subtitleExtension in $Subtitle.Keys) {
            $subtitleOutFile = [System.IO.Path]::ChangeExtension($OutFile, $subtitleExtension)
            $subtitleStream = $Subtitle[$subtitleExtension]
            ffmpeg -i $Path -c copy -map "0:$subtitleStream" $subtitleOutFile
        }
    }
}

Set-Alias ctjfv ConvertTo-JellyfinVideo
