<#
.SYNOPSIS
  Sauvegarde chiffrée de l'état Terraform, hors du dépôt.

.DESCRIPTION
  À lancer après chaque terraform apply. Chiffre terraform.tfstate avec GnuPG
  (AES-256, phrase de passe demandée par gpg) et écrit le résultat dans
  %USERPROFILE%\smb111-backups\tfstate. Rien n'est écrit dans le dépôt, et la
  phrase de passe n'est ni lue ni stockée par ce script.

.EXAMPLE
  .\scripts\backup-tfstate.ps1
#>
[CmdletBinding()]
param(
    [string]$StateFile = (Join-Path $PSScriptRoot '..\terraform\environments\production\terraform.tfstate'),
    [string]$BackupDir = (Join-Path $env:USERPROFILE 'smb111-backups\tfstate'),
    [int]$Keep = 20
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $StateFile)) {
    throw "État introuvable : $StateFile"
}
$StateFile = (Resolve-Path $StateFile).Path

# gpg du PATH, sinon celui livré avec Git for Windows.
$gpg = (Get-Command gpg -ErrorAction SilentlyContinue).Source
if (-not $gpg) {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\Git\usr\bin\gpg.exe'),
        (Join-Path $env:ProgramFiles 'Git\usr\bin\gpg.exe')
    )
    $gpg = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
}
if (-not $gpg) {
    throw 'gpg introuvable (installer Git for Windows ou Gpg4win).'
}

New-Item -ItemType Directory -Force $BackupDir | Out-Null

$serial = (Get-Content $StateFile -Raw | ConvertFrom-Json).serial
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$target = Join-Path $BackupDir "terraform-$stamp-serial$serial.tfstate.gpg"

& $gpg --symmetric --cipher-algo AES256 --output $target $StateFile
if ($LASTEXITCODE -ne 0) {
    throw "Échec du chiffrement (gpg, code $LASTEXITCODE)."
}

# Rotation : on garde les $Keep sauvegardes les plus récentes.
Get-ChildItem $BackupDir -Filter 'terraform-*.tfstate.gpg' |
    Sort-Object LastWriteTime -Descending |
    Select-Object -Skip $Keep |
    Remove-Item -Confirm:$false

Write-Host "Sauvegarde chiffrée : $target"
Write-Host "Restauration : gpg --decrypt --output terraform.tfstate `"$target`""
