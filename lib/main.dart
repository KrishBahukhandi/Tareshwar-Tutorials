// ─────────────────────────────────────────────────────────────
//  main.dart  –  App entry point
// ─────────────────────────────────────────────────────────────
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/app_router.dart';
import 'shared/services/app_logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (AppConstants.supabaseUrl.isEmpty ||
      AppConstants.supabaseAnonKey.isEmpty) {
    throw StateError(
      'Missing Supabase configuration. Pass SUPABASE_URL and SUPABASE_ANON_KEY with --dart-define.',
    );
  }

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    AppLogger.error(
      'Unhandled Flutter framework error',
      name: 'flutter',
      error: details.exception,
      stackTrace: details.stack,
    );
  };

  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    AppLogger.error(
      'Unhandled platform error',
      name: 'platform',
      error: error,
      stackTrace: stack,
    );
    return true;
  };

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );

  runApp(const ProviderScope(child: TareshwarApp()));
}

class TareshwarApp extends ConsumerWidget {
  const TareshwarApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
