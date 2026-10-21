import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {

  late final AnimationController _entranceController;
  late final AnimationController _orbitController;

  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();

    // Logo and text entrance animation
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeInOut,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: Curves.easeOutBack,
      ),
    );

    // Continuous orbit rotation
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _entranceController.forward();

    // Navigate after 3 seconds
    _navigationTimer = Timer(
      const Duration(seconds: 3),
          () {
        if (!mounted) return;

        Navigator.of(context).pushReplacement(
          PageRouteBuilder<void>(
            pageBuilder: (
                context,
                animation,
                secondaryAnimation,
                ) => const HomeScreen(),
            transitionDuration: const Duration(
              milliseconds: 600,
            ),
            transitionsBuilder: (
                context,
                animation,
                secondaryAnimation,
                child,
                ) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
          ),
        );

          },
    );
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _entranceController.dispose();
    _orbitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [

          // Galaxy background
          Image.asset(
            'lib/core/assets/bg.jpg',
            fit: BoxFit.cover,
          ),

          // Dark overlay for readability
          const ColoredBox(
            color: Color(0xBB0B0914),
          ),

          // Subtle cosmic glow
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 0.9,
                colors: [
                  Color(0x443F1675),
                  Colors.transparent,
                ],
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 30,
              ),
              child: Column(
                children: [
                  const Spacer(),

                  // Animated central logo
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Column(
                        children: [
                          SizedBox(
                            width: 220,
                            height: 220,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [

                                // Rotating orbit rings
                                RotationTransition(
                                  turns: _orbitController,
                                  child: CustomPaint(
                                    size: const Size(210, 210),
                                    painter: _OrbitPainter(),
                                  ),
                                ),

                                // Glowing planet
                                Container(
                                  width: 105,
                                  height: 105,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const RadialGradient(
                                      colors: [
                                        Color(0xFFFFB7ED),
                                        Color(0xFF984DE1),
                                        Color(0xFF391461),
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primaryPink
                                            .withAlpha(105),
                                        blurRadius: 55,
                                        spreadRadius: 12,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.auto_awesome_rounded,
                                    color: Colors.white,
                                    size: 34,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 30),

                          const Text(
                            'ORBIT',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 44,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 10,
                            ),
                          ),

                          const SizedBox(height: 12),

                          const Text(
                            'A world that remembers you.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.softLilac,
                              fontSize: 14,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Bottom loading section
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        const Text(
                          'ENTERING YOUR UNIVERSE',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                            letterSpacing: 3,
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                        const SizedBox(height: 20),

                        SizedBox(
                          width: 140,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(
                                begin: 0,
                                end: 1,
                              ),
                              duration: const Duration(
                                seconds: 3,
                              ),
                              builder: (context, value, child) {
                                return LinearProgressIndicator(
                                  value: value,
                                  minHeight: 3,
                                  backgroundColor:
                                  AppColors.cardSoft,
                                  valueColor:
                                  const AlwaysStoppedAnimation(
                                    AppColors.primaryPink,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom orbit ring illustration
class _OrbitPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(
      size.width / 2,
      size.height / 2,
    );

    // First orbit
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-math.pi / 4);

    final firstPaint = Paint()
      ..color = AppColors.primaryPink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: 205,
        height: 95,
      ),
      firstPaint,
    );

    canvas.restore();

    // Second orbit
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(math.pi / 4);

    final secondPaint = Paint()
      ..color = AppColors.softLilac.withAlpha(130)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: 190,
        height: 85,
      ),
      secondPaint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
