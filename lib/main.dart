import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/services/chat_storage.dart';
import 'features/splash_screen.dart';
import 'features/profile_setup_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Connect to Firebase Auth Emulator
  await FirebaseAuth.instance.useAuthEmulator(
    '10.0.2.2',
    9099,
  );

  // Connect to Firebase Functions Emulator
  FirebaseFunctions.instanceFor(
    region: 'asia-southeast1',
  ).useFunctionsEmulator(
    '10.0.2.2',
    5001,
  );

  // Login anonymously
  // Temporary: reset Firebase Auth session
  await FirebaseAuth.instance.signOut();
  await FirebaseAuth.instance.signInAnonymously();

  debugPrint(
    'AUTH RESET OK: ${FirebaseAuth.instance.currentUser != null}',
  );

  // Load saved conversations
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
      theme: AppTheme.darkTheme,
      home: const ProfileSetupScreen(),
      // home: const SplashScreen(),
    );
  }
}
