import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PlayerAuthService {
  PlayerAuthService._();

  static final instance = PlayerAuthService._();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static final RegExp _usernamePattern =
  RegExp(r'^[a-z0-9_]{5,12}$');

  static const String _emailDomain = 'users.orbit.example';

  // USERNAME VALIDATION & MAPPING
  String _emailFromUsername(String username) {
    final normalized = username.trim().toLowerCase();

    if (!_usernamePattern.hasMatch(normalized)) {
      throw const FormatException(
        'Username must be 5-12 characters '
            'and contain only letters, numbers, or underscores.',
      );
    }

    return '$normalized@$_emailDomain';
  }

  // REGISTER
  Future<UserCredential> register({
    required String username,
    required String password,
  }) async {
    final email = _emailFromUsername(username);

    final credential = await _executeAuth(
      'REGISTER',
          () => _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      ),
    );

    // Account creation already succeeded.
    // A profile update failure must not invalidate registration.
    final user = credential.user;

    if (user != null) {
      try {
        await user.updateDisplayName(username.trim());
        debugPrint('[AUTH] Display name updated');
      } catch (e) {
        debugPrint('[AUTH] Display name update failed: $e');
      }
    }

    return credential;
  }

  // LOGIN
  Future<UserCredential> login({
    required String username,
    required String password,
  }) async {
    final email = _emailFromUsername(username);

    return _executeAuth(
      'LOGIN',
          () => _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      ),
    );
  }

  // LOGOUT
  Future<void> logout() => _auth.signOut();

  // CURRENT USER
  User? get currentUser => _auth.currentUser;

  // CENTRALIZED AUTH ERROR HANDLING
  Future<T> _executeAuth<T>(
      String action,
      Future<T> Function() operation,
      ) async {
    try {
      final result = await operation();

      debugPrint('[AUTH][$action] SUCCESS');

      return result;
    } on FirebaseAuthException catch (e) {
      debugPrint('[AUTH][$action] FAILED: ${e.code}');

      if (kDebugMode) {
        debugPrint('[AUTH][$action] ${e.message}');
      }

      rethrow;
    } catch (e, stackTrace) {
      debugPrint('[AUTH][$action] UNEXPECTED: $e');
      debugPrintStack(stackTrace: stackTrace);

      rethrow;
    }
  }
}