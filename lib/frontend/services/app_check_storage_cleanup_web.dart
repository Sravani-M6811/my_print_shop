import 'package:web/web.dart' as web;

/// Firebase app name used by [FirebaseAppCheck] storage keys below.
///
/// Matches `defaultFirebaseAppName` from `firebase_core_platform_interface`
/// (`'[DEFAULT]'`). Only the default app is used by this app.
const String _defaultFirebaseAppName = '[DEFAULT]';

/// localStorage/sessionStorage keys FlutterFire's web plugin uses to persist
/// the last-used App Check web provider for the default app.
const String _appCheckTypeKey = 'FlutterFire-$_defaultFirebaseAppName-recaptchaType';
const String _appCheckSiteKeyKey =
    'FlutterFire-$_defaultFirebaseAppName-recaptchaSiteKey';

/// Removes FlutterFire's persisted App Check *provider selection* from web
/// storage. Web only.
///
/// The FlutterFire web plugin re-activates the last-used App Check provider
/// from localStorage/sessionStorage from inside `Firebase.initializeApp()`
/// (its registered `ensurePluginInitialized` hook), which runs BEFORE `main()`
/// can call `FirebaseAppCheck.activate`. If that persisted provider is stale —
/// e.g. a reCAPTCHA v3 provider stored with a test/invalid site key from an
/// earlier run — the plugin pre-initializes App Check with the wrong key:
/// reCAPTCHA token exchange then fails with HTTP 403, App Check applies its
/// 24-hour "initial-throttle", every Firestore request fails, and the later
/// `activate()` call throws `app-check/already-initialized`.
///
/// Clearing the selection keys first makes the ONLY App Check initialization
/// the one `main()` performs with the provider chosen for the current build.
/// Real App Check tokens (which live in IndexedDB under
/// `firebase-app-check-store`) are NOT touched, and App Check itself is never
/// disabled.
void clearAppCheckProviderSelectionOnWeb() {
  for (final store in [web.window.localStorage, web.window.sessionStorage]) {
    store.removeItem(_appCheckTypeKey);
    store.removeItem(_appCheckSiteKeyKey);
  }
}