// Konfigurasi ini dibuat agar nilai sensitif tidak langsung dikommit.
// Isi semua variabel `FIREBASE_*` saat menjalankan `flutter run`, `flutter build`,
// atau tugas CI dengan `--dart-define` agar Firebase dapat terhubung.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions belum diatur untuk platform ini.',
        );
    }
  }

  static FirebaseOptions get android => FirebaseOptions(
        apiKey: _requireConfigured(_androidApiKey, 'FIREBASE_ANDROID_API_KEY'),
        appId: _requireConfigured(_androidAppId, 'FIREBASE_ANDROID_APP_ID'),
        messagingSenderId: _requireConfigured(
          _androidMessagingSenderId,
          'FIREBASE_ANDROID_MESSAGING_SENDER_ID',
        ),
        projectId: _requireConfigured(
          _androidProjectId,
          'FIREBASE_ANDROID_PROJECT_ID',
        ),
        storageBucket: _requireConfigured(
          _androidStorageBucket,
          'FIREBASE_ANDROID_STORAGE_BUCKET',
        ),
      );

  static FirebaseOptions get web => FirebaseOptions(
        apiKey: _requireConfigured(_webApiKey, 'FIREBASE_WEB_API_KEY'),
        appId: _requireConfigured(_webAppId, 'FIREBASE_WEB_APP_ID'),
        messagingSenderId: _requireConfigured(
          _webMessagingSenderId,
          'FIREBASE_WEB_MESSAGING_SENDER_ID',
        ),
        projectId: _requireConfigured(
          _webProjectId,
          'FIREBASE_WEB_PROJECT_ID',
        ),
        authDomain: _requireConfigured(
          _webAuthDomain,
          'FIREBASE_WEB_AUTH_DOMAIN',
        ),
        storageBucket: _requireConfigured(
          _webStorageBucket,
          'FIREBASE_WEB_STORAGE_BUCKET',
        ),
        measurementId: _requireConfigured(
          _webMeasurementId,
          'FIREBASE_WEB_MEASUREMENT_ID',
        ),
      );
}

String _requireConfigured(String value, String envName) {
  if (value.startsWith('<') && value.endsWith('>')) {
    throw StateError(
      'Variabel $envName belum diset. Tetapkan nilainya lewat --dart-define ' 
      'atau ikuti panduan README.md.',
    );
  }
  return value;
}

const String _androidApiKey =
    String.fromEnvironment('FIREBASE_ANDROID_API_KEY',
        defaultValue: '<FIREBASE_ANDROID_API_KEY>');
const String _androidAppId =
    String.fromEnvironment('FIREBASE_ANDROID_APP_ID',
        defaultValue: '<FIREBASE_ANDROID_APP_ID>');
const String _androidMessagingSenderId =
    String.fromEnvironment('FIREBASE_ANDROID_MESSAGING_SENDER_ID',
        defaultValue: '<FIREBASE_ANDROID_MESSAGING_SENDER_ID>');
const String _androidProjectId =
    String.fromEnvironment('FIREBASE_ANDROID_PROJECT_ID',
        defaultValue: '<FIREBASE_ANDROID_PROJECT_ID>');
const String _androidStorageBucket =
    String.fromEnvironment('FIREBASE_ANDROID_STORAGE_BUCKET',
        defaultValue: '<FIREBASE_ANDROID_STORAGE_BUCKET>');

const String _webApiKey =
    String.fromEnvironment('FIREBASE_WEB_API_KEY',
        defaultValue: '<FIREBASE_WEB_API_KEY>');
const String _webAppId =
    String.fromEnvironment('FIREBASE_WEB_APP_ID',
        defaultValue: '<FIREBASE_WEB_APP_ID>');
const String _webMessagingSenderId =
    String.fromEnvironment('FIREBASE_WEB_MESSAGING_SENDER_ID',
        defaultValue: '<FIREBASE_WEB_MESSAGING_SENDER_ID>');
const String _webProjectId =
    String.fromEnvironment('FIREBASE_WEB_PROJECT_ID',
        defaultValue: '<FIREBASE_WEB_PROJECT_ID>');
const String _webAuthDomain =
    String.fromEnvironment('FIREBASE_WEB_AUTH_DOMAIN',
        defaultValue: '<FIREBASE_WEB_AUTH_DOMAIN>');
const String _webStorageBucket =
    String.fromEnvironment('FIREBASE_WEB_STORAGE_BUCKET',
        defaultValue: '<FIREBASE_WEB_STORAGE_BUCKET>');
const String _webMeasurementId =
    String.fromEnvironment('FIREBASE_WEB_MEASUREMENT_ID',
        defaultValue: '<FIREBASE_WEB_MEASUREMENT_ID>');
