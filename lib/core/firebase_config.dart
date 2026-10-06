import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Firebase project settings, from the app registered in the customer apps' Firebase project
/// (softix-rental-customer; its service account goes in the platform settings, under the
/// customer apps). These are identifiers, not secrets. Build with:
///
/// flutter build apk --dart-define=FIREBASE_API_KEY=... --dart-define=FIREBASE_APP_ID=... \
///   --dart-define=FIREBASE_SENDER_ID=... --dart-define=FIREBASE_PROJECT_ID=...
///
/// Without them the app runs normally, just without push notifications.
class FirebaseConfig {
  static const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const _appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const _senderId = String.fromEnvironment('FIREBASE_SENDER_ID');
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: 'softix-rental-customer');

  /// Push works on the phone apps only.
  static bool get enabled => !kIsWeb && _apiKey != '' && _appId != '' && _senderId != '';

  static FirebaseOptions get options => const FirebaseOptions(apiKey: _apiKey, appId: _appId, messagingSenderId: _senderId, projectId: _projectId);
}
