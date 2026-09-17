import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/firebase_config.dart';

/// Service managing user authentication with Firebase Auth and Guest Mode fallback
class AuthService {
  static const String _guestModeKey = 'quantro_is_guest_mode';
  final SharedPreferences? _prefs;

  AuthService(this._prefs);

  /// Get current authenticated Firebase user
  User? get currentUser {
    if (!FirebaseConfig.isConfigured) return null;
    return FirebaseConfig.auth?.currentUser;
  }

  /// Check if user is currently logged in via Firebase
  bool get isLoggedIn => currentUser != null;

  /// Check if user has selected Guest (Offline-Only) Mode
  bool get isGuestMode => _prefs?.getBool(_guestModeKey) ?? false;

  /// Auth state change stream
  Stream<User?>? get authStateStream {
    if (!FirebaseConfig.isConfigured) return null;
    return FirebaseConfig.auth?.authStateChanges();
  }

  /// Sign up with Email and Password
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    final auth = _requireFirebase();
    final credential = await auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    // Exit guest mode upon successful account creation
    await setGuestMode(false);
    return credential;
  }

  /// Sign in with Email and Password
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final auth = _requireFirebase();
    final credential = await auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    // Exit guest mode upon successful login
    await setGuestMode(false);
    return credential;
  }

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb ? '277150463102-2nve9qflhf00urksfbe290rpkm5gsv4f.apps.googleusercontent.com' : null,
    serverClientId: '277150463102-2nve9qflhf00urksfbe290rpkm5gsv4f.apps.googleusercontent.com',
  );

  /// Sign in with Google OAuth
  Future<bool> signInWithGoogle() async {
    final auth = _requireFirebase();
    try {
      if (kIsWeb) {
        final googleProvider = GoogleAuthProvider();
        googleProvider.setCustomParameters({'prompt': 'select_account'});
        try {
          final userCredential = await auth.signInWithPopup(googleProvider);
          if (userCredential.user == null) return false;
          await setGuestMode(false);
          return true;
        } on FirebaseAuthException catch (e) {
          if (e.code == 'popup-closed-by-user' || e.code == 'cancelled-popup-request') {
            return false;
          }
          if (e.code == 'popup-blocked') {
            await auth.signInWithRedirect(googleProvider);
            return true;
          }
          if (e.code == 'unauthorized-domain') {
            throw Exception(
              'Domain not authorized in Firebase Console. Add this domain under Authentication > Settings > Authorized domains.',
            );
          }
          rethrow;
        }
      }

      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return false;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await auth.signInWithCredential(credential);
      await setGuestMode(false);
      return true;
    } catch (e) {
      debugPrint('Google sign in error: $e');
      final errorStr = e.toString();
      if (errorStr.contains(': 10') || errorStr.contains('ApiException: 10')) {
        throw Exception(
          'Google Sign-In configuration error (Code 10). The APK SHA-1 fingerprint (1F:58:6E:C3:EF:28:D6:3D:4D:BD:3B:C8:9F:D6:0F:F8:63:CB:5D:F2) must be registered in Firebase Console under Android Project Settings.',
        );
      }
      rethrow;
    }
  }

  /// Send password reset email
  Future<void> resetPassword(String email) async {
    final auth = _requireFirebase();
    await auth.sendPasswordResetEmail(email: email.trim());
  }

  /// Enable or disable Guest Mode
  Future<void> setGuestMode(bool value) async {
    await _prefs?.setBool(_guestModeKey, value);
  }

  /// Sign out from Firebase account
  Future<void> signOut() async {
    if (FirebaseConfig.isConfigured && auth != null) {
      await auth!.signOut();
      if (!kIsWeb) {
        try {
          await _googleSignIn.signOut();
        } catch (e) {
          debugPrint('Google sign out error: $e');
        }
      }
    }
    // Note: signing out does not force guest mode automatically; user goes to AuthScreen
    await setGuestMode(false);
  }

  FirebaseAuth _requireFirebase() {
    final instance = FirebaseConfig.auth;
    if (instance == null) {
      throw Exception(
        'Firebase is not configured yet. Please configure credentials in Settings or continue in Offline Guest Mode.',
      );
    }
    return instance;
  }

  FirebaseAuth? get auth => FirebaseConfig.auth;
}
