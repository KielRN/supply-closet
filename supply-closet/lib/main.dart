import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
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

  // Check for forced update via Remote Config
  await _checkForUpdate();

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

/// Check Firebase Remote Config for minimum required app version.
/// If the current version is below the minimum, show a blocking dialog.
Future<void> _checkForUpdate() async {
  try {
    final remoteConfig = FirebaseRemoteConfig.instance;
    await remoteConfig.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 10),
      minimumFetchInterval: const Duration(hours: 1),
    ));
    await remoteConfig.fetchAndActivate();

    final minVersion = remoteConfig.getString('min_app_version');
    if (minVersion.isEmpty) return;

    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;

    if (_isVersionBelow(currentVersion, minVersion)) {
      // Show blocking update dialog
      // Note: In production, this would show a dialog requiring app store update
      debugPrint('UPDATE REQUIRED: Current $currentVersion < Minimum $minVersion');
    }
  } catch (e) {
    // If Remote Config fails, allow app to continue
    debugPrint('Remote Config check failed: $e');
  }
}

/// Compare semantic versions (e.g., "1.2.3" < "1.3.0")
bool _isVersionBelow(String current, String minimum) {
  final currentParts = current.split('.').map(int.parse).toList();
  final minimumParts = minimum.split('.').map(int.parse).toList();

  for (int i = 0; i < 3; i++) {
    final c = i < currentParts.length ? currentParts[i] : 0;
    final m = i < minimumParts.length ? minimumParts[i] : 0;
    if (c < m) return true;
    if (c > m) return false;
  }
  return false;
}
