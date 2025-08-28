#
# Allows using .nvmrc files with https://github.com/coreybutler/nvm-windows
#
# Pass the -noInstall flag if you do not want to automatically install the version in .nvmrc if it is missing.
#
# Original source: https://gist.github.com/danpetitt/e87dabb707079e1bfaf797d0f5f798f2
# Why is this necessary: https://github.com/coreybutler/nvm-windows/issues/388#issuecomment-418513601
#

[CmdletBinding()]
param (
    [switch]$noInstall = $false
)

if (-not (Test-Path .nvmrc -PathType Any)) {
    throw ".nvmrc file not found"
}

$version = $(Get-Content .nvmrc).replace( 'v', '' ).replace( 'lts/', '' )
$response = nvm use $version

if ($response -match 'not installed') {
    if ($noInstall) {
        throw "Refusing to install missing version $version due to noInstall flag"
    }

    if ($response -match '64-bit') {
        $response = nvm install $version x64
    } else {
        $response = nvm install $version x86
    }

    Write-Host $response
    $response = nvm use $version
}

Write-Host $response
