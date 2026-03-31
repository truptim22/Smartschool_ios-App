// lib/firebase_options.dart
// ignore_for_file: type=lint
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
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAeX1s1F1w6EVVUp9OsAJoqEKM2BaXmTJA',
    appId: '1:869078929067:web:a15c4bba512386ff7671ee',
    messagingSenderId: '869078929067',
    projectId: 'smartschool-8e775',
    authDomain: 'smartschool-8e775.firebaseapp.com',
    storageBucket: 'smartschool-8e775.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBL8ijXhe0h3Y_lSCxulCAWT3-2aHq_Azw',
    appId: '1:869078929067:android:4a3447582c4c99f17671ee',
    messagingSenderId: '869078929067',
    projectId: 'smartschool-8e775',
    storageBucket: 'smartschool-8e775.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyD226z44n-27jHimnWuE2YNrwCIEu5YlQU',
    appId: '1:869078929067:ios:546d84d680d0b86b7671ee',
    messagingSenderId: '869078929067',
    projectId: 'smartschool-8e775',
    storageBucket: 'smartschool-8e775.firebasestorage.app',
    iosBundleId: 'com.lantechcomputers.smartschool',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyD226z44n-27jHimnWuE2YNrwCIEu5YlQU',
    appId: '1:869078929067:ios:546d84d680d0b86b7671ee',
    messagingSenderId: '869078929067',
    projectId: 'smartschool-8e775',
    storageBucket: 'smartschool-8e775.firebasestorage.app',
    iosBundleId: 'com.lantechcomputers.smartschool',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAeX1s1F1w6EVVUp9OsAJoqEKM2BaXmTJA',
    appId: '1:869078929067:web:e7905bc301b095a07671ee',
    messagingSenderId: '869078929067',
    projectId: 'smartschool-8e775',
    authDomain: 'smartschool-8e775.firebaseapp.com',
    storageBucket: 'smartschool-8e775.firebasestorage.app',
  );
}