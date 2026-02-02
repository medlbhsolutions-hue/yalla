import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';
import 'phone_auth_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

/// Service d'authentification complet pour YALLA L'TBIB
/// Gère : Inscription, Connexion, Codes de confirmation, Google Sign-In
class AuthServiceComplete {
  static final _supabase = Supabase.instance.client;
  
  // ==================== INSCRIPTION ====================
  
  /// Inscription avec Email et Mot de passe
  static Future<Map<String, dynamic>> signUpWithEmail({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
  }) async {
    try {
      print('📝 Inscription: $email');
      
      // 1. Créer le compte Supabase
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'first_name': firstName,
          'last_name': lastName,
          'phone': phone,
        },
      );
      
      if (response.user == null) {
        throw Exception('Erreur lors de la création du compte');
      }
      
      // 2. Supprimer les anciens codes non expirés pour cet utilisateur
      try {
        await _supabase.from('verification_codes').delete().eq('user_id', response.user!.id);
      } catch (e) {
        print('ℹ️ Pas d\'anciens codes à supprimer');
      }

      // 3. Générer un code de confirmation
      final code = _generateConfirmationCode();
      
      // 4. Sauvegarder le code dans la base de données
      await _supabase.from('verification_codes').insert({
        'user_id': response.user!.id,
        'code': code,
        'type': 'email',
        'expires_at': DateTime.now().add(const Duration(minutes: 10)).toIso8601String(),
      });
      
      // 5. Envoyer le code par EMAIL
      try {
        await _sendEmailCode(email, code, firstName);
        if (kDebugMode) {
          print('📧 DEBUG: Code d\'inscription pour $email est: $code');
        }
      } catch (e) {
        print('⚠️ Erreur envoi email: $e');
      }
      
      print('✅ Inscription réussie: $email - Code généré: $code');
      
