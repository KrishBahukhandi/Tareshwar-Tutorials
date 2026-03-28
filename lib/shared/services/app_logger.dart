import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

abstract final class AppLogger {
  static void info(
    String message, {
    String name = 'app',
    Object? error,
    StackTrace? stackTrace,
  }) {
    developer.log(
      message,
      name: name,
      error: error,
      stackTrace: stackTrace,
      level: 800,
    );
  }

  static void warning(
    String message, {
    String name = 'app',
    Object? error,
    StackTrace? stackTrace,
  }) {
    developer.log(
      message,
      name: name,
      error: error,
      stackTrace: stackTrace,
      level: 900,
    );
  }

  static void error(
    String message, {
    String name = 'app',
    Object? error,
    StackTrace? stackTrace,
  }) {
    developer.log(
      message,
      name: name,
      error: error,
      stackTrace: stackTrace,
      level: 1000,
    );
    if (kDebugMode && error != null) {
      debugPrint('[$name] $message: $error');
    }
  }
}
