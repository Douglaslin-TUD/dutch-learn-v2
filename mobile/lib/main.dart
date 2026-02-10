import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dutch_learn_app/app.dart';
import 'package:dutch_learn_app/injection_container.dart';

/// Global error log for displaying on error screen.
final List<String> _errorLog = [];

/// Application entry point.
void main() async {
  // Catch all Flutter framework errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    _errorLog.add('[Flutter] ${details.exceptionAsString()}\n${details.stack}');
    debugPrint('HEARLOOP_ERROR: ${details.exceptionAsString()}');
  };

  // Catch all async errors in a zone
  runZonedGuarded(() async {
    // Ensure Flutter is initialized
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize sqflite_ffi for desktop platforms
    if (!kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    // Set preferred orientations
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Initialize SharedPreferences
    final sharedPreferences = await SharedPreferences.getInstance();

    // Run the app with Riverpod
    runApp(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        ],
        child: const DutchLearnApp(),
      ),
    );
  }, (error, stackTrace) {
    _errorLog.add('[Zone] $error\n$stackTrace');
    debugPrint('HEARLOOP_ERROR: $error\n$stackTrace');
    // If app hasn't started yet, show error screen
    if (_errorLog.length == 1) {
      runApp(ErrorApp(error: error.toString(), stack: stackTrace.toString()));
    }
  });
}

/// Emergency error display app when the main app fails to start.
class ErrorApp extends StatelessWidget {
  final String error;
  final String stack;

  const ErrorApp({super.key, required this.error, required this.stack});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('HearLoop - Startup Error'),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'The app failed to start. Error details:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  error,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    color: Colors.red,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Stack trace:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  stack,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