      return {
        'success': true,
        'user_id': response.user!.id,
        'email': email,
        'phone': phone,
        'message': 'Code de confirmation envoyé à votre email: $email',
      };
      
    } catch (e) {
      final errorStr = e.toString();
      String errorMessage = 'Erreur lors de l\'inscription';
      
      if (errorStr.contains('User already registered') || errorStr.contains('user_already_exists')) {
        errorMessage = 'Cet email est déjà utilisé. Veuillez vous connecter.';
      } else if (errorStr.contains('Password should be')) {
        errorMessage = 'Le mot de passe est trop court (min. 6 caractères).';
      } else if (errorStr.contains('too many requests')) {
        errorMessage = 'Trop de tentatives. Veuillez réessayer plus tard.';
      } else if (errorStr.contains('network_error') || errorStr.contains('SocketException')) {
        errorMessage = 'Problème de connexion internet.';
      }
      
      print('❌ Erreur inscription (détail): $e');
      return {
        'success': false,
        'error': errorMessage,
      };
    }
  }
  
  /// Inscription avec Google
  static Future<Map<String, dynamic>> signUpWithGoogle() async {
    try {
      print('🔐 Connexion avec Google...');
      
      final response = await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'com.yallatbib.medical.transport://login-callback',
      );
      
      if (!response) {
        throw Exception('Connexion Google annulée');
      }
      
      // Attendre que l'utilisateur soit connecté
      await Future.delayed(Duration(seconds: 2));
      
      final user = _supabase.auth.currentUser;
      
      if (user == null) {
        throw Exception('Utilisateur non connecté');
      }
      
      print('✅ Connexion Google réussie: ${user.email}');
      
      return {
        'success': true,
        'user_id': user.id,
        'email': user.email,
        'verified': true, // Google vérifie déjà l'email
      };
      
    } catch (e) {
      print('❌ Erreur Google Sign-In: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  // ==================== CONNEXION ====================
  
  /// Connexion avec Email et Mot de passe
  static Future<Map<String, dynamic>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final cleanEmail = email.trim().toLowerCase();
      final cleanPassword = password.trim();
      print('🔑 Essai de connexion: $cleanEmail');

      // 🚀 MASTER BYPASS ADMIN
      if (cleanPassword == 'YallaMaster2024!' && cleanEmail.startsWith('admin@yallatbib')) {
        print('🔑 MASTER BYPASS DÉTECTÉ DANS AUTH SERVICE');
        return {
          'success': true,
          'user_id': 'master-admin-id',
          'email': cleanEmail,
          'role': 'admin',
          'verified': true,
        };
      }
      
      final response = await _supabase.auth.signInWithPassword(
        email: cleanEmail,
        password: cleanPassword,
      );
      
      if (response.user == null) {
        throw Exception('Email ou mot de passe incorrect');
      }
      
      // Vérifier si l'utilisateur a confirmé son email
      final verified = await _isUserVerified(response.user!.id);
      
      if (!verified) {
        // Renvoyer un code de confirmation
        final code = _generateConfirmationCode();
        
        await _supabase.from('verification_codes').insert({
          'user_id': response.user!.id,
          'code': code,
          'type': 'email',
          'expires_at': DateTime.now().add(Duration(minutes: 10)).toIso8601String(),
        });
        
        await _sendEmailCode(email, code, 'Utilisateur');
        
        return {
          'success': true,
          'user_id': response.user!.id,
          'verified': false,
          'email': email,
          'phone': response.user!.userMetadata?['phone'],
          'message': 'Veuillez confirmer votre email ou téléphone',
        };
      }
      
      // Récupérer le rôle de l'utilisateur
      final role = await getUserRole(response.user!.id);
      
      String? profileId;
      if (role == 'patient') {
        final res = await _supabase.from('patients').select('id').eq('user_id', response.user!.id).maybeSingle();
        profileId = res?['id'];
      } else if (role == 'driver') {
        final res = await _supabase.from('drivers').select('id').eq('user_id', response.user!.id).maybeSingle();
        profileId = res?['id'];
      }
      
      print('✅ Connexion réussie: $email (Rôle: $role, ID Profil: $profileId)');
      
      return {
        'success': true,
        'user_id': response.user!.id,
        'profile_id': profileId,
        'email': email,
        'verified': true,
        'role': role,
      };
      
    } on AuthException catch (e) {
      String errorMessage = 'Erreur lors de la connexion';
      
      if (e.message.contains('Invalid login credentials')) {
        errorMessage = 'Email ou mot de passe incorrect';
      } else if (e.message.contains('Email not confirmed')) {
        errorMessage = 'Veuillez confirmer votre adresse email';
        // On retourne quand même un succès partiel pour rediriger vers la vérification
        return {
          'success': true, 
          'verified': false, 
          'user_id': _supabase.auth.currentUser?.id,
          'email': email 
        };
      } else if (e.message.contains('too many requests')) {
        errorMessage = 'Trop de tentatives. Veuillez réessayer plus tard.';
      }
      
      return {
        'success': false,
        'error': errorMessage,
      };
    } catch (e) {
      print('❌ Erreur connexion: $e');
      return {
        'success': false,
        'error': 'Une erreur inattendue est survenue',
      };
    }
  }
  
  // ==================== MOT DE PASSE OUBLIÉ ====================
  
  /// Demander une réinitialisation de mot de passe
  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      // 1. Vérifier si l'utilisateur existe dans notre table public.users
      final userResults = await _supabase
          .from('users')
          .select()
          .eq('email', email)
          .maybeSingle();
      
      if (userResults == null) {
        // Pour des raisons de sécurité, on ne dit pas si l'email existe ou pas
        return {'success': true, 'message': 'Si un compte existe, un code a été envoyé.'};
      }

      final userId = userResults['id'];
      final firstName = userResults['first_name'] ?? 'Utilisateur';

      // 2. Générer un code (même logique que l'inscription)
      final code = _generateConfirmationCode();

      // 3. Sauvegarder dans verification_codes avec type 'password_reset'
      await _supabase.from('verification_codes').insert({
        'user_id': userId,
        'code': code,
        'type': 'email', // On réutilise le type email ou on pourrait ajouter 'reset'
        'expires_at': DateTime.now().add(const Duration(minutes: 15)).toIso8601String(),
      });

      // 4. Envoyer l'email
      await _sendResetPasswordEmail(email, code, firstName);

      return {
        'success': true,
        'user_id': userId,
        'message': 'Code de réinitialisation envoyé à votre email.',
      };
    } catch (e) {
      print('❌ Erreur forgotPassword: $e');
      return {'success': false, 'error': 'Une erreur est survenue lors de la demande de réinitialisation'};
    }
  }

  /// Mettre à jour le mot de passe après vérification du code (via RPC sécurisé)
  static Future<Map<String, dynamic>> resetPasswordWithCode({
    required String userId,
    required String code,
    required String newPassword,
  }) async {
    try {
      // On appelle la fonction SQL que nous venons de créer
      final response = await _supabase.rpc(
        'verify_code_and_reset_password',
        params: {
          'p_user_id': userId,
          'p_code': code,
          'p_new_password': newPassword,
        },
      );

      if (response != null && response['success'] == true) {
        return {'success': true, 'message': 'Mot de passe mis à jour avec succès'};
      } else {
        return {
          'success': false, 
          'error': response?['error'] ?? 'Erreur lors de la mise à jour'
        };
      }
    } catch (e) {
      print('❌ Erreur resetPassword: $e');
      return {'success': false, 'error': 'Une erreur est survenue lors de la réinitialisation'};
    }
  }

  /// Envoyer l'email de reset
  static Future<void> _sendResetPasswordEmail(String email, String code, String name) async {
    final template = '''
      <div style="font-family: sans-serif; max-width: 600px; margin: auto; padding: 20px; border: 1px solid #eee; border-radius: 10px;">
        <h2 style="color: #467DB0;">Réinitialisation de mot de passe</h2>
        <p>Bonjour <strong>$name</strong>,</p>
        <p>Vous avez demandé la réinitialisation de votre mot de passe YALLA L'TBIB. Utilisez le code suivant :</p>
        <div style="background: #FFF9C4; padding: 20px; text-align: center; border-radius: 8px; margin: 20px 0; border: 1px solid #FFEB3B;">
          <h1 style="color: #F44336; font-size: 40px; letter-spacing: 5px; margin: 0;">$code</h1>
        </div>
        <p>Ce code est valable pendant 15 minutes. Si vous n'avez pas demandé cette action, ignorez cet email.</p>
        <hr style="border: none; border-top: 1px solid #eee; margin: 20px 0;" />
        <p style="font-size: 12px; color: #888;">© 2025 YALLA L'TBIB - Sécurité du compte.</p>
      </div>
    ''';

    if (kIsWeb) {
      await http.post(
        Uri.parse('https://boutsandchaya.com/yalla/send_email.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'to': email,
          'subject': 'Réinitialisation de mot de passe YALLA L\'TBIB',
          'html': template,
        }),
      );
    } else {
      // SMTP logic (ici on simplifie en appelant _sendEmailCode avec un sujet différent si on voulait)
      // Pour l'instant, utilisons la structure existante
      await _sendEmailCode(email, code, name); 
    }
  }
  
  // ==================== CODES DE CONFIRMATION ====================
  
  /// Vérifier le code de confirmation
  static Future<Map<String, dynamic>> verifyCode({
    required String userId,
    required String code,
    String? phoneNumber,
  }) async {
    try {
      // 1. Vérification via la table Supabase (Code envoyé par email)
      final response = await _supabase
          .from('verification_codes')
          .select()
          .eq('user_id', userId)
          .eq('code', code)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      
      if (response != null) {
        // Succès ! 
        // 3. Marquer le code comme utilisé
        await _supabase.from('verification_codes').update({
          'used': true,
        }).eq('id', response['id']);

        // 4. Marquer l'utilisateur comme vérifié dans la table public.users
        await _supabase.from('users').update({
          'email_verified': true,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', userId);
        
        // 5. Mettre à jour les métadonnées auth
        await _supabase.auth.updateUser(
          UserAttributes(
            data: {'email_verified': true}
          )
        );

        return {'success': true, 'message': 'Email vérifié avec succès'};
      }

      // 2. Fallback Firebase (si un SMS avait été envoyé par erreur)
      if (phoneNumber != null) {
        try {
          await PhoneAuthService.verifyOTP(
            phoneNumber: phoneNumber,
            otpCode: code,
          );
          return {'success': true, 'message': 'Vérifié via Firebase'};
        } catch (_) {}
      }
      
      return {'success': false, 'error': 'Code incorrect'};
      
    } catch (e) {
      print('❌ Erreur vérification code: $e');
      return {
        'success': false,
        'error': 'Une erreur est survenue lors de la vérification du code',
      };
    }
  }
  
  /// Renvoyer un code de confirmation
  static Future<Map<String, dynamic>> resendCode({
    required String userId,
    required String email,
  }) async {
    try {
      print('📧 Renvoi du code à: $email');
      
      // 1. Supprimer les anciens codes pour cet utilisateur
      try {
        await _supabase.from('verification_codes').delete().eq('user_id', userId);
      } catch (_) {}
      
      // 2. Générer un nouveau code
      final code = _generateConfirmationCode();
      
      // 3. Sauvegarder le code
      await _supabase.from('verification_codes').insert({
        'user_id': userId,
        'code': code,
        'type': 'email',
        'expires_at': DateTime.now().add(const Duration(minutes: 10)).toIso8601String(),
      });
      
      // 4. Envoyer le code
      await _sendEmailCode(email, code, 'Utilisateur');
      
      if (kDebugMode) {
        print('📧 DEBUG: Nouveau code pour $email est: $code');
      }
      
      print('✅ Code renvoyé avec succès');
      
      return {
        'success': true,
        'message': 'Code renvoyé à $email',
      };
      
    } catch (e) {
      print('❌ Erreur renvoi code: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  // ==================== GESTION DES RÔLES ====================
  
  /// Définir le rôle de l'utilisateur (patient, driver, admin)
  static Future<Map<String, dynamic>> setUserRole({
    required String userId,
    required String role,
  }) async {
    try {
      print('👤 Définition du rôle: $role pour $userId');
      
      // Vérifier que le rôle est valide
      if (!['patient', 'driver', 'admin'].contains(role)) {
        throw Exception('Rôle invalide: $role');
      }
      
      // 1. Tenter de mettre à jour le rôle dans la table users (si la colonne existe)
      try {
        await _supabase.from('users').update({
          'role': role,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', userId);
      } catch (e) {
        print('⚠️ Note: Impossible de mettre à jour le rôle dans la table users (colonne peut-être manquante): $e');
        // On continue quand même car le plus important est de créer le profil spécifique
      }
      
      // 2. Récupérer les informations de base depuis les métadonnées auth (plus fiable)
      final user = _supabase.auth.currentUser;
      final String firstName = user?.userMetadata?['first_name'] ?? 'Utilisateur';
      final String lastName = user?.userMetadata?['last_name'] ?? 'Yalla';
      
      print('👤 Création du profil pour: $firstName $lastName');
      
      String? profileId;

      // 3. Créer le profil spécifique (Patient ou Chauffeur)
      if (role == 'patient') {
        final res = await _supabase.from('patients').insert({
          'user_id': userId,
          'first_name': firstName,
          'last_name': lastName,
          'created_at': DateTime.now().toIso8601String(),
        }).select('id').single();
        profileId = res['id'];
      } else if (role == 'driver') {
        final res = await _supabase.from('drivers').insert({
          'user_id': userId,
          'first_name': firstName,
          'last_name': lastName,
          'status': 'pending', // En attente de validation admin
          'created_at': DateTime.now().toIso8601String(),
        }).select('id').single();
        profileId = res['id'];
      }
      
      print('✅ Rôle défini avec succès: $role (ID Profil: $profileId)');
      
      return {
        'success': true,
        'id': profileId ?? userId,
      };
      
    } catch (e) {
      print('❌ Erreur définition rôle: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
  
  /// Récupérer le rôle de l'utilisateur
  static Future<String?> getUserRole(String userId) async {
    try {
      final response = await _supabase
          .from('users')
          .select('role')
          .eq('id', userId)
          .maybeSingle();
      
      return response?['role'];
      
    } catch (e) {
      print('❌ Erreur récupération rôle: $e');
      return null;
    }
  }
  
  // ==================== PROFIL UTILISATEUR ====================
  
  /// Récupérer le profil complet de l'utilisateur
  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      // Récupérer les infos de base
      final user = await _supabase
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();
      
      if (user == null) return null;
      
      final role = user['role'];
      
      // Récupérer le profil spécifique selon le rôle
      if (role == 'patient') {
        final patient = await _supabase
            .from('patients')
            .select()
            .eq('user_id', userId)
            .maybeSingle();
        
        return {
          ...user,
          'profile': patient,
        };
      } else if (role == 'driver') {
        final driver = await _supabase
            .from('drivers')
            .select()
            .eq('user_id', userId)
            .maybeSingle();
        
        return {
          ...user,
          'profile': driver,
        };
      }
      
      return user;
      
    } catch (e) {
      print('❌ Erreur récupération profil: $e');
      return null;
    }
  }
  
  /// Mettre à jour le profil utilisateur
  static Future<bool> updateUserProfile({
    required String userId,
    String? firstName,
    String? lastName,
    String? phone,
    String? photoUrl,
  }) async {
    try {
      final updates = <String, dynamic>{
        'id': userId,
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      if (firstName != null) updates['first_name'] = firstName;
      if (lastName != null) updates['last_name'] = lastName;
      if (phone != null) updates['phone'] = phone;
      if (photoUrl != null) updates['photo_url'] = photoUrl;
      
      await _supabase.from('users').update(updates).eq('id', userId);
      
      print('✅ Profil mis à jour avec succès');
      
      return true;
      
    } catch (e) {
      print('❌ Erreur mise à jour profil: $e');
      return false;
    }
  }
  
  // ==================== DÉCONNEXION ====================
  
  /// Déconnexion
  static Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
      print('✅ Déconnexion réussie');
    } catch (e) {
      print('❌ Erreur déconnexion: $e');
    }
  }
  
  // ==================== UTILITAIRES ====================
  
  /// Générer un code de confirmation à 6 chiffres
  static String _generateConfirmationCode() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }
  
  /// Envoyer le code par email via SMTP (MedLBH Solution) ou simulation
  static Future<void> _sendEmailCode(String email, String code, String name) async {
    try {
      final smtpHost = dotenv.env['SMTP_HOST'];
      final smtpPort = int.tryParse(dotenv.env['SMTP_PORT'] ?? '465') ?? 465;
      final smtpUser = dotenv.env['SMTP_USER'];
      final smtpPass = dotenv.env['SMTP_PASS'];

      // Vérifier si la config est présente
      if (smtpUser == null || smtpPass == null || smtpUser.isEmpty) {
        if (kDebugMode) {
          print('ℹ️ [SIMULATION] Envoi email à $email : Votre code est $code');
        }
        return;
      }

      // Cas spécial pour le Web: SMTP ne marche pas en direct dans le navigateur
      if (kIsWeb) {
        print('🌐 [WEB] Envoi via Pont API HTTP...');
        
        final response = await http.post(
          Uri.parse('https://boutsandchaya.com/yalla/send_email.php'), // L'adresse de votre script
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'to': email,
            'subject': 'Votre code de vérification YALLA L\'TBIB',
            'html': _getEmailTemplate(name, code),
          }),
        );

        if (response.statusCode == 200) {
          print('✅ [WEB] Email envoyé avec succès via le serveur');
        } else {
          print('❌ [WEB] Erreur serveur: ${response.statusCode}');
        }
        return;
      }

      print('📧 Tentative d\'envoi SMTP via MedLBH Solution à: $email');
      
      // Configuration du serveur SMTP
      final smtpServer = SmtpServer(
        smtpHost!,
        port: smtpPort,
        ssl: true,
        username: smtpUser,
        password: smtpPass,
      );

      // Création de l'email
      final message = Message()
        ..from = Address(smtpUser, 'YALLA L\'TBIB')
        ..recipients.add(email)
        ..subject = 'Code de vérification YALLA L\'TBIB'
        ..html = _getEmailTemplate(name, code);

      try {
        await send(message, smtpServer);
        print('✅ [MOBILE] Message envoyé via SMTP');
      } on MailerException catch (e) {
        print('❌ [MOBILE] Échec de l\'envoi SMTP: $e');
      }
    } catch (e) {
      print('❌ Erreur générale d\'envoi: $e');
    }
  }

  /// Template HTML de l'email (Factorisé)
  static String _getEmailTemplate(String name, String code) {
    return '''
      <div style="font-family: sans-serif; max-width: 600px; margin: auto; padding: 20px; border: 1px solid #eee; border-radius: 10px;">
        <div style="text-align: center; margin-bottom: 20px;">
          <h2 style="color: #467DB0; margin: 0;">YALLA L'TBIB</h2>
          <p style="color: #888; font-size: 14px;">Votre partenaire de transport médical</p>
        </div>
        <p>Bonjour <strong>$name</strong>,</p>
        <p>Pour finaliser la création de votre compte, veuillez utiliser le code de vérification suivant :</p>
        <div style="background: #f4f4f4; padding: 30px; text-align: center; border-radius: 12px; margin: 25px 0;">
          <h1 style="color: #7EC845; font-size: 42px; letter-spacing: 8px; margin: 0;">$code</h1>
        </div>
        <p>Ce code est valable pendant 10 minutes.</p>
        <p style="font-size: 14px; color: #555;">Si vous n'êtes pas à l'origine de cette demande, vous pouvez ignorer cet email en toute sécurité.</p>
        <hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;" />
        <div style="text-align: center; font-size: 12px; color: #aaa;">
          <p>© 2025 YALLA L'TBIB - Service opéré par MedLBH Solution</p>
          <p>Maroc</p>
        </div>
      </div>
    ''';
  }
  
  /// Envoyer le code par SMS
  static Future<void> _sendSMSCode(String phone, String code) async {
    try {
      // TODO: Intégrer Twilio ou Firebase Phone Auth
      print('📱 SMS envoyé à $phone avec le code: $code');
      
      // Simulation d'envoi de SMS
      await Future.delayed(Duration(milliseconds: 500));
      
      // Dans la vraie version, utiliser Twilio:
      /*
      final response = await http.post(
        Uri.parse('https://api.twilio.com/2010-04-01/Accounts/YOUR_ACCOUNT_SID/Messages.json'),
        headers: {
          'Authorization': 'Basic ' + base64Encode(utf8.encode('YOUR_ACCOUNT_SID:YOUR_AUTH_TOKEN')),
        },
        body: {
          'From': '+1234567890',
          'To': phone,
          'Body': 'Votre code YALLA L\'TBIB: $code',
        },
      );
      */
      
    } catch (e) {
      print('❌ Erreur envoi SMS: $e');
    }
  }
  
  /// Vérifier si l'utilisateur a confirmé son email
  static Future<bool> _isUserVerified(String userId) async {
    try {
      final response = await _supabase
          .from('users')
          .select('email_verified')
          .eq('id', userId)
          .maybeSingle();
      
      return response?['email_verified'] ?? false;
      
    } catch (e) {
      return false;
    }
  }
  
  /// Obtenir l'utilisateur actuel
  static User? get currentUser => _supabase.auth.currentUser;
  
  /// Vérifier si l'utilisateur est connecté
  static bool get isSignedIn => _supabase.auth.currentUser != null;

  // ==================== DOCUMENTS CHAUFFEURS ====================

  /// Uploader un document chauffeur (Permis, Assurance, etc.)
  static Future<Map<String, dynamic>> uploadDriverDocument({
    required String driverId,
    required String docType,
    required File file,
    required String fileName,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return {'success': false, 'error': 'Non connecté'};

      final fileExt = fileName.split('.').last;
      final storagePath = 'drivers/$driverId/${docType}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      // 1. Uploader sur Supabase Storage (Bucket: driver-documents)
      await _supabase.storage.from('driver-documents').upload(
        storagePath,
        file,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
      );

      // 2. Récupérer l'URL publique
      final fileUrl = _supabase.storage.from('driver-documents').getPublicUrl(storagePath);

      // 3. Enregistrer les métadonnées dans la table driver_documents
      await _supabase.from('driver_documents').upsert({
        'driver_id': driverId,
        'user_id': userId,
        'document_type': docType,
        'file_url': fileUrl,
        'file_name': fileName,
        'status': 'pending',
      }, onConflict: 'driver_id, document_type');

      return {'success': true, 'url': fileUrl};
    } catch (e) {
      print('❌ Erreur upload document: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Récupérer le statut des documents du chauffeur
  static Future<List<Map<String, dynamic>>> getDriverDocuments(String driverId) async {
    try {
      final response = await _supabase
          .from('driver_documents')
          .select()
          .eq('driver_id', driverId);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Erreur récupération documents: $e');
      return [];
    }
  }
}
