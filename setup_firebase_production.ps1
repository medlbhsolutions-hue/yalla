# =======================================================
# 🔥 Script: Configuration Firebase SMS Production
# Projet: Yalla Tbib Medical Transport
# =======================================================

Write-Host "===============================================" -ForegroundColor Green
Write-Host "  🔥 Firebase SMS Production Setup" -ForegroundColor Green
Write-Host "  📱 Yalla Tbib Medical Transport" -ForegroundColor Green
Write-Host "===============================================`n" -ForegroundColor Green

# =======================================================
# Étape 1 : Vérifier environnement
# =======================================================

Write-Host "📋 Vérification de l'environnement...`n" -ForegroundColor Cyan

# Vérifier Flutter
$flutterVersion = flutter --version 2>&1 | Select-Object -First 1
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Flutter trouvé: $flutterVersion" -ForegroundColor Green
} else {
    Write-Host "❌ Flutter non trouvé. Installez Flutter d'abord." -ForegroundColor Red
    exit 1
}

# Vérifier Android SDK
$androidSdk = $env:LOCALAPPDATA + "\Android\Sdk"
if (Test-Path $androidSdk) {
    Write-Host "✅ Android SDK trouvé: $androidSdk" -ForegroundColor Green
} else {
    Write-Host "⚠️  Android SDK non trouvé au chemin standard" -ForegroundColor Yellow
}

# Vérifier device connecté
Write-Host "`n📱 Recherche de devices connectés..." -ForegroundColor Cyan
$devices = flutter devices 2>&1
if ($devices -match "No devices detected") {
    Write-Host "⚠️  Aucun device Android connecté" -ForegroundColor Yellow
    Write-Host "   Connectez un téléphone Android ou lancez un émulateur`n" -ForegroundColor Yellow
} else {
    Write-Host "✅ Devices détectés:`n$devices`n" -ForegroundColor Green
}

# =======================================================
# Étape 2 : Obtenir SHA Fingerprints
# =======================================================

Write-Host "`n🔑 Obtention des SHA Fingerprints...`n" -ForegroundColor Cyan

$keystorePath = "$env:USERPROFILE\.android\debug.keystore"

