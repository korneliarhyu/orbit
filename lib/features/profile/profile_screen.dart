import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../auth/auth_gate.dart';
import '../auth/player_auth_service.dart';
import '../home_screen.dart';
import 'orbit_profile.dart';
import 'profile_setup_screen.dart';

/// ORBIT player profile.
///
/// Visual artwork is loaded from PNG files; editable content stays in Firestore.
/// Compatible with older player documents that still contain `gender` and do
/// not contain `birth_year`, `aboutYou`, or `typeOfMan`.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.showEnterButton = false});

  final bool showEnterButton;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const String _wordmarkAsset = 'lib/core/assets/orbit_wordmark.png';
  static const _heroAsset =
      'lib/core/assets/orbit_profile_hero_background.png';
  static const _planetAsset =
      'lib/core/assets/orbit_cosmic_details_planet.png';
  static const _avatarAsset = 'lib/core/assets/player_avatar.png';

  static const _months = <String>[
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  static const _zodiacSymbols = <String, String>{
    'Aries': '♈', 'Taurus': '♉', 'Gemini': '♊', 'Cancer': '♋',
    'Leo': '♌', 'Virgo': '♍', 'Libra': '♎', 'Scorpio': '♏',
    'Sagittarius': '♐', 'Capricorn': '♑', 'Aquarius': '♒', 'Pisces': '♓',
  };

  static const _typeOptions = <String>[
    'Gentle', 'Funny', 'Smart', 'Loyal', 'Calm',
    'Ambitious', 'Protective', 'Good Listener',
  ];

  static const _typeIcons = <String, IconData>{
    'Gentle': Icons.favorite_border_rounded,
    'Funny': Icons.sentiment_very_satisfied_outlined,
    'Smart': Icons.school_outlined,
    'Loyal': Icons.shield_outlined,
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
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('You must be signed in.');

    await _playerRef(uid).set({
      ...fields,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // ------------------------------------------------------------
  // EDITABLE PROFILE DATA
  // ------------------------------------------------------------

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
                          avatar: Icon(
                            _typeIcons[type],
                            size: 18,
                            color: selected.contains(type)
                                ? Colors.white
                                : AppColors.primaryPink,
                          ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preferences saved 💗')),
      );
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
  // VISUAL COMPONENTS
  // ------------------------------------------------------------

  Widget _card({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: AppColors.card.withAlpha(244),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFF55416E)),
    ),
    child: child,
  );

  Widget _editButton(VoidCallback onPressed) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: const Icon(Icons.edit_outlined, size: 15),
    label: const Text('Edit'),
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.softLilac,
      side: const BorderSide(color: AppColors.primaryPurple),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      shape: const StadiumBorder(),
    ),
  );

  Widget _sectionTitle(String title, IconData icon, {Widget? action}) => Row(
    children: [
      Icon(icon, color: AppColors.primaryPink, size: 22),
      const SizedBox(width: 9),
      Expanded(
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      if (action != null) action,
    ],
  );

  // Reuse the official ORBIT wordmark instead of spaced-out text.
  // This is a dedicated, tightly cropped asset for a compact header.

  Widget _wordmark() => Center(
    child: SizedBox(
      width: 170,
      height: 50,
      child: Image.asset(
        _wordmarkAsset,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('ORBIT WORDMARK ERROR: $error');
          debugPrint('Asset path: $_wordmarkAsset');

          return const Center(
            child: Icon(
              Icons.broken_image_outlined,
              color: AppColors.danger,
            ),
          );
        },
      ),
    ),
  );


  Widget _avatar(String username, double size) => Container(
    width: size,
    height: size,
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: AppColors.primaryGradient,
      boxShadow: [
        BoxShadow(
          color: AppColors.primaryPink.withAlpha(56),
          blurRadius: 24,
          spreadRadius: 1,
        ),
      ],
    ),
    child: ClipOval(
      child: Image.asset(
        _avatarAsset,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          alignment: Alignment.center,
          color: AppColors.primaryPurple,
          child: Text(
            username.isEmpty ? '?' : username[0].toUpperCase(),
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.43,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    ),
  );

  Widget _hero(OrbitProfile profile) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 335;
      final avatarSize = compact ? 108.0 : 126.0;

      return ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          height: 194,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                _heroAsset,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                errorBuilder: (context, error, stackTrace) =>
                const ColoredBox(color: AppColors.background),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0x990B0914)],
                    stops: [0.54, 1],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 13),
                child: Row(
                  children: [
                    _avatar(profile.username, avatarSize),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            profile.username,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: compact ? 23 : 27,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 9),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.cardSoft,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: AppColors.primaryPurple,
                              ),
                            ),
                            child: Text(
                              '${_zodiacSymbols[profile.zodiac] ?? '✦'}  ${profile.zodiac}',
                              style: const TextStyle(
                                color: AppColors.softLilac,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Your Cosmic Identity',
                            style: TextStyle(
                              color: AppColors.softLilac,
                              fontSize: 12,
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
        ),
      );
    },
  );

  Widget _fact(IconData icon, String label, String value,
      {Color valueColor = AppColors.textPrimary}) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(icon, size: 21, color: AppColors.softLilac),
      const SizedBox(height: 7),
      Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 11,
        ),
      ),
      const SizedBox(height: 5),
      Text(
        value,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: valueColor,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );

  Widget _facts(OrbitProfile profile, Map<String, dynamic> data) => _card(
    child: SizedBox(
      height: 92,
      child: Row(
        children: [
          Expanded(
            child: _fact(
              Icons.calendar_month_outlined,
              'Date of Birth',
              _birthday(profile, data),
            ),
          ),
          const SizedBox(
            height: 68,
            child: VerticalDivider(color: AppColors.border),
          ),
          Expanded(
            child: _fact(
              Icons.nights_stay_outlined,
              'Zodiac',
              profile.zodiac,
              valueColor: AppColors.primaryPink,
            ),
          ),
          const SizedBox(
            height: 68,
            child: VerticalDivider(color: AppColors.border),
          ),
          Expanded(
            child: _fact(
              Icons.public_outlined,
              'Origin Sector',
              profile.origin_sector,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _cosmicDetails(String about) => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          'Cosmic Details',
          Icons.auto_awesome_rounded,
          action: _editButton(() => _editAbout(about)),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final artWidth = constraints.maxWidth < 280 ? 100.0 : 134.0;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Use the actual 2D illustration asset. Do not draw
                // the ringed planet/clouds manually.
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    _planetAsset,
                    width: artWidth,
                    height: 115,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => SizedBox(
                      width: artWidth,
                      height: 115,
                      child: const Icon(
                        Icons.public,
                        color: AppColors.primaryPurple,
                        size: 62,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(width: 1, height: 100, color: const Color(0xFF55416E)),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'About You',
                        style: TextStyle(
                          color: AppColors.softLilac,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        about,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ],
    ),
  );

  Widget _typeCard(List<String> selected) => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          'Your Type of Man',
          Icons.favorite_rounded,
          action: _editButton(() => _editTypes(selected)),
        ),
        const SizedBox(height: 11),
        const Text(
          'These preferences will help match you with compatible NPCs.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 18),
        if (selected.isEmpty)
          TextButton.icon(
            onPressed: () => _editTypes(selected),
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Choose your favorite traits'),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 9,
            children: [
              for (final type in selected)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.cardSoft,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _typeIcons[type],
                        size: 16,
                        color: AppColors.primaryPink,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        type,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
      ],
    ),
  );

  Widget _profileBody(OrbitProfile profile, Map<String, dynamic> data) {
    final about = _about(data);
    final selected = _selectedTypes(data);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _wordmark(),
          const SizedBox(height: 4),
          _hero(profile),
          const SizedBox(height: 12),
          _facts(profile, data),
          const SizedBox(height: 14),
          _cosmicDetails(about),
          const SizedBox(height: 16),
          _typeCard(selected),
          const SizedBox(height: 26),
          if (widget.showEnterButton)
            Container(
              height: 54,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(28),
              ),
              child: TextButton(
                onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                      (_) => false,
                ),
                child: const Text(
                  'Enter ORBIT Universe  →',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
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
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // FIRESTORE PROFILE STREAM
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: Text('Please sign in.')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
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
                child: CircularProgressIndicator(color: AppColors.primaryPink),
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
    );
  }
}
