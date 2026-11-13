import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'features/chat/chat_storage.dart';
import 'features/auth/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --------------------------------------------------
  // 1. FIREBASE INITIALIZATION
  // --------------------------------------------------
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // --------------------------------------------------
  // 2. LOCAL FIREBASE EMULATORS
  // Android Emulator: 10.0.2.2
  // Debug only, never release.
  // --------------------------------------------------
  if (kDebugMode) {
    const host = '10.0.2.2';

    await FirebaseAuth.instance.useAuthEmulator(host, 9099);

    FirebaseFirestore.instance.useFirestoreEmulator(
      host,
      8080,
    );

    FirebaseFunctions.instanceFor(
      region: 'asia-southeast1',
    ).useFunctionsEmulator(host, 5001);
  }

  // --------------------------------------------------
  // 3. LOAD SAVED CONVERSATIONS
  // --------------------------------------------------
  await ChatStore.instance.initialize();

  runApp(const OrbitApp());
}

class OrbitApp extends StatelessWidget {
  const OrbitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ORBIT',

      // --------------------------------------------------
      // 4. GLOBAL APP THEME
      // --------------------------------------------------
      theme: AppTheme.darkTheme.copyWith(
        scaffoldBackgroundColor: Colors.transparent,
      ),

      // --------------------------------------------------
      // 5. GLOBAL COSMIC BACKGROUND
      // --------------------------------------------------
      builder: (context, child) {
        return Stack(
          fit: StackFit.expand,
          children: [
            // Background image
            Positioned.fill(
              child: Image.asset(
                'lib/core/assets/bg.jpg',
                fit: BoxFit.cover,
              ),
            ),

            // Dark overlay for text readability
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x990B0914),
              ),
            ),

            // Current app page / Navigator
            if (child != null)
              Positioned.fill(
                child: child,
              ),
          ],
        );
      },

      // --------------------------------------------------
      // 6. AUTHENTICATION GATE
      // --------------------------------------------------
      home: const AuthGate(),
    );
  }
}
