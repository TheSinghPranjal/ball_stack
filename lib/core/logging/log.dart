import 'package:flutter/foundation.dart';

/// Minimal tagged logger; silent in release builds.
abstract final class Log {
  static void d(String tag, String message) {
    if (kDebugMode) debugPrint('[$tag] $message');
  }

  static void w(String tag, String message) {
    if (kDebugMode) debugPrint('[$tag] WARN $message');
  }
}
