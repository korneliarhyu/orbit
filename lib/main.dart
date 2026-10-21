import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/services/chat_storage.dart';
import 'features/splash_screen.dart';

Future <void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load saved conversations first
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
      home: const SplashScreen(),
    );
  }
}
