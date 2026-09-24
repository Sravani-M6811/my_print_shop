import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('App Check release posture (web)', () {
    late String main;

    setUpAll(() {
      main = File('lib/main.dart').readAsStringSync();
    });

    test('reCAPTCHA site key is injected at build time, never committed', () {
      expect(main, contains("String.fromEnvironment('RECAPTCHA_SITE_KEY')"));
      final siteKeyLiteral = RegExp("['\"]6L[A-Za-z0-9_\\-]{38}['\"]");
      expect(siteKeyLiteral.hasMatch(main), isFalse,
          reason: 'a real reCAPTCHA site key must not be hard-coded');
    });

    test('release web builds use reCAPTCHA v3, never the debug provider', () {
      expect(main, contains('if (kDebugMode) return WebDebugProvider();'));
      expect(main, contains('return ReCaptchaV3Provider(_reCaptchaSiteKey);'));
    });

    test('release web fails closed when the site key is missing', () {
      expect(main, contains('_reCaptchaSiteKey.isEmpty'));
      expect(main, contains('throw StateError'));
    });

    test('release Android/Apple use Play Integrity and Device Check', () {
      expect(main, contains('AndroidDebugProvider'));
      expect(main, contains('AndroidPlayIntegrityProvider'));
      expect(main, contains('AppleDebugProvider'));
      expect(main, contains('AppleDeviceCheckProvider'));
      // Debug providers are gated to the debug branch of the ternary.
      expect(main, contains('providerAndroid: kDebugMode'));
      expect(main, contains('providerApple: kDebugMode'));
    });
  });

  group('No committed App Check debug token', () {
    test('no app source file assigns a FIREBASE_APPCHECK_DEBUG_TOKEN value', () {
      final files = <File>[
        ...['lib/frontend', 'lib/admin', 'lib/ui']
            .expand((root) => Directory(root)
                .listSync(recursive: true)
                .whereType<File>()
                .where((f) => f.path.endsWith('.dart')))
            .cast<File>(),
        File('lib/main.dart'),
      ];
      expect(files, isNotEmpty);
      for (final file in files) {
        final content = file.readAsStringSync();
        expect(content, isNot(contains('FIREBASE_APPCHECK_DEBUG_TOKEN = ')),
            reason: '${file.path} must not commit an App Check debug token');
        final tokenLiteral = RegExp("['\"][A-Za-z0-9+/]{128}['\"]");
        expect(tokenLiteral.hasMatch(content), isFalse,
            reason: '${file.path} must not embed an App Check debug token');
      }
    });
  });

  group('Web App Check storage cleanup', () {
    late String web;

    setUpAll(() {
      web = File('lib/frontend/services/app_check_storage_cleanup_web.dart')
          .readAsStringSync();
    });

    test('cleanup never disables App Check or touches real tokens', () {
      expect(web, contains('activate'));
      expect(web, isNot(contains('deactivate')));
      expect(web, isNot(contains('appCheckToken')));
    });

    test('cleanup removes only provider-selection keys', () {
      expect(web, contains('recaptchaType'));
      expect(web, contains('recaptchaSiteKey'));
    });
  });

  group('Android release hardening', () {
    test('release manifest does not globally allow cleartext traffic', () {
      final main = File('android/app/src/main/AndroidManifest.xml')
          .readAsStringSync();
      expect(main, isNot(contains('usesCleartextTraffic')));
    });

    test('cleartext HTTP is allowed only in dev build overlays', () {
      for (final variant in ['debug', 'profile']) {
        final overlay = File('android/app/src/$variant/AndroidManifest.xml')
            .readAsStringSync();
        expect(overlay, contains('usesCleartextTraffic="true"'),
            reason: '$variant overlay must allow cleartext for local dev');
      }
    });
  });
}