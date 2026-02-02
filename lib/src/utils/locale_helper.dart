import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Helper safe pour formater les dates même si les locales
/// n'ont pas encore été initialisées (hot-reload / tests).
class LocaleHelper {
  static bool _initialized = false;

  /// Tente d'initialiser les locales si nécessaire (silencieux).
  static Future<void> ensureInitialized([String locale = 'fr_FR']) async {
    if (_initialized) return;
    try {
      await initializeDateFormatting(locale, null);
      Intl.defaultLocale = locale;
    } catch (_) {
      // ignore errors - we'll fallback to default formatting
    }
    _initialized = true;
  }

  /// Formate une date de façon sûre. Si la locale n'est pas disponible,
  /// on retombe sur un format court 'dd/MM/yyyy'.
  static String formatDateSafe(DateTime date, {String pattern = 'EEEE d MMMM yyyy', String locale = 'fr_FR'}) {
    try {
      // attempt to format with intl
      final fmt = DateFormat(pattern, locale);
      return fmt.format(date);
    } catch (e) {
      // fallback
      try {
        return DateFormat('dd/MM/yyyy').format(date);
      } catch (_) {
        return date.toIso8601String().split('T').first;
      }
    }
  }
}
