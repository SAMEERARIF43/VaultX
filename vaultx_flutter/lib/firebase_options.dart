// GENERATED / PLACEHOLDER TEMPLATE FOR FLUTTERFIRE CLI.
// Run the following command locally in vaultx_flutter/ to bind your Android SHA-1
// and download the live Android App ID + google-services.json:
//
//   flutterfire configure --project=arctic-digit-87cdj --platforms=android
//
// Do NOT commit real Android google-services.json secrets to public repositories.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions is configured Android-first for Phase 2. '
        'Run `flutterfire configure --project=arctic-digit-87cdj --platforms=android,web` if enabling Flutter Web.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions has not been configured for $defaultTargetPlatform yet.',
        );
    }
  }

  /// Replace placeholder values by running:
  /// `flutterfire configure --project=arctic-digit-87cdj --platforms=android`
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'REPLACE_VIA_FLUTTERFIRE_CONFIGURE',
    appId: 'REPLACE_VIA_FLUTTERFIRE_CONFIGURE',
    messagingSenderId: '399637063594',
    projectId: 'arctic-digit-87cdj',
    storageBucket: 'arctic-digit-87cdj.firebasestorage.app',
  );
}
