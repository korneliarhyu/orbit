import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../profile/orbit_profile.dart';
import '../home_screen.dart';
import '../profile/profile_setup_screen.dart';
import 'auth_screen.dart';

enum _GatePage {
  signUp,
  buildIdentity,
  home,
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String? _checkedUid;
  Future<_GatePage>? _pageFuture;

  Future<_GatePage> _checkPlayer(User user) async {
    try {
      // Check the existing login session first.
      await user.getIdToken(true);

      if (FirebaseAuth.instance.currentUser?.uid != user.uid) {
        return _GatePage.signUp;
      }

      // Only access Firestore after checking the session.
      final profile = await OrbitProfileStore.load();

      if (profile == null) {
        return _GatePage.buildIdentity;
      }

      return _GatePage.home;
    } on FirebaseAuthException catch (error) {
      final code = error.code.toLowerCase();
      final message = (error.message ?? '').toUpperCase();

      final invalidSession = {
        'invalid-user-token',
        'user-token-expired',
        'user-disabled',
        'user-not-found',
        'invalid-credential',
      }.contains(code) ||
          message.contains('INVALID_REFRESH_TOKEN');

      if (invalidSession) {
        debugPrint('ORBIT: Invalid session, signing out.');
        if (FirebaseAuth.instance.currentUser?.uid == user.uid) {
          await FirebaseAuth.instance.signOut();
        }
        return _GatePage.signUp;
      }
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState ==
            ConnectionState.waiting) {
          return _loadingScreen();
        }

        if (authSnapshot.hasError) {
          return _errorScreen(
            'Authentication failed.',
                () => setState(() {}),
          );
        }

        final user = authSnapshot.data;
        // Not logged in: show Sign Up directly.
        if (user == null || user.isAnonymous) {
          _checkedUid = null;
          _pageFuture = null;
          return const AuthScreen();
        }

        // Recheck when the logged-in account changes.
        if (_checkedUid != user.uid || _pageFuture == null) {
          _checkedUid = user.uid;
          _pageFuture = _checkPlayer(user);
        }

        return FutureBuilder<_GatePage>(
          future: _pageFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              debugPrint(
                'ORBIT GATE ERROR: ${snapshot.error}',
              );

              return _errorScreen(
                'Unable to connect to your universe.',
                    () {
                  setState(() {
                    _pageFuture = _checkPlayer(user);
                  });
                },
              );
            }

            if (snapshot.connectionState !=
                ConnectionState.done) {
              return _loadingScreen();
            }

            switch (snapshot.data) {
              case _GatePage.signUp:
                return const AuthScreen();

              case _GatePage.buildIdentity:
                return const ProfileSetupScreen();

              case _GatePage.home:
                return const HomeScreen();

              default:
                return _loadingScreen();
            }
          },
        );
      },
    );
  }

  Widget _loadingScreen() {
    return const Scaffold(
      backgroundColor: Color(0xFF0B0718),
      body: Center(
        child: CircularProgressIndicator(
          color: Color(0xFFFF4EB8),
        ),
      ),
    );
  }

  Widget _errorScreen(
      String message,
      VoidCallback onRetry,
      ) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0718),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              color: Color(0xFFFF4EB8),
              size: 40,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFD6C2FF),
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
            TextButton(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
              },
              child: const Text('Back to Sign In'),
            ),
          ],
        ),
      ),
    );
  }
}
