import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../auth/auth_gate.dart';
import '../auth/player_auth_service.dart';
import '../home_screen.dart';
import 'orbit_profile.dart';
import 'profile_setup_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.showEnterButton = false});
  final bool showEnterButton;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _months = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const _typeOptions = <String>[
    'Gentle', 'Funny', 'Loyal', 'Confident', 'Romantic',
    'Caring', 'Intelligent', 'Goal-Oriented', 'Calm', 'Ambitious',
    'Mature', 'Playful', 'Special', 'Adventurous', 'Mysterious',
    'Communicative', 'Thoughtful',
    'Smart', 'Protective', 'Good Listener', // backward compatibility
  ];

  static const _typeIcons = <String, IconData>{
    'Gentle': Icons.eco_outlined,
    'Funny': Icons.sentiment_very_satisfied_outlined,
    'Smart': Icons.school_outlined,
    'Loyal': Icons.shield_outlined,
    'Confident': Icons.workspace_premium_outlined,
    'Romantic': Icons.favorite_border_rounded,
    'Calm': Icons.spa_outlined,
    'Ambitious': Icons.trending_up_rounded,
    'Protective': Icons.verified_user_outlined,
    'Good Listener': Icons.headphones_outlined,
  };

  static const _defaultAbout =
      'An astrology-inspired archetype for your fictional persona, '
      'not a fixed personality.';

  DocumentReference<Map<String, dynamic>> _playerRef(String uid) =>
      FirebaseFirestore.instance.collection('players').doc(uid);

  String _birthday(OrbitProfile profile, Map<String, dynamic> data) {
    final month = profile.birth_month;
    if (month < 1 || month > 12) return 'Not set';

    final year = data['birth_year'];
    final date = '${_months[month - 1]} ${profile.birth_day}';
    return year is int && year > 0 ? '$date, $year' : date;
  }

  List<String> _selectedTypes(Map<String, dynamic> data) {
    final raw = data['typeOfMan'];
    if (raw is! List) return const [];

    final values = raw.whereType<String>().toSet();
    return _typeOptions.where(values.contains).toList(growable: false);
  }

  String _about(Map<String, dynamic> data) {
    final value = data['aboutYou'];
    return value is String && value.trim().isNotEmpty
        ? value.trim()
        : _defaultAbout;
  }

  Future<void> _saveFields(Map<String, dynamic> fields) async {
    const editableFields = {'aboutYou', 'typeOfMan'};
    if (fields.keys.any((key) => !editableFields.contains(key))) {
      throw StateError('Only About You and Type of Man can be edited.');
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('You must be signed in.');

    await _playerRef(uid).set({
      ...fields,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // ------------------------------------------------------------
  // EDITABLE PROFILE DATA
  // ------------------------------------------------------------
  Future<void> _editProfilePhoto() async {
    final openSetup = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          decoration: const BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(28),
            ),
            border: Border(
              top: BorderSide(color: AppColors.border),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),

              const SizedBox(height: 22),

              Row(
                children: [
                  _iconArt(
                    'ui_camera',
                    size: 36,
                    fallback: Icons.camera_alt_outlined,
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Change Profile Picture',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 4),

              const Text(
                'Update your avatar through the persona setup.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),

              const SizedBox(height: 22),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () =>
                      Navigator.pop(sheetContext, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 15,
                    ),
                  ),
                  child: const Text('Open Profile Setup'),
                ),
              ),

              const SizedBox(height: 8),

              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () =>
                      Navigator.pop(sheetContext, false),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (openSetup == true && mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const ProfileSetupScreen(),
        ),
      );
    }
  }

  Future<void> _editTypes(List<String> currentTypes) async {
    final selected = currentTypes.toSet();

    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, refresh) => SafeArea(
          top: false,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.8,
            ),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            decoration: const BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.textSecondary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Your Type of Man',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'Choose up to 6 traits. Your choices will guide future NPC matching.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Wrap(
                    spacing: 9,
                    runSpacing: 9,
                    children: [
                      for (final type in _typeOptions)
                        FilterChip(
                          avatar: _traitArt(type, size: 30),
                          label: Text(type),
                          selected: selected.contains(type),
                          showCheckmark: false,
                          backgroundColor: AppColors.cardSoft,
                          selectedColor: AppColors.primaryPurple,
                          side: BorderSide(
                            color: selected.contains(type)
                                ? AppColors.primaryPurple
                                : AppColors.border,
                          ),
                          labelStyle: TextStyle(
                            color: selected.contains(type)
                                ? Colors.white
                                : AppColors.softLilac,
                          ),
                          onSelected: (isSelected) {
                            if (isSelected && selected.length >= 6) {
                              ScaffoldMessenger.of(sheetContext).showSnackBar(
                                const SnackBar(
                                  content: Text('Choose up to 6 traits.'),
                                ),
                              );
                              return;
                            }
                            refresh(() {
                              if (isSelected) {
                                selected.add(type);
                              } else {
                                selected.remove(type);
                              }
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(
                        sheetContext,
                        _typeOptions.where(selected.contains).toList(),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      child: const Text('Save Preferences'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (result == null) return;
    try {
      await _saveFields({'typeOfMan': result});
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Preferences saved 💗')));
    } catch (error) {
      _showError('Could not save preferences: $error');
    }
  }

  Future<void> _editAbout(String currentAbout) async {
    var draft = currentAbout == _defaultAbout ? '' : currentAbout;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text(
          'About You',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: TextFormField(
          initialValue: draft,
          onChanged: (value) => draft = value,
          maxLines: 4,
          maxLength: 180,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Tell the universe about yourself...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, draft.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == null) return;
    try {
      await _saveFields({'aboutYou': result});
    } catch (error) {
      _showError('Could not save About You: $error');
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text(
          'Leaving the galaxy?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'You can always return to your universe.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Log Out',
              style: TextStyle(color: AppColors.primaryPink),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    try {
      await PlayerAuthService.instance.logout();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
            (_) => false,
      );
    } catch (error) {
      _showError('Logout failed: $error');
    }
  }

  // ------------------------------------------------------------
  // VISUAL DESIGN v3 — use the user's actual ORBIT assets.
  // ------------------------------------------------------------
  static const _assetRoot = 'lib/core/assets';
  static const _iconRoot = '$_assetRoot/icons';
  static const _glowBorder = Color(0xFFCF8ADE);
  static const _cardPurple = Color(0xFF392345);
  static const _cardNavy = Color(0xFF1B172E);
  static const _softGlow = Color(0xFFFF83D8);
  static const _fileExtensions = <String>['png', 'webp', 'jpg', 'jpeg'];

  static const Map<String, String> _traitAssetNames = <String, String>{
    'Caring': '01_caring',
    'Intelligent': '02_intelligent',
    'Goal-Oriented': '03_goal_oriented',
    'Gentle': '04_gentle',
    'Loyal': '05_loyal',
    'Funny': '06_funny',
    'Calm': '07_calm',
    'Ambitious': '08_ambitious',
    'Mature': '09_mature',
    'Playful': '10_playful',
    'Romantic': '11_romantic',
    'Special': '12_special',
    'Adventurous': '13_adventurous',
    'Mysterious': '14_mysterious',
    'Communicative': '15_communicative',
    'Thoughtful': '16_thoughtful',
    'Confident': '09_mature',
    'Smart': '02_intelligent',
    'Protective': '05_loyal',
    'Good Listener': '15_communicative',
  };

  Widget _art(
      String base, {
        double? width,
        double? height,
        BoxFit fit = BoxFit.contain,
        Alignment alignment = Alignment.center,
        Widget? fallback,
      }) {
    Widget variant(int index) {
      if (index >= _fileExtensions.length) {
        return fallback ?? const SizedBox.shrink();
      }
      return Image.asset(
        '$base.${_fileExtensions[index]}',
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        gaplessPlayback: true,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, __, ___) => variant(index + 1),
      );
    }

    return variant(0);
  }

  Widget _avatarCameraButton({
    required VoidCallback onPressed,
  }) =>
      Material(
        color: const Color(0xFF3B274C),
        shape: const CircleBorder(
          side: BorderSide(
            color: _glowBorder,
            width: 1.35,
          ),
        ),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: _iconArt(
                'ui_camera',
                size: 26,
                fallback: Icons.camera_alt_outlined,
              ),
            ),
          ),
        ),
      );

  Widget _iconArt(String filename, {double size = 30, IconData? fallback}) {
    return SizedBox.square(
      dimension: size,
      child: _art(
        '$_iconRoot/$filename',
        width: size,
        height: size,
        fit: BoxFit.contain,
        fallback: Icon(
          fallback ?? Icons.auto_awesome_outlined,
          size: size * .90,
          color: _softGlow,
        ),
      ),
    );
  }

  Widget _traitArt(String trait, {double size = 32}) => _iconArt(
    _traitAssetNames[trait] ?? '12_special',
    size: size,
    fallback: _typeIcons[trait] ?? Icons.favorite_border,
  );

  Widget _glassCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(20),
    String? backgroundArtwork,
    double artworkOpacity = .24,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(27),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_cardPurple, _cardNavy, Color(0xFF2B1B3B)],
        ),
        border: Border.all(
          color: _glowBorder.withValues(alpha: .84),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPurple.withValues(alpha: .15),
            blurRadius: 26,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          children: [
            if (backgroundArtwork != null) ...[
              Positioned.fill(
                child: Opacity(
                  opacity: artworkOpacity,
                  child: _art(
                    '$_assetRoot/$backgroundArtwork',
                    fit: BoxFit.cover,
                    alignment: Alignment.bottomCenter,
                  ),
                ),
              ),
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xB31B172E), Color(0x332B1B3B)],
                    ),
                  ),
                ),
              ),
            ],
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }

  Widget _editIcon(VoidCallback onPressed) => Material(
    color: AppColors.cardSoft.withValues(alpha: .68),
    shape: const CircleBorder(side: BorderSide(color: _glowBorder, width: 1.2)),
    child: InkWell(
      onTap: onPressed,
      customBorder: const CircleBorder(),
      child: SizedBox(
        width: 49,
        height: 49,
        child: Center(
          child: _iconArt('ui_edit', size: 28, fallback: Icons.edit_outlined),
        ),
      ),
    ),
  );

  Widget _wordmark() => SizedBox(
    width: 152,
    height: 61,
    child: _art(
      '$_assetRoot/orbit_wordmark',
      width: 152,
      height: 61,
      fit: BoxFit.contain,
      alignment: Alignment.centerLeft,
      fallback: _art(
        '$_assetRoot/orbit_logo_long',
        width: 152,
        height: 61,
        alignment: Alignment.centerLeft,
        fallback: const Text(
          'ORBIT',
          style: TextStyle(
            fontFamily: 'serif',
            fontSize: 31,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryPink,
          ),
        ),
      ),
    ),
  );

  // Identity is read-only after onboarding: no generic "Edit Profile" CTA.
  Widget _header() => Padding(
    padding: const EdgeInsets.only(top: 2, bottom: 9),
    child: Align(
      alignment: Alignment.centerLeft,
      child: _wordmark(),
    ),
  );

  Widget _defaultAvatar(OrbitProfile profile, double size) => _art(
    '$_assetRoot/player_avatar',
    fit: BoxFit.cover,
    fallback: _art(
      '$_assetRoot/bg4',
      fit: BoxFit.cover,
      alignment: const Alignment(-.32, -.78),
      fallback: ColoredBox(
        color: AppColors.primaryPurple,
        child: Center(
          child: Text(
            profile.username.isEmpty ? '?' : profile.username[0].toUpperCase(),
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: size * .4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    ),
  );


  Widget _avatar(
      OrbitProfile profile,
      Map<String, dynamic> data,
      double size,
      ) {
    final url = data['photoUrl'];
    final fallback = _defaultAvatar(profile, size);

    return SizedBox(
      width: size + 24,
      height: size + 24,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: Container(
              width: size,
              height: size,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.primaryGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryPink
                        .withValues(alpha: .42),
                    blurRadius: 23,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: ClipOval(
                child: url is String && url.trim().isNotEmpty
                    ? Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => fallback,
                )
                    : fallback,
              ),
            ),
          ),
          Positioned(
            right: 18,
            bottom: 18,
            child: _avatarCameraButton(
              onPressed: _editProfilePhoto,
            ),
          ),
        ],
      ),
    );
  }

  Widget _zodiacBadge(String zodiac) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFF31203E).withValues(alpha: .9),
      borderRadius: BorderRadius.circular(40),
      border: Border.all(color: _glowBorder),
      boxShadow: [
        BoxShadow(
          color: AppColors.primaryPink.withValues(alpha: .13),
          blurRadius: 12,
        ),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _iconArt(
          zodiac.trim().toLowerCase(), // e.g. sagittarius.png, cancer.png
          size: 38,
          fallback: Icons.nights_stay_outlined,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            zodiac,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _hero(OrbitProfile profile, Map<String, dynamic> data) =>
      LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 350;
          final avatarSize = compact ? 127.0 : 150.0;
          return SizedBox(
            height: compact ? 160 : 180,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                const Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(painter: _OrbitStarlightPainter()),
                  ),
                ),
                Positioned.fill(
                  child: Row(
                    children: [
                      _avatar(profile, data, avatarSize),
                      SizedBox(width: compact ? 10 : 15),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.username,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontFamily: 'serif',
                                fontWeight: FontWeight.w700,
                                fontSize: compact ? 27 : 32,
                                height: 1.1,
                                shadows: const [
                                  Shadow(
                                    color: Color(0xAF000000),
                                    blurRadius: 9,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 13),
                            _zodiacBadge(profile.zodiac),
                            const SizedBox(height: 12),
                            const Text(
                              'Your Cosmic Identity',
                              maxLines: 2,
                              style: TextStyle(
                                color: AppColors.softLilac,
                                fontSize: 13,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );

  Widget _fact(
      String asset,
      IconData fallbackIcon,
      String label,
      String value, {
        Color valueColor = AppColors.textPrimary,
      }) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      _iconArt(asset, size: 43, fallback: fallbackIcon),
      const SizedBox(height: 8),
      Text(
        label,
        maxLines: 2,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.softLilac, fontSize: 12.2),
      ),
      const SizedBox(height: 5),
      Text(
        value,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: valueColor,
          fontWeight: FontWeight.w700,
          fontSize: 13.6,
          height: 1.17,
        ),
      ),
    ],
  );

  Widget _facts(OrbitProfile profile, Map<String, dynamic> data,) =>
      _glassCard(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
    child: SizedBox(
      height: 112,
      child: Row(
        children: [
          Expanded(
            child: _fact(
              'ui_calendar',
              Icons.calendar_month_outlined,
              'Date of Birth',
              _birthday(profile, data),
            ),
          ),
          Container(
            width: 1,
            height: 91,
            color: _glowBorder.withValues(alpha: .65),
          ),
          Expanded(
            child: _fact(
              'ui_crescent',
              Icons.nightlight_round,
              'Zodiac',
              profile.zodiac,
              valueColor: AppColors.primaryPink,
            ),
          ),
          Container(
            width: 1,
            height: 91,
            color: _glowBorder.withValues(alpha: .65),
          ),
          Expanded(
            child: _fact(
              'saturn_planet',
              Icons.public_outlined,
              'Origin Sector',
              profile.origin_sector,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _sectionTitle({
    required String title,
    required String icon,
    required VoidCallback onEdit,
  }) => Row(
    children: [
      _iconArt(icon, size: 39, fallback: Icons.auto_awesome),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'serif',
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      const SizedBox(width: 6),
      _editIcon(onEdit),
    ],
  );

  Widget _aboutCard(String about) => _glassCard(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 13),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          title: 'About You',
          icon: 'sparkles',
          onEdit: () => _editAbout(about),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 285;
            final imageWidth = compact ? 97.0 : constraints.maxWidth * .43;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: imageWidth,
                  height: 100,
                  child: _art(
                    '$_assetRoot/orbit_cosmic_details_planet',
                    fit: BoxFit.contain,
                    fallback: _iconArt('saturn_planet', size: 77),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 1,
                  height: 104,
                  color: _glowBorder.withValues(alpha: .8),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    about,
                    style: TextStyle(
                      color: AppColors.softLilac,
                      fontSize: compact ? 12 : 13,
                      height: 1.44,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    ),
  );

  Widget _traitChip(String trait) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: const Color(0xFF34243F).withValues(alpha: .9),
      borderRadius: BorderRadius.circular(36),
      border: Border.all(color: const Color(0xFFE09DDC)),
      boxShadow: [
        BoxShadow(
          color: AppColors.primaryPink.withValues(alpha: .13),
          blurRadius: 12,
        ),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _traitArt(trait, size: 32),
        const SizedBox(width: 7),
        Text(
          trait,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12.7,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );

  Widget _typeCard(List<String> selected) => _glassCard(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
    backgroundArtwork: 'bg2',
    artworkOpacity: .34,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          title: 'Your Type of Man',
          icon: '11_romantic',
          onEdit: () => _editTypes(selected),
        ),
        const SizedBox(height: 7),
        const Text(
          'These preferences will help match you with compatible NPCs.',
          style: TextStyle(
            color: AppColors.softLilac,
            fontSize: 12.5,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        if (selected.isEmpty)
          TextButton.icon(
            onPressed: () => _editTypes(selected),
            icon: _iconArt('ui_add', size: 31, fallback: Icons.add_circle_outline),
            label: const Text('Choose your favorite traits'),
          )
        else
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 11,
              children: [for (final trait in selected) _traitChip(trait)],
            ),
          ),
      ],
    ),
  );

  Widget _profileBody(OrbitProfile profile, Map<String, dynamic> data) {
    final about = _about(data);
    final selected = _selectedTypes(data);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 34),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 550),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(),
              const SizedBox(height: 0),
              _hero(profile, data),
              const SizedBox(height: 4),
              _facts(profile, data),
              const SizedBox(height: 12),
              _aboutCard(about),
              const SizedBox(height: 12),
              _typeCard(selected),
              const SizedBox(height: 20),
              if (widget.showEnterButton)
                Container(
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(27),
                  ),
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const HomeScreen()),
                          (_) => false,
                    ),
                    child: const Text(
                      'Enter ORBIT Universe  →',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                )
              else
                OutlinedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Log Out'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryPink,
                    side: const BorderSide(color: AppColors.primaryPink),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // FIRESTORE REALTIME PROFILE
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: Text('Please sign in.')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: _art(
              '$_assetRoot/bg3',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              fallback: const ColoredBox(color: AppColors.background),
            ),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xCE0B0914),
                    Color(0xBA0B0914),
                    Color(0xEA0B0914),
                  ],
                  stops: [0, .48, 1],
                ),
              ),
            ),
          ),
          SafeArea(
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _playerRef(uid).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      'Could not load your profile.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryPink,
                    ),
                  );
                }
                final data = snapshot.data!.data();
                if (data == null) {
                  return Center(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => const ProfileSetupScreen(),
                        ),
                      ),
                      child: const Text('Create Your Persona'),
                    ),
                  );
                }
                try {
                  final profile = OrbitProfile.fromJson({
                    ...data,
                    'gender': data['gender'] ?? '',
                  });
                  return _profileBody(profile, data);
                } catch (error) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Invalid player profile: $error',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Decorative orbit trajectory and stars; illustration still uses real assets.
class _OrbitStarlightPainter extends CustomPainter {
  const _OrbitStarlightPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final orbit = Paint()
      ..color = const Color(0x96DD84FB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.save();
    canvas.translate(size.width * .53, size.height * .54);
    canvas.rotate(-.19);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: size.width * 1.22,
        height: size.height * .87,
      ),
      orbit,
    );
    canvas.restore();

    final star = Paint()..color = const Color(0xFFFFA6E1);
    const stars = <Offset>[
      Offset(.03, .21),
      Offset(.29, .1),
      Offset(.52, .23),
      Offset(.73, .12),
      Offset(.94, .42),
      Offset(.14, .84),
      Offset(.61, .88),
      Offset(.87, .79),
    ];
    for (final point in stars) {
      final center = Offset(size.width * point.dx, size.height * point.dy);
      canvas.drawCircle(center, 1.4, star);
      canvas.drawLine(center.translate(-4, 0), center.translate(4, 0), star);
      canvas.drawLine(center.translate(0, -4), center.translate(0, 4), star);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
