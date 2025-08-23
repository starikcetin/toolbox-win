#
# Restarts the system.
# Boots directly into the BIOS.
#

param([switch]$Elevated)

function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
    $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

if ((Test-Admin) -eq $false)  {
    if ($elevated) {
        Write-Host "Tried to elevate to admin priviliges, did not work, aborting. Try running the script as an Administrator."
    } else {
        Start-Process powershell.exe -Verb RunAs -ArgumentList ('-noprofile -file "{0}" -elevated' -f ($myinvocation.MyCommand.Definition))
    }
    exit
}

$title = "Are you sure?"
$message = "Are you sure you want to restart your computer? It will boot directly into the BIOS."
$choices = "&Yes", "&No"
$decision = $Host.UI.PromptForChoice($title, $message, $choices, 1)

if ($decision -eq 0) {
    Write-Host "Restarting into BIOS..."
    shutdown /r /fw /t 0
}
else {
    Write-Host "Cancelled restart as per user choice."
}
