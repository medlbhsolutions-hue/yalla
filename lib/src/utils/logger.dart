import 'package:flutter/foundation.dart';
import '../config/app_config.dart';

/// Service de logging centralisé pour l'application.
/// Remplace les print() et debugPrint() dispersés.
/// 
/// Utilisation:
/// Logger.info('Message d\'info');
/// Logger.warning('Attention quelque chose cloche');
/// Logger.error('Grosse erreur', error, stackTrace);
class Logger {
  // Empêcher l'instanciation
  Logger._();

  static void debug(String message, [String? tag]) {
    _log('🐛 DEBUG', message, tag);
  }

  static void info(String message, [String? tag]) {
    _log('ℹ️ INFO', message, tag);
  }

  static void success(String message, [String? tag]) {
    _log('✅ SUCCESS', message, tag);
  }

  static void warning(String message, [String? tag]) {
    _log('⚠️ WARNING', message, tag);
  }

  static void error(String message, [Object? error, StackTrace? stackTrace, String? tag]) {
    if (!AppConfig.enableLogs && !AppConfig.isDevelopment) {
      // En production, on pourrait envoyer l'erreur vers Crashlytics ici
      // Crashlytics.recordError(error, stackTrace, reason: message);
      return;
    }

    final tagStr = tag != null ? '[$tag] ' : '';
    debugPrint('🔴 ERROR $tagStr: $message');
    if (error != null) debugPrint('   Error: $error');
    if (stackTrace != null) debugPrint('   Stack: $stackTrace');
  }

  /// Méthode interne pour afficher le log
  static void _log(String prefix, String message, String? tag) {
    // Vérifier si les logs sont activés dans la config
    if (!AppConfig.enableLogs) return;

    final tagStr = tag != null ? '[$tag] ' : '';
    debugPrint('$prefix $tagStr$message');
  }
}
