
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../chat/chat_screen.dart';
import 'match_service.dart';
import 'npc_persona.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen>
    with SingleTickerProviderStateMixin {
  final _generator = NpcGenerator();
  late final List<NpcPersona> _deck;
  late final AnimationController _swipeController;

  Animation<Offset> _motion = const AlwaysStoppedAnimation(Offset.zero);
  Offset _drag = Offset.zero;
  bool _busy = false;

  static const double _swipeThreshold = 95;

  static const _avatarPalettes = <List<Color>>[
    [Color(0xFF9B4DCA), Color(0xFF20113D)],
    [Color(0xFF275B9B), Color(0xFF0D1837)],
    [Color(0xFFAD407C), Color(0xFF35122F)],
    [Color(0xFF457E85), Color(0xFF102C3D)],
    [Color(0xFF7C59CD), Color(0xFF261344)],
    [Color(0xFF9D6278), Color(0xFF301E42)],
  ];

  @override
  void initState() {
    super.initState();
    _deck = _generator.generateBatch(10);
    _swipeController = AnimationController(vsync: this)
      ..addListener(() {
        if (mounted) setState(() => _drag = _motion.value);
      });
  }

  @override
  void dispose() {
    _swipeController.dispose();
    super.dispose();
  }

  // One animation function for flying away and returning to center.
  Future<void> _animateCard(
      Offset target, {
        required Duration duration,
        required Curve curve,
      }) async {
    _swipeController.duration = duration;
    _motion = Tween<Offset>(begin: _drag, end: target).animate(
      CurvedAnimation(parent: _swipeController, curve: curve),
    );
    await _swipeController.forward(from: 0);
    _motion = AlwaysStoppedAnimation(_drag);
    _swipeController.reset();
  }

  void _nextNpc() {
    setState(() {
      _deck.removeAt(0);
      _deck.add(_generator.generate());
      _drag = Offset.zero;
    });
  }

  Future<void> _choose({required bool liked}) async {
    if (_busy || _deck.isEmpty) return;

    final npc = _deck.first;
    setState(() => _busy = true);

    try {
      // Passing needs no database request; only Likes can match.
      final MatchOutcome? outcome =
      liked ? await MatchService.instance.tryMatch(npc) : null;
      if (!mounted) return;

      final screenWidth = MediaQuery.sizeOf(context).width;
      await _animateCard(
        Offset(liked ? screenWidth * 1.45 : -screenWidth * 1.45, -30),
        duration: const Duration(milliseconds: 290),
        curve: Curves.easeInCubic,
      );
      if (!mounted) return;

      _nextNpc();

      if (outcome?.isMatch == true) {
        await _showMatch(npc, outcome!);
      }
    } catch (error) {
      if (!mounted) return;
      await _animateCard(
        Offset.zero,
        duration: const Duration(milliseconds: 190),
        curve: Curves.easeOut,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to process swipe: $error')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetCard() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _animateCard(
        Offset.zero,
        duration: const Duration(milliseconds: 230),
        curve: Curves.easeOutCubic,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _onDragEnd(DragEndDetails details) {
    if (_busy) return;
    final speed = details.primaryVelocity ?? 0;
    if (_drag.dx.abs() >= _swipeThreshold ||
        (_drag.dx.abs() > 35 && speed.abs() > 800)) {
      _choose(liked: _drag.dx > 0);
    } else {
      _resetCard();
    }
  }

  Future<void> _showMatch(NpcPersona npc, MatchOutcome result) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: const Color(0xFF201331),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: const BorderSide(color: AppColors.primaryPurple),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.favorite_rounded,
                color: AppColors.primaryPink,
                size: 66,
              ),
              const SizedBox(height: 12),
              const Text(
                "IT'S A MATCH! ✦",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'You and ${npc.name} like each other!',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.softLilac),
              ),
              const SizedBox(height: 6),
              Text(
                npc.archetype.name,
                style: const TextStyle(color: AppColors.primaryPink),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0x882A2340),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      result.npcStarts
                          ? '${npc.name} messaged you first! 💌'
                          : '${npc.name} is waiting for your hello 💜',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.softLilac,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (result.firstMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        '"${result.firstMessage}"',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 23),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ChatScreen(npcId: npc.id),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(16),
                  ),
                  child: const Text('Start Chat 💬'),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text(
                  'Keep Swiping',
                  style: TextStyle(color: AppColors.softLilac),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _traitChip(NpcTrait trait) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.primaryPurple.withAlpha(65),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.softLilac.withAlpha(75),
        ),
      ),
      child: Text(
        trait.label,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // Temporary silhouette; replace this with each NPC's avatar asset later.
  Widget _portrait(NpcPersona npc) {
    final palette =
    _avatarPalettes[npc.avatarIndex % _avatarPalettes.length];

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: palette,
            ),
          ),
        ),
        Positioned(
          top: -75,
          right: -75,
          child: Container(
            width: 290,
            height: 290,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.softLilac.withAlpha(95),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryPink.withAlpha(55),
                  blurRadius: 90,
                  spreadRadius: 4,
                ),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 85,
          left: -90,
          child: Container(
            width: 245,
            height: 245,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primaryPink.withAlpha(110),
              ),
            ),
          ),
        ),
        Center(
          child: Icon(
            npc.species == 'Android'
                ? Icons.smart_toy_rounded
                : Icons.person_rounded,
            size: 215,
            color: AppColors.softLilac.withAlpha(185),
          ),
        ),
        const Positioned(
          top: 70,
          right: 30,
          child: Icon(
            Icons.auto_awesome,
            color: AppColors.softLilac,
            size: 24,
          ),
        ),
      ],
    );
  }

  Widget _npcCard(NpcPersona npc) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF19112E),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: AppColors.softLilac.withAlpha(100),
              width: 1.2,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _portrait(npc),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.0, 0.35, 0.70, 1.0],
                    colors: [
                      Color(0x000F0921),
                      Color(0x000F0921),
                      Color(0xB50F0921),
                      Color(0xFA0F0921),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 18,
                left: 18,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x99130D28),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: AppColors.softLilac.withAlpha(90),
                    ),
                  ),
                  child: Text(
                    '✦ ${npc.species}',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${npc.name}, ${npc.age}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 29,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      npc.archetype.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.primaryPink,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      npc.bio,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 13),
                    Wrap(
                      spacing: 7,
                      runSpacing: 6,
                      children: npc.traits.take(3).map(_traitChip).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Background cards only need a portrait, not three expensive blur layers.
  Widget _backCard(NpcPersona npc) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: AppColors.primaryPink.withAlpha(95),
            width: 2,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _portrait(npc),
            const ColoredBox(color: Color(0x44120A25)),
          ],
        ),
      ),
    );
  }

  // Stack next NPCs behind the current NPC, like a physical deck.
  Widget _buildDeck() {
    final double progress =
    (_drag.dx.abs() / 190).clamp(0.0, 1.0).toDouble();
    final npc = _deck.first;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          if (_deck.length > 2)
            Transform.translate(
              offset: const Offset(-15, 10),
              child: Transform.rotate(
                angle: -0.075,
                child: Transform.scale(
                  scale: 0.92,
                  child: _backCard(_deck[2]),
                ),
              ),
            ),
          if (_deck.length > 1)
            Transform.translate(
              offset: Offset(16 * (1 - progress), 5 * (1 - progress)),
              child: Transform.rotate(
                angle: 0.055 * (1 - progress),
                child: Transform.scale(
                  scale: 0.955 + (0.045 * progress),
                  child: _backCard(_deck[1]),
                ),
              ),
            ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: _busy
                ? null
                : (details) {
              setState(() {
                _drag = Offset(
                  _drag.dx + details.delta.dx,
                  (_drag.dy + details.delta.dy)
                      .clamp(-55.0, 55.0)
                      .toDouble(),
                );
              });
            },
            onHorizontalDragEnd: _onDragEnd,
            child: Transform.translate(
              offset: _drag,
              child: Transform.rotate(
                angle: _drag.dx / 1050,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _npcCard(npc),
                    if (_drag.dx.abs() > 25)
                      Positioned(
                        top: 58,
                        left: _drag.dx > 0 ? 22 : null,
                        right: _drag.dx < 0 ? 22 : null,
                        child: Opacity(
                          opacity: progress,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xCC160E2B),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _drag.dx > 0
                                    ? AppColors.primaryPink
                                    : AppColors.danger,
                                width: 2,
                              ),
                            ),
                            child: Text(
                              _drag.dx > 0 ? 'LIKE 💗' : 'PASS ✕',
                              style: TextStyle(
                                color: _drag.dx > 0
                                    ? AppColors.primaryPink
                                    : AppColors.danger,
                                fontSize: 21,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (_busy)
            const Positioned(
              top: 8,
              right: 8,
              child: IgnorePointer(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primaryPink,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _actionButton({required bool liked}) {
    final color = liked ? AppColors.primaryPink : AppColors.softLilac;
    final size = liked ? 76.0 : 62.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(size / 2),
            onTap: _busy ? null : () => _choose(liked: liked),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: liked ? null : const Color(0xFF1A102D),
                gradient: liked ? AppColors.primaryGradient : null,
                border: Border.all(
                  color: liked ? AppColors.primaryPink : AppColors.border,
                  width: 1.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withAlpha(liked ? 115 : 25),
                    blurRadius: liked ? 26 : 10,
                    spreadRadius: liked ? 3 : 0,
                  ),
                ],
              ),
              child: Icon(
                liked ? Icons.favorite_rounded : Icons.close_rounded,
                color: liked ? Colors.white : color,
                size: liked ? 36 : 29,
              ),
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          liked ? 'Like' : 'Pass',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'lib/core/assets/bg.jpg',
              fit: BoxFit.cover,
            ),
          ),
          const Positioned.fill(
            child: ColoredBox(color: Color(0xB8090718)),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
                  child: Column(
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            color: AppColors.primaryPink,
                            size: 27,
                          ),
                          SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'For You',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 25,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Someone new is in your orbit.',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.auto_awesome,
                            color: AppColors.softLilac,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Expanded(child: _buildDeck()),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _actionButton(liked: false),
                          const SizedBox(width: 46),
                          _actionButton(liked: true),
                        ],
                      ),
                      const SizedBox(height: 7),
                      const Text(
                        'Swipe left to pass · Right to like',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
