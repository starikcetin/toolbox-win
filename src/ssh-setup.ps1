#
# Installs Windows OpenSSH client.
# Generates a new SSH key pair.
# Sets up the SSH config file.
# Opens the SSH key settings pages of Github, GitLab, and Bitbucket.
# Opens the newly-generated SSH public key file.
#
# WARNING: This script renames your existing .ssh folders to '.ssh.backup_DATETIME'.
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
        Start-Process powershell.exe -Verb RunAs -ArgumentList ('-noprofile -noexit -file "{0}" -elevated' -f ($myinvocation.MyCommand.Definition))
    }
    exit
}

function Out-FileUtf8NoBom {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory, Position=0)] [string] $LiteralPath,
    [switch] $Append,
    [switch] $NoClobber,
    [AllowNull()] [int] $Width,
    [switch] $UseLF,
    [Parameter(ValueFromPipeline)] $InputObject
  )

  $dir = Split-Path -LiteralPath $LiteralPath
  if ($dir) { $dir = Convert-Path -ErrorAction Stop -LiteralPath $dir } else { $dir = $pwd.ProviderPath}
  $LiteralPath = [IO.Path]::Combine($dir, [IO.Path]::GetFileName($LiteralPath))

  if ($NoClobber -and (Test-Path $LiteralPath)) {
    Throw [IO.IOException] "The file '$LiteralPath' already exists."
  }

  $sw = New-Object System.IO.StreamWriter $LiteralPath, $Append

  $htOutStringArgs = @{}
  if ($Width) {
    $htOutStringArgs += @{ Width = $Width }
  }

  try {
    $Input | Out-String -Stream @htOutStringArgs | ForEach-Object {
      if ($UseLf) {
        $sw.Write($_ + "`n")
      }
      else {
        $sw.WriteLine($_)
      }
    }
  } finally {
    $sw.Dispose()
  }
}

Write-Host "`n====== Installing OpenSSH Client"
Add-WindowsCapability -Online -Name OpenSSH.Client

Write-Host "`n====== Setting SSH agent to automatic start"
Set-Service ssh-agent -StartupType Automatic

Write-Host "`n====== Starting SSH agent"
Start-Service ssh-agent

$sshFolder = "$env:USERPROFILE\.ssh"

$userName = $env:username
$userName = $userName.replace(' ','-')

$hostName = hostname
$hostName = $hostName.replace(' ','-')

$dateTime = Get-Date -UFormat "%Y-%m-%d_%H-%M"

$keyId = ($userName + "@" + $hostName + "_" + $dateTime)

$keyFilePath = ($sshFolder + "\" + $keyId)

$sshBackupName = ".ssh.backup_$dateTime"

Write-Host "`n====== Renaming directory $sshFolder to $sshBackupName"
Rename-Item -LiteralPath "$sshFolder" -NewName "$sshBackupName"

Write-Host "`n====== Renaming directory $env:USERPROFILE\Documents\.ssh to $sshBackupName"
Rename-Item -LiteralPath "$env:USERPROFILE\Documents\.ssh" -NewName "$sshBackupName"

Write-Host "`n====== Creating directory $sshFolder"
mkdir $sshFolder

Write-Host "`n====== Generating an SSH key (rsa 4096, no passphrase) to $keyFilePath"
ssh-keygen -t rsa -b 4096 -C "$keyId" -f "$keyFilePath" -N """"

Write-Host "`n====== Adding the generated SSH key to SSH agent"
ssh-add "$keyFilePath"

Write-Host "`n====== Writing the SSH config file"
Write-Output "IdentityFile $keyFilePath"                 >> "$sshFolder\config"
Write-Output "UserKnownHostsFile $sshFolder\known_hosts" >> "$sshFolder\config"
Write-Output "HashKnownHosts false"                      >> "$sshFolder\config"
Write-Output ""                                          >> "$sshFolder\config"
Write-Output "Host github.com"                           >> "$sshFolder\config"
Write-Output "    HostName github.com"                   >> "$sshFolder\config"
Write-Output "    StrictHostKeyChecking false"           >> "$sshFolder\config"
Write-Output ""                                          >> "$sshFolder\config"
Write-Output "Host gitlab.com"                           >> "$sshFolder\config"
Write-Output "    HostName gitlab.com"                   >> "$sshFolder\config"
Write-Output "    StrictHostKeyChecking false"           >> "$sshFolder\config"
Write-Output ""                                          >> "$sshFolder\config"
Write-Output "Host bitbucket.org"                        >> "$sshFolder\config"
Write-Output "    HostName bitbucket.org"                >> "$sshFolder\config"
Write-Output "    StrictHostKeyChecking false"           >> "$sshFolder\config"

(Get-Content "$sshFolder\config") | Out-FileUtf8NoBom "$sshFolder\config" # Add -UseLF for Unix newlines

Write-Host "`n====== Launching Github, Gitlab, and Bitbucket SSH settings pages"
Start-Process "https://github.com/settings/keys"
Start-Process "https://gitlab.com/-/user_settings/ssh_keys"
Start-Process "https://bitbucket.org/account/settings/ssh-keys/"

Write-Host "`n====== Opening the generated public key file"
Start-Process "$keyFilePath.pub"

Write-Host "`n`n=========================================================================================="
Write-Host "`nNow you need to copy your public key and add it to your Git remotes. Follow these steps:"
Write-Host "1. Your public key is opened for you in Notepad. Copy everything in it."
Write-Host "2. Settings pages of Github, Gitlab, and Bitbucket are opened in a Chrome window:"
Write-Host "    i. (optional) Remove the existing keys on the ones that you use."
Write-Host "   ii. Add the public key you copied to the ones that you use."
Write-Host "`nImportant paths you might want to remember for when you need this SSH key the future:"
Write-Host "* .ssh folder:  $env:USERPROFILE\.ssh"
Write-Host "* Public key:   $keyFilePath.pub"
Write-Host "* Private key:  $keyFilePath"
Write-Host "`nIMPORTANT: Do not share your PRIVATE key with anyone!"
Write-Host "The only keys you should be sharing are PUBLIC keys (those that end with .pub extension)."
Write-Host "`n=========================================================================================="
Write-Host "`n`n====== All done. You can close this window now.`n"
