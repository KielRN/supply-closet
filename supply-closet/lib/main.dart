import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'providers/auth_provider.dart';
import 'providers/procedure_provider.dart';
import 'providers/gamification_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Pass all uncaught Flutter errors to Crashlytics
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  // Pass all uncaught asynchronous errors to Crashlytics
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ProcedureProvider()),
        ChangeNotifierProvider(create: (_) => GamificationProvider()),
      ],
      child: const SupplyClosetApp(),
    ),
  );
}
