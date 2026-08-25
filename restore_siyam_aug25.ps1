$ErrorActionPreference = 'Stop'

$Root = (Get-Location).Path
$Pubspec = Join-Path $Root 'pubspec.yaml'
$LibRoot = Join-Path $Root 'lib'
$BackupRoot = Join-Path $Root '.siyam_revision_backup_aug25'
$BackupLib = Join-Path $BackupRoot 'lib'
$PatchFolder = Join-Path $Root 'SIYAM_revision_batch_aug25'

Write-Host "SIYAM Aug 25 recovery" -ForegroundColor Cyan
Write-Host "Project: $Root"
Write-Host ""

if (-not (Test-Path $Pubspec)) {
    throw "pubspec.yaml was not found. Run this from the siyam_flutter project root."
}

if (-not (Test-Path $LibRoot)) {
    throw "lib folder was not found. Run this from the siyam_flutter project root."
}

if (-not (Test-Path $BackupLib)) {
    throw "Backup folder not found: $BackupLib"
}

$BackupBase = (Resolve-Path $BackupLib).Path
$ProjectLibBase = (Resolve-Path $LibRoot).Path

$Files = Get-ChildItem -Path $BackupBase -Recurse -File

if ($Files.Count -eq 0) {
    throw "The backup folder exists but contains no files."
}

Write-Host "Restoring $($Files.Count) pre-patch files..." -ForegroundColor Yellow

foreach ($File in $Files) {
    $Relative = $File.FullName.Substring($BackupBase.Length).TrimStart('\', '/')
    $Destination = Join-Path $ProjectLibBase $Relative
    $DestinationDir = Split-Path $Destination -Parent

    if (-not (Test-Path $DestinationDir)) {
        New-Item -ItemType Directory -Force -Path $DestinationDir | Out-Null
    }

    Copy-Item -Path $File.FullName -Destination $Destination -Force
    Write-Host "RESTORE $Relative" -ForegroundColor Green
}

# These two files were introduced by the failed revision batch.
$NewFiles = @(
    (Join-Path $Root 'lib\widgets\pending_donation_badge.dart'),
    (Join-Path $Root 'lib\state\donor_notification_seen_state.dart')
)

foreach ($File in $NewFiles) {
    if (Test-Path $File) {
        Remove-Item -Path $File -Force
        Write-Host "REMOVE  $($File.Substring($Root.Length + 1))" -ForegroundColor Green
    }
}

# The extracted patch folder contains standalone Dart helper files. Keeping it
# inside the Flutter project makes `flutter analyze` analyze those helpers too.
if (Test-Path $PatchFolder) {
    Remove-Item -Path $PatchFolder -Recurse -Force
    Write-Host "REMOVE  SIYAM_revision_batch_aug25" -ForegroundColor Green
}

Write-Host ""
Write-Host "RECOVERY COMPLETE" -ForegroundColor Cyan
Write-Host "The .siyam_revision_backup_aug25 folder was intentionally kept." -ForegroundColor DarkGray
Write-Host ""
Write-Host "Next run:" -ForegroundColor Yellow
Write-Host "  flutter analyze"