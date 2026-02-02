# 🚀 GUIDE DE DÉPLOIEMENT - YALLA L'TBIB
Ce guide détaille les étapes pour publier l'application sur Google Play Store (Android) et Apple App Store (iOS).

---

## 🤖 1. GOOGLE PLAY STORE (ANDROID)

### **Étape 1 : Compte Développeur**
*   Créez un compte [Google Play Console](https://play.google.com/console).
*   Coût : **25 $ (paiement unique)**.

### **Étape 2 : Signature de l'application (Keystore)**
⚠️ **IMPORTANT : Ne perdez JAMAIS ce fichier, sinon vous ne pourrez plus mettre à jour l'app.**

1.  Ouvrez un terminal dans le dossier racine du projet.
2.  Générez la clé (sur Windows) :
    ```powershell
    keytool -genkey -v -keystore android/app/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
    ```
3.  Répondez aux questions (Mot de passe, Nom, Organisation...). **Notez bien le mot de passe.**

### **Étape 3 : Configuration Flutter**
1.  Créez le fichier `android/key.properties` :
    ```properties
    storePassword=VOTRE_MOT_DE_PASSE
    keyPassword=VOTRE_MOT_DE_PASSE
    keyAlias=upload
    storeFile=upload-keystore.jks
    ```
2.  Le fichier `android/app/build.gradle` est déjà configuré pour lire ce fichier (vérifiez la section `signingConfigs`).

### **Étape 4 : Génération du Bundle (.aab)**
Google exige désormais le format `.aab` (Android App Bundle) plutôt que `.apk`.
```bash
flutter build appbundle --release
```
Le fichier sera généré dans : `build/app/outputs/bundle/release/app-release.aab`

### **Étape 5 : Publication**
1.  Sur la [Google Play Console](https://play.google.com/console), créez une nouvelle application.
2.  Remplissez la **Fiche du magasin** (Titre, Description courte/longue).
3.  Importez les **Visuels** :
    *   Icône (512x512 px, PNG).
    *   Bannière (1024x500 px, PNG).
    *   Screenshots (Téléphone, Tablette 7", Tablette 10").
4.  Allez dans **Production** -> **Créer une nouvelle version**.
5.  Importez votre fichier `.aab`.
6.  Envoyez pour examen (Délai : 2 à 7 jours).

---

## 🍎 2. APPLE APP STORE (iOS)
⚠️ **Nécessite obligatoirement un Mac avec Xcode**.

### **Étape 1 : Compte Développeur**
*   Inscrivez-vous au [Apple Developer Program](https://developer.apple.com/).
*   Coût : **99 $ / an**.

### **Étape 2 : Configuration Xcode**
1.  Ouvrez `ios/Runner.xcworkspace` avec Xcode.
2.  Dans l'onglet **Signing & Capabilities** :
    *   Cochez "Automatically manage signing".
    *   Sélectionnez votre **Team** (votre compte Apple Dev).
    *   Vérifiez que le **Bundle Identifier** est unique (ex: `com.medlbh.yallatbib`).

### **Étape 3 : App Store Connect**
1.  Connectez-vous à [App Store Connect](https://appstoreconnect.apple.com/).
2.  Créez une nouvelle App ("My Apps" -> "+").
3.  Remplissez les métadonnées (Nom, description, mots-clés, support URL).

### **Étape 4 : Build et Upload**
1.  Dans Xcode, sélectionnez "Any iOS Device (arm64)" comme cible.
2.  Menu **Product** -> **Archive**.
3.  Une fois l'archivage terminé, la fenêtre "Organizer" s'ouvre.
4.  Cliquez sur **Distribute App** -> **App Store Connect** -> **Upload**.

### **Étape 5 : Soumission**
1.  Retournez sur App Store Connect.
2.  Dans la section "Build", sélectionnez la version que vous venez d'uploader.
3.  Ajoutez les **Screenshots** (Requis pour iPhone 6.5" et 5.5").
4.  Cliquez sur **Submit for Review**.
5.  Délai de validation : 24h à 48h (très strict).

---

## 📝 checklist AVANT Publication

- [ ] **Nom de l'app** : Vérifier `android:label` dans Manifest et `CFBundleDisplayName` dans Info.plist.
- [ ] **Icône** : Avez-vous généré les icônes finales avec `flutter_launcher_icons` ?
- [ ] **Permissions** : Vérifiez que vous n'en demandez pas trop (Google/Apple peuvent refuser).
- [ ] **Version** : Mettez à jour `version: 1.0.0+1` dans `pubspec.yaml` à chaque mise à jour (+2, +3...).
- [ ] **Environnement** : Assurez-vous que l'app pointe vers la base de données de PROD (Supabase/Firebase).

---

## 🛠️ Commandes Utiles

**Générer les icônes (si config changée) :**
```bash
flutter pub run flutter_launcher_icons
```

**Voir la clé SHA-1 (Pour configuration Firebase/Google Maps) :**
```bash
keytool -list -v -keystore android/app/upload-keystore.jks -alias upload
```
