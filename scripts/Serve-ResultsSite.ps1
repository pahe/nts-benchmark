[CmdletBinding()]
param(
    [ValidateRange(1, 65535)]
    [int]$Port = 4173,
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
$sitePath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\site'))
$runsPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\runs'))

if (-not $SkipBuild) {
    & (Join-Path $PSScriptRoot 'Build-ResultsSite.ps1')
}

$python = Get-Command python -ErrorAction SilentlyContinue
if ($null -eq $python) {
    $python = Get-Command py -ErrorAction SilentlyContinue
}
if ($null -eq $python) {
    throw 'Python saknas. Installera Python eller använd en annan statisk webbserver för site-mappen.'
}

& $python.Source (Join-Path $PSScriptRoot 'serve_results_site.py') --site $sitePath --runs $runsPath --port $Port
