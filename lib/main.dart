
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';

import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'features/chat/chat_storage.dart';
import 'features/auth/auth_gate.dart';

// ==================================================
// ORBIT - MAIN
// ==================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 2. Detect device and configure Firebase
  await configureFirebase();

  // 3. Load saved conversations
  await ChatStore.instance.initialize();

  // 4. Launch ORBIT
  runApp(const OrbitApp());
}

// ==================================================
// AUTOMATIC FIREBASE CONFIGURATION
// ==================================================
Future<void> configureFirebase() async {
  // Release mode always uses Firebase Cloud.
  if (!kDebugMode) {
    debugPrint(
      'ORBIT Firebase: RELEASE -> CLOUD',
    );
    return;
  }

  // This configuration targets Android devices.
  if (kIsWeb ||
      defaultTargetPlatform != TargetPlatform.android) {
    debugPrint(
      'ORBIT Firebase: NON-ANDROID -> CLOUD',
    );
    return;
  }

  try {
    // Detect the Android device type.
    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;

    final bool isPhysicalDevice =
        androidInfo.isPhysicalDevice;

    debugPrint(
      'ORBIT Device: ${androidInfo.model}',
    );

    // ================================================
    // PHYSICAL ANDROID DEVICE
    // USB DEBUGGING / WIRELESS DEBUGGING
    // ================================================

    if (isPhysicalDevice) {
      debugPrint(
        'ORBIT Firebase: PHYSICAL DEVICE -> CLOUD',
      );

      // No emulator configuration needed.
      // Firebase uses its default cloud endpoints.
      return;
    }

    // ================================================
    // ANDROID EMULATOR
    // ================================================

    debugPrint(
      'ORBIT Firebase: ANDROID EMULATOR -> LOCAL',
    );

    // Android Emulator accesses the host PC
    // using 10.0.2.2.
    const String host = '10.0.2.2';

    // Firebase Authentication Emulator
    await FirebaseAuth.instance.useAuthEmulator(
      host,
      9099,
    );

    // Cloud Firestore Emulator
    FirebaseFirestore.instance.useFirestoreEmulator(
      host,
      8080,
    );

    // Cloud Functions Emulator
    FirebaseFunctions.instanceFor(
      region: 'asia-southeast1',
    ).useFunctionsEmulator(
      host,
      5001,
    );

    debugPrint(
      'ORBIT Firebase: LOCAL EMULATORS CONFIGURED',
    );

    debugPrint(
      'Auth: $host:9099',
    );

    debugPrint(
      'Firestore: $host:8080',
    );

    debugPrint(
      'Functions: $host:5001',
    );

  } catch (error) {
    debugPrint(
      'ORBIT Firebase: Device detection/config '
          'failed: $error',
    );

    // Do not silently switch endpoints after a
    // partial Firebase emulator configuration.
    rethrow;
  }
}

// ==================================================
// ORBIT APPLICATION
// ==================================================

class OrbitApp extends StatelessWidget {
  const OrbitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ORBIT',

      // ================================================
      // GLOBAL APP THEME
      // ================================================

      theme: AppTheme.darkTheme.copyWith(
        scaffoldBackgroundColor: Colors.transparent,
      ),

      // ================================================
      // GLOBAL COSMIC BACKGROUND
      // ================================================

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

            // Dark overlay
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x9912101D),
              ),
            ),

            // Current app screen
            if (child != null)
              Positioned.fill(
                child: child,
              ),
          ],
        );
      },

      // ================================================
      // AUTHENTICATION GATE
      // ================================================

      home: const AuthGate(),
    );
  }
}
