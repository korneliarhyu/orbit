import 'dart:async';

import 'package:flutter/material.dart';

import '../constants/app_spacing.dart';
import '../widgets/app_notification_banner.dart';

class OrbitNotificationService {
  OrbitNotificationService._();

  static final OrbitNotificationService instance = OrbitNotificationService._();

  OverlayEntry? _entry;
  Object? _owner;

  bool get isShowing => _entry != null;

  void show(
    BuildContext context, {
    required String name,
    required String message,
    int? avatarIndex,
    String? imageUrl,
    VoidCallback? onTap,
    Duration duration = const Duration(seconds: 4),
    Object? owner,
    OverlayState? targetOverlay,
  }) {
    if (!context.mounted || message.trim().isEmpty) return;

    final overlay =
        targetOverlay ?? Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null || !overlay.mounted) return;

    // Only one active banner for now. A queue is a later step.
    dismiss();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: _AnimatedNotification(
                  duration: duration,
                  onDismissed: () => _remove(entry),
                  child: OrbitNotificationBanner(
                    name: name,
                    message: message,
                    avatarIndex: avatarIndex,
                    imageUrl: imageUrl,
                    onTap: onTap == null
                        ? null
                        : () {
                            if (!identical(_entry, entry)) return;
                            _remove(entry);
                            onTap();
                          },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    _entry = entry;
    _owner = owner;
    overlay.insert(entry);
  }

  // If an owner is supplied, leave other owners' notifications alone.
  void dismiss({Object? owner}) {
    if (owner != null && !identical(owner, _owner)) return;
    final entry = _entry;
    if (entry != null) _remove(entry);
  }

  void _remove(OverlayEntry entry) {
    if (!identical(_entry, entry)) return;
    _entry = null;
    _owner = null;
    entry.remove();
    entry.dispose();
  }
}

class _AnimatedNotification extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final VoidCallback onDismissed;

  const _AnimatedNotification({
    required this.child,
    required this.duration,
    required this.onDismissed,
  });

  @override
  State<_AnimatedNotification> createState() => _AnimatedNotificationState();
}

class _AnimatedNotificationState extends State<_AnimatedNotification>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _position;
  Timer? _timer;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 220),
    );
    final animation = _controller.drive(CurveTween(curve: Curves.easeOutCubic));
    _opacity = animation;
    _position = animation.drive(
      Tween<Offset>(begin: const Offset(0, -1.5), end: Offset.zero),
    );
    _controller.addStatusListener(_onAnimationStatus);
    _controller.forward();
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_closing) {
      _timer?.cancel();
      _timer = Timer(widget.duration, _hide);
    }
    if (status == AnimationStatus.dismissed && _closing) {
      widget.onDismissed();
    }
  }

  void _hide() {
    if (!mounted || _closing) return;
    _closing = true;
    _timer?.cancel();
    _controller.reverse();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.removeStatusListener(_onAnimationStatus);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _position,
      child: FadeTransition(opacity: _opacity, child: widget.child),
    );
  }
}
