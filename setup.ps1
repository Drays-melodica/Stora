# Script d'installation STORA pour Windows
# Exécuter dans PowerShell : .\setup.ps1

$ErrorActionPreference = "Stop"

Write-Host "=== STORA Setup ===" -ForegroundColor Cyan

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    $flutterBat = "D:\flutter\bin\flutter.bat"
    if (Test-Path $flutterBat) {
        $env:Path = "D:\flutter\bin;" + $env:Path
    } else {
        Write-Host "ERREUR: Flutter introuvable." -ForegroundColor Red
        exit 1
    }
}

Write-Host "Flutter détecté." -ForegroundColor Green
flutter doctor

Write-Host "`nGénération des fichiers Windows..." -ForegroundColor Yellow
flutter create . --project-name stora --platforms windows

Write-Host "`nInstallation des dépendances..." -ForegroundColor Yellow
flutter pub get

Write-Host "`nLancement de STORA..." -ForegroundColor Green
flutter run -d windows
