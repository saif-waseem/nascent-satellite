// Firebase options for cars_app - same project as pos_app
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCjmGWBANCyPt3sFF6L7Cxp1N1I_w_E5Ws',
    appId: '1:1031487835291:web:f4e2721771a01e7be58a3e',
    messagingSenderId: '1031487835291',
    projectId: 'my-store-b0723',
    authDomain: 'my-store-b0723.firebaseapp.com',
    storageBucket: 'my-store-b0723.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCjmGWBANCyPt3sFF6L7Cxp1N1I_w_E5Ws',
    appId: '1:1031487835291:android:f4e2721771a01e7be58a3e',
    messagingSenderId: '1031487835291',
    projectId: 'my-store-b0723',
    storageBucket: 'my-store-b0723.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDQ1c4wUo9_18i1zpitgV9A5WWnFyy15xY',
    appId: '1:1031487835291:ios:ab245a97dd71b515e58a3e',
    messagingSenderId: '1031487835291',
    projectId: 'my-store-b0723',
    storageBucket: 'my-store-b0723.firebasestorage.app',
    iosBundleId: 'com.saas.ecommerce.carsApp',
  );
}
