import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/app_icon_button.dart';
import '../../core/constants/app_radius.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_avatar.dart';
import '../../core/widgets/app_button.dart';
import '../../core/services/orbit_notification_service.dart';

import '../chat/chat_screen.dart';

import 'match_service.dart';

import '../npc/npc_persona.dart';
import '../npc/npc_profile_generator.dart';
import '../npc/npc_avatar_widget.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key, this.locationLabel});

  // Optional: connect the actual NPC world/origin field from your data model.
  // If not supplied, the location is hidden rather than invented.
  final String? Function(NpcPersona npc)? locationLabel;

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen>
    with SingleTickerProviderStateMixin {
  final _generator = NpcProfileGenerator();
  late final List<NpcPersona> _deck;
  late final AnimationController _swipeController;

  Animation<Offset> _motion = const AlwaysStoppedAnimation(Offset.zero);
  Offset _drag = Offset.zero;
  bool _busy = false;

  static const double _swipeThreshold = 95;

  static const _muted = Color(0xFFC9C3D3);
  static const _outline = Color(0xFF62576F);

  // This is a preference, not an exclusive filter: other species can appear
  // when none of the preferred species are in the generated deck.
  String? _preferredSpecies;

  static const _avatarPalettes = <Color>[
    Color(0xFF66547D),
    Color(0xFF425776),
    Color(0xFF76506D),
    Color(0xFF42636B),
    Color(0xFF675783),
    Color(0xFF72596C),
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
    _motion = _swipeController.drive(
      Tween<Offset>(begin: _drag, end: target).chain(CurveTween(curve: curve)),
    );
    try {
      await _swipeController.forward(from: 0).orCancel;
    } on TickerCanceled {
      return;
    }
    if (!mounted) return;
    _motion = AlwaysStoppedAnimation(_drag);
    _swipeController.reset();
  }

  void _nextNpc() {
    setState(() {
      _deck.removeAt(0);
      _deck.add(_generator.generate());
      _prioritizeSpecies();
      _drag = Offset.zero;
    });
  }

  Future<void> _choose({required bool liked}) async {
    if (_busy || _deck.isEmpty) return;

    final npc = _deck.first;
    setState(() => _busy = true);

    try {
      // Passing needs no database request; only Likes can match.
      final MatchOutcome? outcome = liked
          ? await MatchService.instance.tryMatch(npc)
          : null;
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
    final firstMessage = result.firstMessage;
    final notificationService = OrbitNotificationService.instance;
    final notificationOwner = Object();
    bool notificationScheduled = false;
    bool notificationShown = false;

    final startChat = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        if (!notificationScheduled &&
            result.npcStarts &&
            firstMessage != null &&
            firstMessage.trim().isNotEmpty) {
          notificationScheduled = true;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !dialogContext.mounted) return;
            if (ModalRoute.of(dialogContext)?.isCurrent != true) return;

            notificationService.show(
              dialogContext,
              owner: notificationOwner,
              name: npc.name,
              message: firstMessage,
              avatarIndex: npc.avatarIndex,
              onTap: () {
                if (!dialogContext.mounted) return;
                if (ModalRoute.of(dialogContext)?.isCurrent == true) {
                  Navigator.pop(dialogContext, true);
                }
              },
            );
            notificationShown = true;
          });
        }

        return Dialog(
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.dialog),
            side: const BorderSide(color: AppColors.border),
          ),

          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xxl),

            child: Column(
              mainAxisSize: MainAxisSize.min,

              children: [
                // CONNECTION LABEL
                const Text(
                  '✧  A NEW CONNECTION  ✧',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.overline,
                ),

                const SizedBox(height: AppSpacing.xxl),

                // NPC PROFILE PICTURE
                OrbitAvatar(
                  name: npc.name,
                  avatarIndex: npc.avatarIndex,
                  size: 128,
                  highlighted: true,
                ),

                const SizedBox(height: AppSpacing.xl),

                // MATCH TITLE
                Text(
                  "It's a match.",
                  textAlign: TextAlign.center,
                  style: AppTextStyles.editorial.copyWith(fontSize: 30),
                ),

                const SizedBox(height: AppSpacing.md),

                // NPC NAME & AGE
                Text(
                  '${npc.name}, ${npc.age}',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.heading2,
                ),

                const SizedBox(height: AppSpacing.xs),

                // NPC CAREER & SPECIES
                Text(
                  '${npc.career} · ${npc.species}',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMuted,
                ),

                const SizedBox(height: AppSpacing.xl),

                // SIGNATURE STAR DIVIDER
                const Row(
                  children: [
                    Expanded(
                      child: Divider(color: AppColors.border, height: 1),
                    ),

                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      child: Text(
                        '✧',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 16,
                        ),
                      ),
                    ),

                    Expanded(
                      child: Divider(color: AppColors.border, height: 1),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.xl),

                // START CHAT
                OrbitButton(
                  label: 'Start Chat',
                  icon: Icons.chat_bubble_outline_rounded,
                  fullWidth: true,
                  onPressed: () {
                    Navigator.pop(dialogContext, true);
                  },
                ),

                const SizedBox(height: AppSpacing.xs),

                // KEEP SWIPING
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, false);
                  },
                  child: const Text(
                    'Keep Swiping',
                    style: AppTextStyles.bodyMuted,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (notificationShown) {
      notificationService.dismiss(owner: notificationOwner);
    }

    // CHAT NAVIGATION
    if (!mounted || startChat != true) return;

    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => ChatScreen(npcId: npc.id)));
  }

  // DISCOVER PREFERENCES & DETAILS
  String? _location(NpcPersona npc) {
    final value = widget.locationLabel?.call(npc)?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  void _prioritizeSpecies() {
    final preferred = _preferredSpecies;
    if (preferred == null) return;

    final matching = _deck.where((npc) => npc.species == preferred).toList();

    final others = _deck.where((npc) => npc.species != preferred).toList();

    _deck
      ..clear()
      ..addAll(matching)
      ..addAll(others);
  }

  Future<void> _showFilters() async {
    if (_busy) return;
    final species = <String>{
      ?_preferredSpecies,
      ..._deck.map((npc) => npc.species),
    }.toList()..sort();

    // Empty string represents Any species; null represents dismissal.
    final selection = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * .65,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              const Text(
                'Discover preferences',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 23,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Prioritize a species from your current deck. Other species may still appear.',
                style: TextStyle(color: _muted, height: 1.4),
              ),
              const SizedBox(height: 12),
              for (final option in ['', ...species])
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    option.isEmpty ? 'Any species' : option,
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                  trailing: Icon(
                    (_preferredSpecies ?? '') == option
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked,
                    color: (_preferredSpecies ?? '') == option
                        ? AppColors.primary
                        : _muted,
                  ),
                  onTap: () => Navigator.pop(sheetContext, option),
                ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || selection == null || _busy) return;
    setState(() {
      _preferredSpecies = selection.isEmpty ? null : selection;
      _prioritizeSpecies();
    });
  }

  Future<void> _showProfile(NpcPersona npc) async {
    if (_busy) return;
    final location = _location(npc);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * .75,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _speciesBadge(npc),
                const SizedBox(height: 14),
                Text(
                  '${npc.name}, ${npc.age}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 30,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                _profileMeta(npc, location),
                const SizedBox(height: 24),
                const Text(
                  'About',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  npc.bio,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Personality',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: npc.traits.map(_traitChip).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Discover',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 32,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -.8,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Discover preferences',
              onPressed: _busy ? null : _showFilters,
              color: _preferredSpecies == null ? _muted : AppColors.primary,
              iconSize: 28,
              icon: const Icon(Icons.tune_rounded),
            ),
          ],
        ),
        const SizedBox(height: 9),
        const Row(
          children: [
            Text(
              'FOR YOU',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 4,
              ),
            ),
            SizedBox(width: 14),
            Expanded(child: Divider(color: Color(0xFF514659), thickness: .8)),
          ],
        ),
      ],
    );
  }

  Widget _traitChip(NpcTrait trait) => OrbitChip(label: trait.label);

  Widget _speciesBadge(NpcPersona npc) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xE6221D30),
        border: Border.all(color: const Color(0xFFAA87CE)),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            color: AppColors.textPrimary,
            size: 14,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              npc.species,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _careerIcon(String career) {
    if (career.toLowerCase().contains('pilot')) return Icons.flight_rounded;
    return Icons.work_outline_rounded;
  }

  Widget _profileMeta(NpcPersona npc, String? location) {
    return Row(
      children: [
        Icon(_careerIcon(npc.career), color: AppColors.primary, size: 16),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            npc.career,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _muted, fontSize: 13),
          ),
        ),
        if (location != null) ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 9),
            child: Text('·', style: TextStyle(color: _muted)),
          ),
          const Icon(Icons.public_rounded, color: AppColors.primary, size: 16),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              location,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _muted, fontSize: 13),
            ),
          ),
        ],
      ],
    );
  }

  Widget _portrait(NpcPersona npc) {
    final tint = _avatarPalettes[npc.avatarIndex % _avatarPalettes.length];
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: _NebulaPainter(tint)),
        LayoutBuilder(
          builder: (context, constraints) {
            // Adjust these two numbers if your transparent PNGs have padding.
            final portraitWidth = math.min(
              constraints.maxWidth * 1.10,
              constraints.maxHeight * .96,
            );
            final portraitHeight = portraitWidth * (1402 / 1122);
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: 5,
                  left: (constraints.maxWidth - portraitWidth) / 2,
                  width: portraitWidth,
                  height: portraitHeight,
                  child: NpcAvatarWidget(
                    key: ValueKey('npc-avatar-${npc.id}'),
                    avatarIndex: npc.avatarIndex,
                    width: portraitWidth,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _npcCard(NpcPersona npc, {bool interactive = true}) {
    final radius = BorderRadius.circular(27);
    return ClipRRect(
      borderRadius: radius,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _portrait(npc),
          // Only one fade; the face remains clear and the lower torso blends
          // into the information area instead of fading twice.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, .44, .60, .76, .90, 1],
                colors: [
                  Color(0x001B1924),
                  Color(0x001B1924),
                  Color(0x401B1924),
                  Color(0xEB1B1924),
                  AppColors.surface,
                  AppColors.surface,
                ],
              ),
            ),
          ),
          Positioned(
            top: 14,
            left: 16,
            right: 16,
            child: Align(
              alignment: Alignment.topLeft,
              child: _speciesBadge(npc),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 19,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${npc.name}, ${npc.age}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -.6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: 'View profile',
                      visualDensity: VisualDensity.compact,
                      onPressed: interactive && !_busy
                          ? () => _showProfile(npc)
                          : null,
                      color: _muted,
                      icon: const Icon(Icons.info_outline_rounded, size: 24),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                _profileMeta(npc, _location(npc)),
                const SizedBox(height: 12),
                Text(
                  npc.bio,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                if (npc.traits.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: npc.traits.take(2).map(_traitChip).toList(),
                  ),
                ],
              ],
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(color: _outline, width: 1),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Keep the next card underneath, at exactly the same position.
  // No visible stack of rotated cards when the user is idle.
  Widget _buildDeck() {
    final progress = (_drag.dx.abs() / 190).clamp(0.0, 1.0).toDouble();
    final npc = _deck.first;
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        if (_deck.length > 1)
          RepaintBoundary(
            child: IgnorePointer(child: _npcCard(_deck[1], interactive: false)),
          ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: _busy
              ? null
              : (details) {
                  setState(
                    () => _drag = Offset(
                      _drag.dx + details.delta.dx,
                      (_drag.dy + details.delta.dy)
                          .clamp(-55.0, 55.0)
                          .toDouble(),
                    ),
                  );
                },
          onHorizontalDragEnd: _busy ? null : _onDragEnd,
          onHorizontalDragCancel: _busy
              ? null
              : () {
                  _resetCard();
                },
          child: Transform.translate(
            offset: _drag,
            child: Transform.rotate(
              angle: _drag.dx / 1050,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  RepaintBoundary(child: _npcCard(npc)),
                  if (_drag.dx.abs() > 25)
                    Positioned(
                      top: 64,
                      left: _drag.dx > 0 ? 18 : null,
                      right: _drag.dx < 0 ? 18 : null,
                      child: Opacity(
                        opacity: progress,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _drag.dx > 0
                                  ? AppColors.primary
                                  : AppColors.danger,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            _drag.dx > 0 ? 'LIKE' : 'PASS',
                            style: TextStyle(
                              color: _drag.dx > 0
                                  ? AppColors.primary
                                  : AppColors.danger,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
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
            top: 14,
            right: 14,
            child: IgnorePointer(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _actionButton({required bool liked, required double size}) {
    return OrbitIconButton(
      icon: liked ? Icons.favorite_rounded : Icons.close_rounded,
      variant: liked
          ? OrbitIconButtonVariant.primary
          : OrbitIconButtonVariant.secondary,
      size: size,
      iconSize: size * .45,
      tooltip: liked ? 'Like' : 'Pass',
      onTap: _busy ? null : () => _choose(liked: liked),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The global galaxy background is supplied by main.dart.
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final horizontal = (constraints.maxWidth * .08)
                    .clamp(18.0, 36.0)
                    .toDouble();
                final cardWidth = constraints.maxWidth - horizontal * 2;
                final buttonSize = (cardWidth * .196)
                    .clamp(52.0, 72.0)
                    .toDouble();
                final available = constraints.maxHeight - (170 + buttonSize);

                final cardHeight = math.min(
                  cardWidth * 1.75,
                  math.max(320.0, available),
                );

                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _header(),
                      const SizedBox(height: 20),
                      SizedBox(height: cardHeight, child: _buildDeck()),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _actionButton(liked: false, size: buttonSize),
                          SizedBox(width: cardWidth * .095),
                          _actionButton(liked: true, size: buttonSize),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// Per-avatar muted nebula: layered radial glows and stable star positions.
class _NebulaPainter extends CustomPainter {
  const _NebulaPainter(this.tint);
  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Color.lerp(tint, const Color(0xFF24212D), .36)!,
            const Color(0xFF242230),
            const Color(0xFF30263D),
          ],
        ).createShader(rect),
    );
    void cloud(double x, double y, double r, Color color) {
      final bounds = Rect.fromCircle(
        center: Offset(size.width * x, size.height * y),
        radius: size.width * r,
      );
      canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(colors: [color, color.withAlpha(0)])
              .createShader(bounds),
      );
    }

    cloud(.16, .49, .62, tint.withAlpha(160));
    cloud(.88, .27, .50, tint.withAlpha(85));
    cloud(.64, .55, .35, const Color(0x427E639A));
    final random = math.Random(41);
    final paint = Paint();
    for (var i = 0; i < 48; i++) {
      final dx = random.nextDouble() * size.width;
      final dy = random.nextDouble() * size.height * .72;
      paint.color = const Color(0xFFE4D4F5).withAlpha(15 + random.nextInt(55));
      canvas.drawCircle(Offset(dx, dy), .35 + random.nextDouble() * .75, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _NebulaPainter oldDelegate) =>
      oldDelegate.tint != tint;
}