if (Test-Path $keystorePath) {
    Write-Host "✅ Debug keystore trouvé: $keystorePath" -ForegroundColor Green
    
    # Chercher keytool
    $keytoolPaths = @(
        "$env:JAVA_HOME\bin\keytool.exe",
        "$androidSdk\jre\bin\keytool.exe",
        "C:\Program Files\Android\Android Studio\jre\bin\keytool.exe",
        "C:\Program Files\Java\jdk*\bin\keytool.exe"
    )
    
    $keytoolFound = $false
    foreach ($path in $keytoolPaths) {
        if (Test-Path $path) {
            Write-Host "`n📋 Extraction des fingerprints avec keytool...`n" -ForegroundColor Cyan
            
            & $path -list -v -keystore $keystorePath `
                -alias androiddebugkey `
                -storepass android `
                -keypass android 2>$null | Select-String "SHA1|SHA256"
            
            $keytoolFound = $true
            break
        }
    }
    
    if (-not $keytoolFound) {
        Write-Host "⚠️  keytool non trouvé. Utilisez gradlew signingReport à la place:`n" -ForegroundColor Yellow
        Write-Host "   cd android" -ForegroundColor Gray
        Write-Host "   .\gradlew signingReport`n" -ForegroundColor Gray
    }
} else {
    Write-Host "❌ Debug keystore non trouvé à: $keystorePath" -ForegroundColor Red
}

Write-Host "`n📝 ACTIONS REQUISES:" -ForegroundColor Yellow
Write-Host "   1. Copiez les valeurs SHA1 et SHA256 ci-dessus" -ForegroundColor Gray
Write-Host "   2. Ouvrez Firebase Console: https://console.firebase.google.com" -ForegroundColor Gray
Write-Host "   3. Project Settings → Your apps → Android app" -ForegroundColor Gray
Write-Host "   4. Ajoutez les fingerprints SHA" -ForegroundColor Gray
Write-Host "   5. Téléchargez le nouveau google-services.json`n" -ForegroundColor Gray

# =======================================================
# Étape 3 : Vérifier google-services.json
# =======================================================

Write-Host "`n📄 Vérification de google-services.json...`n" -ForegroundColor Cyan

$googleServicesPath = "android\app\google-services.json"

if (Test-Path $googleServicesPath) {
    $googleServices = Get-Content $googleServicesPath | ConvertFrom-Json
    $projectId = $googleServices.project_info.project_id
    $packageName = $googleServices.client[0].client_info.android_client_info.package_name
    
    Write-Host "✅ google-services.json trouvé" -ForegroundColor Green
    Write-Host "   Project ID: $projectId" -ForegroundColor Gray
    Write-Host "   Package: $packageName`n" -ForegroundColor Gray
} else {
    Write-Host "❌ google-services.json non trouvé!" -ForegroundColor Red
    Write-Host "   Téléchargez-le depuis Firebase Console`n" -ForegroundColor Red
}

# =======================================================
# Étape 4 : Désactiver le mode debug SMS
# =======================================================

Write-Host "`n🔧 Configuration du mode authentification...`n" -ForegroundColor Cyan

$phoneAuthServicePath = "lib\src\services\phone_auth_service.dart"

if (Test-Path $phoneAuthServicePath) {
    $content = Get-Content $phoneAuthServicePath -Raw
    
    if ($content -match "static const bool _useDebugMode = true") {
        Write-Host "⚠️  Mode debug SMS ACTIVÉ" -ForegroundColor Yellow
        Write-Host "   Pour tester avec de vrais SMS, modifiez:" -ForegroundColor Gray
        Write-Host "   $phoneAuthServicePath" -ForegroundColor Gray
        Write-Host "   Ligne: static const bool _useDebugMode = false;`n" -ForegroundColor Gray
        
        # Demander si on doit modifier
        $response = Read-Host "Voulez-vous désactiver le mode debug maintenant? (O/N)"
        if ($response -eq "O" -or $response -eq "o") {
            $content = $content -replace "static const bool _useDebugMode = true", "static const bool _useDebugMode = false"
            Set-Content $phoneAuthServicePath -Value $content
            Write-Host "✅ Mode debug SMS désactivé`n" -ForegroundColor Green
        }
    } else {
        Write-Host "✅ Mode production SMS activé`n" -ForegroundColor Green
    }
} else {
    Write-Host "⚠️  Fichier phone_auth_service.dart non trouvé`n" -ForegroundColor Yellow
}

# =======================================================
# Étape 5 : Build APK
# =======================================================

Write-Host "`n🔨 Build APK Debug...`n" -ForegroundColor Cyan

$response = Read-Host "Voulez-vous build l'APK debug maintenant? (O/N)"
if ($response -eq "O" -or $response -eq "o") {
    Write-Host "`n🧹 Nettoyage du projet..." -ForegroundColor Cyan
    flutter clean
    
    Write-Host "`n📦 Téléchargement des dépendances..." -ForegroundColor Cyan
    flutter pub get
    
    Write-Host "`n🔨 Build APK debug (peut prendre 5-10 minutes)...`n" -ForegroundColor Cyan
    flutter build apk --debug
    
    if ($LASTEXITCODE -eq 0) {
        $apkPath = "build\app\outputs\flutter-apk\app-debug.apk"
        $apkSize = (Get-Item $apkPath).Length / 1MB
        
        Write-Host "`n✅ APK créé avec succès!" -ForegroundColor Green
        Write-Host "   Chemin: $apkPath" -ForegroundColor Gray
        Write-Host "   Taille: $([math]::Round($apkSize, 2)) MB`n" -ForegroundColor Gray
        
        # Proposer installation
        $devices = flutter devices 2>&1
        if ($devices -match "android") {
            $response = Read-Host "Voulez-vous installer l'APK sur le device connecté? (O/N)"
            if ($response -eq "O" -or $response -eq "o") {
                Write-Host "`n📱 Installation de l'APK...`n" -ForegroundColor Cyan
                flutter install
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "✅ APK installé avec succès!`n" -ForegroundColor Green
                }
            }
        }
    } else {
        Write-Host "`n❌ Erreur lors du build APK`n" -ForegroundColor Red
    }
}

# =======================================================
# Étape 6 : Instructions finales
# =======================================================

Write-Host "`n===============================================" -ForegroundColor Green
Write-Host "  ✅ Configuration terminée!" -ForegroundColor Green
Write-Host "===============================================`n" -ForegroundColor Green

Write-Host "📝 PROCHAINES ÉTAPES:" -ForegroundColor Yellow
Write-Host "   1. ✅ SHA fingerprints extraits" -ForegroundColor Gray
Write-Host "   2. 🌐 Ajouter les SHA dans Firebase Console" -ForegroundColor Gray
Write-Host "   3. 📄 Télécharger google-services.json mis à jour" -ForegroundColor Gray
Write-Host "   4. 🔥 Activer Phone Authentication dans Firebase" -ForegroundColor Gray
Write-Host "   5. 📱 Installer l'APK sur un téléphone physique" -ForegroundColor Gray
Write-Host "   6. 📞 Tester avec un VRAI numéro de téléphone`n" -ForegroundColor Gray

Write-Host "📚 Documentation complète:" -ForegroundColor Cyan
Write-Host "   Voir: GUIDE_FIREBASE_SMS_PRODUCTION.md`n" -ForegroundColor Gray

Write-Host "🔗 Liens utiles:" -ForegroundColor Cyan
Write-Host "   Firebase Console: https://console.firebase.google.com" -ForegroundColor Gray
Write-Host "   Flutter Devices: flutter devices" -ForegroundColor Gray
Write-Host "   Rebuild APK: flutter build apk --debug`n" -ForegroundColor Gray

Write-Host "===============================================`n" -ForegroundColor Green
