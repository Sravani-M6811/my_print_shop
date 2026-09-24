import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'firebase_options.dart';
import 'ui/theme/app_theme.dart';
import 'frontend/l10n/generated/app_localizations.dart';
import 'frontend/screens/auth_gate.dart';
import 'frontend/providers/app_state.dart';
import 'frontend/services/app_check_storage_cleanup.dart';
import 'frontend/services/customer_catalogue.dart';

/// reCAPTCHA v3 site key for App Check on Flutter Web. Passed at build time via
/// `--dart-define=RECAPTCHA_SITE_KEY=<key>` so the production key is never
/// committed to source.
///
/// In debug mode on web, App Check uses FlutterFire's [WebDebugProvider]
/// (Firebase's official "debug provider" for local development) instead of real
/// reCAPTCHA, so local development never hits 403/throttle errors from a test
/// or unset site key.
///
/// Before shipping the web release:
///   1. Google reCAPTCHA admin console (https://www.google.com/recaptcha/admin)
///      -> create a reCAPTCHA v3 site -> note the site key (not the secret).
///   2. Firebase Console -> Project Settings -> App Check -> Apps -> Web app
///      -> register the web app, select reCAPTCHA v3 provider, enable
///      enforcement.
///   3. Rebuild with `--dart-define=RECAPTCHA_SITE_KEY=<real site key>`.
const String _reCaptchaSiteKey = String.fromEnvironment('RECAPTCHA_SITE_KEY');

/// Selects the Firebase App Check web provider for the current build.
///
/// Debug (local development): uses FlutterFire's [WebDebugProvider], the
/// mechanism documented for the installed `firebase_app_check` version. It sets
/// `self.FIREBASE_APPCHECK_DEBUG_TOKEN` (via `dart:js_interop` inside the
/// plugin) immediately before App Check initializes, so the Firebase JS SDK
/// switches its internal provider to the debug provider: NO reCAPTCHA v3
/// verification is attempted, a local debug token is generated/read and printed
/// to the browser console, and App Check tokens come from Firebase's
/// `exchangeDebugToken` endpoint instead.
///
/// Release (production): always uses [ReCaptchaV3Provider] with the REAL site
/// key built in via `--dart-define`. The debug branch is unreachable when
/// `kDebugMode` is false, so a release build can never fall into debug mode.
WebProvider? _buildWebProvider() {
  if (!kIsWeb) return null;
  if (kDebugMode) return WebDebugProvider();
  if (_reCaptchaSiteKey.isEmpty) {
    throw StateError(
      'RECAPTCHA_SITE_KEY must be provided for release web builds so App '
      'Check can enforce web security. Rebuild with '
      '--dart-define=RECAPTCHA_SITE_KEY=<your reCAPTCHA v3 site key>.',
    );
  }
  return ReCaptchaV3Provider(_reCaptchaSiteKey);
}

/// Debug/test-only: enables Firebase's official "App Verification disabled
/// for testing" mode so console test phone numbers work without real SMS.
/// Guarded by [kDebugMode] (release/profile builds never invoke the native
/// method). See MainActivity.kt for the native bridge.
Future<void> _enableTestAppVerificationIfDebug() async {
  if (!kDebugMode) return;
  try {
    const channel = MethodChannel('com.example.my_print_shop/testing');
    await channel.invokeMethod<bool>('setAppVerificationDisabledForTesting', {
      'enable': true,
    });
  } catch (_) {
    // Non-Android platforms or missing bridge: no-op.
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Must run BEFORE Firebase.initializeApp(): the FlutterFire web plugin
  // re-activates the last-used App Check provider from web storage while
  // initializeApp() runs. Clearing the stale selection first ensures the ONLY
  // App Check initialization is the one chosen for this build below — without
  // this a previously saved reCAPTCHA site key (e.g. an invalid/test key) would
  // re-initialize App Check with that key, 403-throttle, and break Firestore
  // before `activate()` even runs.
  clearAppCheckProviderSelectionOnWeb();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Web: WebDebugProvider in debug, real ReCaptchaV3Provider in release.
  // Android/iOS: debug providers in debug builds only; production uses
  // Play Integrity / Device Check respectively.
  final WebProvider? providerWeb = _buildWebProvider();

  await FirebaseAppCheck.instance.activate(
    providerAndroid: kDebugMode
        ? const AndroidDebugProvider()
        : const AndroidPlayIntegrityProvider(),
    providerApple: kDebugMode
        ? const AppleDebugProvider()
        : const AppleDeviceCheckProvider(),
    providerWeb: providerWeb,
  );

  await _enableTestAppVerificationIfDebug();
  // Preload admin catalogue overrides in the background. Until this completes
  // (or if Firestore is unavailable) screens serve the bundled static
  // catalogue, so startup is never blocked or blank.
  unawaited(CustomerCatalogue.instance.refresh());
  runApp(
    ChangeNotifierProvider(
      create: (context) => AppState(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MY PRINT SHOP',
      themeMode: appState.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      locale: Locale(appState.localeCode),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const AuthGate(),
    );
  }
}

