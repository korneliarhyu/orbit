import 'package:flutter/foundation.dart';

class OrbitLogger {
  OrbitLogger._();

  static void debug(String message) {
    if (!kDebugMode) return;

    debugPrint('[ORBIT] $message');
  }

  static void error(String message, {Object? error, StackTrace? stackTrace}) {
    if (!kDebugMode) return;

    debugPrint('[ORBIT ERROR] $message');

    if (error != null) {
      debugPrint(error.toString());
    }

    if (stackTrace != null) {
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
