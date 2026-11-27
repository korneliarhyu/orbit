import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';

import '../constants/app_spacing.dart';
import '../widgets/app_notification_banner.dart';

class OrbitNotificationService {
  OrbitNotificationService._();

  static final OrbitNotificationService instance = OrbitNotificationService._();

  final _queue = Queue<_NotificationRequest>();
  OverlayEntry? _entry;
  Object? _owner;
  bool _drainScheduled = false;
  static const _bannerGap = Duration(milliseconds: 2500);
  Timer? _gapTimer;

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
    bool Function()? shouldShow,
  }) {
    if (!context.mounted || message.trim().isEmpty) return;

    final overlay =
        targetOverlay ?? Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null || !overlay.mounted) return;

    _queue.addLast(
      _NotificationRequest(
        context: context,
        overlay: overlay,
        name: name,
        message: message,
        avatarIndex: avatarIndex,
        imageUrl: imageUrl,
        onTap: onTap,
        duration: duration,
        owner: owner,
        shouldShow: shouldShow,
      ),
    );
    _scheduleDrain();
  }

  // Insert only after the current frame, including after a banner closes.
  void _scheduleDrain() {
    if (_drainScheduled ||
        _gapTimer != null ||
        _entry != null ||
        _queue.isEmpty) {
      return;
    }
    _drainScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _drainScheduled = false;
      _showNext();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _showNext() {
    if (_entry != null || _gapTimer != null) return;
    while (_queue.isNotEmpty) {
      final request = _queue.removeFirst();
      if (!request.context.mounted || !request.overlay.mounted) continue;
      // The chat/session may have changed while this notification waited.
      if (request.shouldShow?.call() == false) continue;
      _insert(request);
      return;
    }
  }

  void _insert(_NotificationRequest request) {
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
                  duration: request.duration,
                  onDismissed: () => _remove(entry),
                  child: OrbitNotificationBanner(
                    name: request.name,
                    message: request.message,
                    avatarIndex: request.avatarIndex,
                    imageUrl: request.imageUrl,
                    onTap: request.onTap == null
                        ? null
                        : () {
                            if (!identical(_entry, entry)) return;
                            _remove(entry);
                            request.onTap!();
                          },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    request.overlay.insert(entry);
    _entry = entry;
    _owner = request.owner;
  }

  // No owner: clear everything. With owner: remove only its banners,
  // including those that have not been displayed yet.
  void dismiss({Object? owner}) {
    if (owner == null) {
      _queue.clear();
      _gapTimer?.cancel();
      _gapTimer = null;
    } else {
      _queue.removeWhere((request) => identical(request.owner, owner));
    }
    final entry = _entry;
    if (entry != null && (owner == null || identical(owner, _owner))) {
      _remove(entry, startGap: owner != null);
    } else {
      _scheduleDrain();
    }
  }

  void _remove(OverlayEntry entry, {bool startGap = true}) {
    if (!identical(_entry, entry)) return;
    _entry = null;
    _owner = null;
    entry.remove();
    entry.dispose();
    if (startGap) {
      // Keep the gap even if the queue is currently empty: another
      // message may arrive before the cooldown finishes.
      _gapTimer?.cancel();
      _gapTimer = Timer(_bannerGap, () {
        _gapTimer = null;
        _scheduleDrain();
      });
    } else {
      _scheduleDrain();
    }
  }
}

class _NotificationRequest {
  const _NotificationRequest({
    required this.context,
    required this.overlay,
    required this.name,
    required this.message,
    required this.duration,
    this.avatarIndex,
    this.imageUrl,
    this.onTap,
    this.owner,
    this.shouldShow,
  });

  final BuildContext context;
  final OverlayState overlay;
  final String name;
  final String message;
  final Duration duration;
  final int? avatarIndex;
  final String? imageUrl;
  final VoidCallback? onTap;
  final Object? owner;
  final bool Function()? shouldShow;
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
