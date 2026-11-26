import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';

import 'firebase_options.dart';
import 'features/auth/auth_gate.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/app_colors.dart';

// ==================================================
// ORBIT - MAIN
// ==================================================
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 2. Detect device and configure Firebase
  await configureFirebase();

  // 4. Launch ORBIT
  runApp(const OrbitApp());
}

// ==================================================
// AUTOMATIC FIREBASE CONFIGURATION
// ==================================================
Future<void> configureFirebase() async {
  // Release mode always uses Firebase Cloud.
  if (!kDebugMode) {
    debugPrint('ORBIT Firebase: RELEASE -> CLOUD');
    return;
  }

  // This configuration targets Android devices.
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    debugPrint('ORBIT Firebase: NON-ANDROID -> CLOUD');
    return;
  }

  try {
    // Detect the Android device type.
    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;

    final bool isPhysicalDevice = androidInfo.isPhysicalDevice;

    debugPrint('ORBIT Device: ${androidInfo.model}');

    // ================================================
    // PHYSICAL ANDROID DEVICE
    // USB DEBUGGING / WIRELESS DEBUGGING
    // ================================================
    if (isPhysicalDevice) {
      debugPrint('ORBIT Firebase: PHYSICAL DEVICE -> CLOUD');

      // No emulator configuration needed.
      // Firebase uses its default cloud endpoints.
      return;
    }

    // ================================================
    // ANDROID EMULATOR
    // ================================================
    debugPrint('ORBIT Firebase: ANDROID EMULATOR -> LOCAL');

    // Android Emulator accesses the host PC
    // using 10.0.2.2.
    const String host = '10.0.2.2';

    // Firebase Authentication Emulator
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);

    // Cloud Firestore Emulator
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);

    // Cloud Functions Emulator
    FirebaseFunctions.instanceFor(region: 'asia-southeast1')
        .useFunctionsEmulator(host, 5001);

    debugPrint('ORBIT Firebase: LOCAL EMULATORS CONFIGURED');

    debugPrint('Auth: $host:9099');

    debugPrint('Firestore: $host:8080');

    debugPrint('Functions: $host:5001');
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

      // ==============================================
      // GLOBAL APP THEME
      // ==============================================
      themeMode: ThemeMode.dark,

      theme: AppTheme.darkTheme.copyWith(
        scaffoldBackgroundColor: Colors.transparent,
      ),

      builder: (context, child) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness: Brightness.light,
          ),
          child: ColoredBox(
            color: AppColors.background,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // background image
                Positioned.fill(
                  child: IgnorePointer(
                    child: Image.asset(
                      'lib/core/assets/bg.jpg',
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.expand(),
                    ),
                  ),
                ),

                // dark overlay
                Positioned.fill(
                  child: IgnorePointer(
                    child: ColoredBox(
                      color: AppColors.background.withValues(alpha: 0.72),
                    ),
                  ),
                ),

                if (child != null) Positioned.fill(child: child),
              ],
            ),
          ),
        );
      },

      // ==============================================
      // AUTHENTICATION GATE
      // ==============================================
      home: const AuthGate(),
    );
  }
}
