import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../../firebase_options.dart';

/// Configuration for Firebase remote database and authentication
class FirebaseConfig {
  static bool _isConfigured = false;

  /// Returns true if Firebase has been configured and initialized
  static bool get isConfigured => _isConfigured;

  /// Initializes Firebase safely. If options are unconfigured or init fails,
  /// returns false so the app degrades gracefully to Offline Local-Only mode.
  static Future<bool> initialize() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _isConfigured = true;
      debugPrint('Firebase initialized successfully.');
      return true;
    } catch (e) {
      debugPrint('Failed to initialize Firebase: $e. Running in offline mode.');
      _isConfigured = false;
      return false;
    }
  }

  /// Safe accessor for FirebaseAuth instance (null if unconfigured)
  static FirebaseAuth? get auth {
    if (!_isConfigured) return null;
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  /// Safe accessor for FirebaseFirestore instance (null if unconfigured)
  static FirebaseFirestore? get db {
    if (!_isConfigured) return null;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }
}
