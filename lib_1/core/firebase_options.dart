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
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.iOS:
        return ios;
      default:
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD414KmJcqWXiunYGFhJjKUqk5r03vYPPI',
    appId: '1:896486425897:android:626a0a2daa0a53255f6338',
    messagingSenderId: '896486425897',
    projectId: 'institution-eaf74',
    storageBucket: 'institution-eaf74.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyD414KmJcqWXiunYGFhJjKUqk5r03vYPPI',
    appId: '1:896486425897:web:a1b2c3d4e5f6g7h8i9j0',
    messagingSenderId: '896486425897',
    projectId: 'institution-eaf74',
    storageBucket: 'institution-eaf74.firebasestorage.app',
    authDomain: 'institution-eaf74.firebaseapp.com',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyD414KmJcqWXiunYGFhJjKUqk5r03vYPPI',
    appId: '1:896486425897:web:j1k2l3m4n5o6p7q8r9s0',
    messagingSenderId: '896486425897',
    projectId: 'institution-eaf74',
    storageBucket: 'institution-eaf74.firebasestorage.app',
    authDomain: 'institution-eaf74.firebaseapp.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_IOS_API_KEY',
    appId: '1:896486425897:ios:placeholder',
    messagingSenderId: '896486425897',
    projectId: 'institution-eaf74',
    storageBucket: 'institution-eaf74.firebasestorage.app',
    iosBundleId: 'com.starlight.superconsole',
  );
}
