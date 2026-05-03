<#
.SYNOPSIS
  Remove the top-left "AI" badge from Dreamina-generated MP4s.

.DESCRIPTION
  Wraps ffmpeg's delogo filter with a radial-feathered gaussian blur on top
  to eliminate the visible interpolation seam. Works on a single file or a
  whole directory. Defaults are calibrated for Dreamina vertical 834x1112.

.EXAMPLE
  ./delogo.ps1 video.mp4
.EXAMPLE
  ./delogo.ps1 C:\path\to\folder
.EXAMPLE
  ./delogo.ps1 video.mp4 result.mp4 -LogoX 10 -LogoY 10 -LogoW 66 -LogoH 52
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)] [string]$Path,
    [Parameter(Position = 1)]            [string]$Output,
    [int]$LogoX = 10, [int]$LogoY = 10, [int]$LogoW = 66, [int]$LogoH = 52,
    [int]$BlurW = 84, [int]$BlurH = 74,
    [int]$BlurCx = 40, [int]$BlurCy = 34,
    [int]$BlurR0 = 28, [int]$BlurR1 = 40,
    [double]$BlurSigma = 2,
    [int]$Crf = 18, [string]$Preset = 'medium'
)

if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
    Write-Error "ffmpeg not found in PATH. Install from https://ffmpeg.org/"
    exit 2
}

$fr = $BlurR1 - $BlurR0
$filter = "[0:v]delogo=x=${LogoX}:y=${LogoY}:w=${LogoW}:h=${LogoH}[clean];[clean]split=2[base][src];[src]crop=${BlurW}:${BlurH}:0:0,gblur=sigma=${BlurSigma}[blur];color=c=black:s=${BlurW}x${BlurH}:r=60:d=20,format=gray,geq=lum=255*max(0\,min(1\,(${BlurR1}-hypot(X-${BlurCx}\,Y-${BlurCy}))/${fr}))[mask];[blur][mask]alphamerge[blur_a];[base][blur_a]overlay=0:0:format=auto:shortest=1[out]"

function Invoke-Delogo {
    param([string]$In, [string]$Out)
    Write-Host ">> $((Split-Path $In -Leaf)) -> $((Split-Path $Out -Leaf))"
    & ffmpeg -y -loglevel error -stats `
        -i $In `
        -filter_complex $filter `
        -map '[out]' -map '0:a?' `
        -c:v libx264 -crf $Crf -preset $Preset `
        -c:a copy `
        $Out
    if ($LASTEXITCODE -ne 0) { throw "ffmpeg failed on $In" }
}

if (Test-Path -LiteralPath $Path -PathType Container) {
    $count = 0
    Get-ChildItem -LiteralPath $Path -File |
        Where-Object { $_.Extension -in '.mp4', '.mov', '.MP4', '.MOV' -and $_.BaseName -notlike '*-clean' } |
        ForEach-Object {
            $out = Join-Path $_.Directory.FullName ($_.BaseName + '-clean' + $_.Extension)
            Invoke-Delogo -In $_.FullName -Out $out
            $count++
        }
    Write-Host "Done. Processed $count file(s)."
}
elseif (Test-Path -LiteralPath $Path -PathType Leaf) {
    if (-not $Output) {
        $item = Get-Item -LiteralPath $Path
        $Output = Join-Path $item.Directory.FullName ($item.BaseName + '-clean' + $item.Extension)
    }
    Invoke-Delogo -In $Path -Out $Output
}
else {
    Write-Error "'$Path' is not a file or directory."
    exit 1
}
