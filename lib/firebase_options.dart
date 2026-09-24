// File: firebase_options.dart

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDEa8JjdkESv1WFAz0U7AYla1i00SwyHtQ',
    appId: '1:507064853156:web:3181707ff9799b06067c31',
    messagingSenderId: '507064853156',
    projectId: 'my-print-shop-7b153',
    authDomain: 'my-print-shop-7b153.firebaseapp.com',
    storageBucket: 'my-print-shop-7b153.firebasestorage.app',
    measurementId: 'G-YSJYSEJ1E3',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC9HdsbPr6gCeZ1138zQQEYMTovT__niSc',
    appId: '1:507064853156:android:5c94e483133c8399067c31',
    messagingSenderId: '507064853156',
    projectId: 'my-print-shop-7b153',
    storageBucket: 'my-print-shop-7b153.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyB8ojgv14cfubelKn6MXquhkmwv9zXQ6nA',
    appId: '1:507064853156:ios:20cf58279b0284f5067c31',
    messagingSenderId: '507064853156',
    projectId: 'my-print-shop-7b153',
    storageBucket: 'my-print-shop-7b153.firebasestorage.app',
    iosBundleId: 'com.example.myPrintShop',
  );
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDeA8JjdkESv1WFAz0U7AYla1i00SwyHtQ',
    appId: '1:507064853156:ios:eaf2909de1bd0330067c31',
    messagingSenderId: '507064853156',
    projectId: 'my-print-shop-7b153',
    storageBucket: 'my-print-shop-7b153.firebasestorage.app',
    iosBundleId: 'com.example.myPrintShop',
  );
}
