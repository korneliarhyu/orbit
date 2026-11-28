import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Branded loading screen shown while AuthGate resolves the player session.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: AspectRatio(
                aspectRatio: 1.6,
                child: CustomPaint(
                  foregroundPainter: _OrbitStarPainter(_controller),
                  child: Center(
                    child: FractionallySizedBox(
                      widthFactor: 0.73,
                      child: Image.asset(
                        'lib/core/assets/orbit_wordmark.png',
                        fit: BoxFit.contain,
                        semanticLabel: 'ORBIT',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrbitStarPainter extends CustomPainter {
  _OrbitStarPainter(this.animation) : super(repaint: animation);

  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final rx = size.width * 0.44;
    final ry = size.height * 0.25;
    const tilt = -0.28;
    final t = animation.value * 2 * math.pi - math.pi / 4;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(tilt);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2),
      Paint()
        ..color = AppColors.primary.withValues(alpha: 0.17)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
    final x = rx * math.cos(t);
    final y = ry * math.sin(t);
    canvas.restore();

    final star =
        center +
        Offset(
          x * math.cos(tilt) - y * math.sin(tilt),
          x * math.sin(tilt) + y * math.cos(tilt),
        );
    canvas.save();
    canvas.translate(star.dx, star.dy);
    final path = Path()
      ..moveTo(0, -8)
      ..quadraticBezierTo(1.3, -1.3, 6, 0)
      ..quadraticBezierTo(1.3, 1.3, 0, 8)
      ..quadraticBezierTo(-1.3, 1.3, -6, 0)
      ..quadraticBezierTo(-1.3, -1.3, 0, -8)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.primary.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawPath(path, Paint()..color = const Color(0xFFF2DDFB));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _OrbitStarPainter oldDelegate) =>
      oldDelegate.animation != animation;
}
