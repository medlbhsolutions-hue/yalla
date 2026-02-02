# Script de Configuration Production - Yalla Tbib
# Ce script vous guide dans la configuration de l'application

Write-Host "========================================" -ForegroundColor Green
Write-Host "  YALLA TBIB - Configuration Production" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# Fonction pour afficher un message de succès
function Write-Success {
    param($Message)
    Write-Host "✅ $Message" -ForegroundColor Green
}

# Fonction pour afficher un message d'erreur
function Write-Error-Custom {
    param($Message)
    Write-Host "❌ $Message" -ForegroundColor Red
}

# Fonction pour afficher un message d'information
function Write-Info {
    param($Message)
    Write-Host "ℹ️  $Message" -ForegroundColor Cyan
}

# Fonction pour afficher un message d'avertissement
function Write-Warning-Custom {
    param($Message)
    Write-Host "⚠️  $Message" -ForegroundColor Yellow
}

# Étape 1 : Vérifier Flutter
Write-Host "Étape 1/6 : Vérification de Flutter" -ForegroundColor Yellow
Write-Host "-----------------------------------" -ForegroundColor Yellow

try {
    $flutterVersion = flutter --version 2>&1 | Select-String "Flutter" | Select-Object -First 1
    if ($flutterVersion) {
        Write-Success "Flutter est installé"
        Write-Host "   $flutterVersion" -ForegroundColor Gray
    }
} catch {
    Write-Error-Custom "Flutter n'est pas installé ou pas dans le PATH"
    Write-Info "Installez Flutter depuis : https://flutter.dev/docs/get-started/install"
    exit 1
}

Write-Host ""

# Étape 2 : Vérifier les dépendances
Write-Host "Étape 2/6 : Installation des dépendances" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Yellow

Write-Info "Installation des packages Flutter..."
flutter pub get

if ($LASTEXITCODE -eq 0) {
    Write-Success "Dépendances installées"
} else {
    Write-Error-Custom "Erreur lors de l'installation des dépendances"
    exit 1
}

Write-Host ""

# Étape 3 : Vérifier la configuration Supabase
Write-Host "Étape 3/6 : Configuration Supabase" -ForegroundColor Yellow
Write-Host "----------------------------------" -ForegroundColor Yellow

$databaseServicePath = "lib\src\services\database_service.dart"

if (Test-Path $databaseServicePath) {
    $content = Get-Content $databaseServicePath -Raw
    
    if ($content -match "static const String supabaseUrl = '([^']+)'") {
        $supabaseUrl = $matches[1]
        
        if ($supabaseUrl -like "*supabase.co*" -and $supabaseUrl -notlike "*votre-projet*") {
            Write-Success "URL Supabase configurée"
            Write-Host "   URL: $supabaseUrl" -ForegroundColor Gray
        } else {
            Write-Warning-Custom "URL Supabase non configurée"
            Write-Info "Modifiez lib\src\services\database_service.dart avec votre URL Supabase"
        }
    }
    
    if ($content -match "static const String supabaseAnonKey = '([^']+)'") {
        $supabaseKey = $matches[1]
        
        if ($supabaseKey.Length -gt 100) {
            Write-Success "Clé Supabase configurée"
            Write-Host "   Clé: $($supabaseKey.Substring(0, 20))..." -ForegroundColor Gray
        } else {
            Write-Warning-Custom "Clé Supabase non configurée"
            Write-Info "Modifiez lib\src\services\database_service.dart avec votre clé anon"
        }
    }
} else {
    Write-Error-Custom "Fichier database_service.dart non trouvé"
    exit 1
}

Write-Host ""

# Étape 4 : Vérifier le schéma SQL
Write-Host "Étape 4/6 : Vérification du schéma SQL" -ForegroundColor Yellow
Write-Host "--------------------------------------" -ForegroundColor Yellow

$sqlPath = "supabase\migrations\20241001000000_complete_database_schema.sql"

if (Test-Path $sqlPath) {
    Write-Success "Fichier SQL trouvé"
    Write-Info "Exécutez ce fichier dans Supabase SQL Editor"
    Write-Host "   Chemin: $sqlPath" -ForegroundColor Gray
} else {
    Write-Error-Custom "Fichier SQL non trouvé"
}

Write-Host ""

# Étape 5 : Proposer de lancer le test
Write-Host "Étape 5/6 : Test de connexion" -ForegroundColor Yellow
Write-Host "-----------------------------" -ForegroundColor Yellow

$response = Read-Host "Voulez-vous lancer le test de connexion Supabase ? (o/n)"

if ($response -eq "o" -or $response -eq "O") {
    Write-Info "Lancement du test..."
    flutter run -t test_production.dart
} else {
    Write-Info "Test ignoré. Vous pouvez le lancer manuellement avec :"
    Write-Host "   flutter run -t test_production.dart" -ForegroundColor Gray
}

Write-Host ""

# Étape 6 : Proposer de lancer l'application
Write-Host "Étape 6/6 : Lancement de l'application" -ForegroundColor Yellow
Write-Host "--------------------------------------" -ForegroundColor Yellow

Write-Host ""
Write-Host "Quelle version voulez-vous lancer ?" -ForegroundColor Cyan
Write-Host "1. Version Production (main_production_ready.dart)" -ForegroundColor White
Write-Host "2. Version Standard (main.dart)" -ForegroundColor White
Write-Host "3. Ne rien lancer" -ForegroundColor White
Write-Host ""

$choice = Read-Host "Votre choix (1/2/3)"

switch ($choice) {
    "1" {
        Write-Info "Lancement de la version production..."
        flutter run -t lib\main_production_ready.dart
    }
    "2" {
        Write-Info "Lancement de la version standard..."
        flutter run
    }
    "3" {
        Write-Info "Aucune application lancée"
    }
    default {
        Write-Warning-Custom "Choix invalide"
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Configuration terminée !" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

Write-Host "📚 Ressources utiles :" -ForegroundColor Cyan
Write-Host "   - Guide complet : DEMARRAGE_RAPIDE_PRODUCTION.md" -ForegroundColor Gray
Write-Host "   - Guide Supabase : GUIDE_PRODUCTION_SUPABASE.md" -ForegroundColor Gray
Write-Host "   - Service DB : lib\src\services\database_service.dart" -ForegroundColor Gray
Write-Host ""

Write-Host "🚀 Commandes utiles :" -ForegroundColor Cyan
Write-Host "   flutter run                                    # Version standard" -ForegroundColor Gray
Write-Host "   flutter run -t lib\main_production_ready.dart  # Version production" -ForegroundColor Gray
Write-Host "   flutter run -t test_production.dart            # Test connexion" -ForegroundColor Gray
Write-Host ""

Write-Success "Bonne chance avec Yalla Tbib ! 🚑"
