import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../auth/auth_gate.dart';
import '../auth/player_auth_service.dart';
import '../home_screen.dart';
import 'orbit_profile.dart';
import 'profile_setup_screen.dart';

/// ORBIT • Lunar Lavender profile.
/// UI-only redesign. The player document and saved preference field names
/// remain unchanged: players/{uid}, aboutYou, typeOfMan.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.showEnterButton = false});

  final bool showEnterButton;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _months = <String>[
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  static const _typeOptions = <String>[
    'Gentle', 'Funny', 'Loyal', 'Confident', 'Romantic',
    'Caring', 'Intelligent', 'Goal-Oriented', 'Calm', 'Ambitious',
    'Mature', 'Playful', 'Special', 'Adventurous', 'Mysterious',
    'Communicative', 'Thoughtful',
    'Smart', 'Protective', 'Good Listener', // Existing saved values.
  ];

  static const _defaultAbout =
      'Add a little about yourself to shape your story.';
  static const _oldDefaultAbout =
      'An astrology-inspired archetype for your fictional persona, '
      'not a fixed personality.';

  DocumentReference<Map<String, dynamic>> _playerRef(String uid) =>
      FirebaseFirestore.instance.collection('players').doc(uid);

  String _birthday(OrbitProfile profile, Map<String, dynamic> data) {
    final month = profile.birth_month;
    if (month < 1 || month > 12) return 'Not set';
    final year = data['birth_year'];
    final value = '${_months[month - 1]} ${profile.birth_day}';
    return year is int && year > 0 ? '$value, $year' : value;
  }

  String _about(Map<String, dynamic> data) {
    final value = data['aboutYou'];
    return value is String &&
        value.trim().isNotEmpty &&
        value.trim() != _oldDefaultAbout
        ? value.trim()
        : _defaultAbout;
  }

  List<String> _selectedTypes(Map<String, dynamic> data) {
    final raw = data['typeOfMan'];
    if (raw is! List) return const [];
    final set = raw.whereType<String>().toSet();
    return _typeOptions.where(set.contains).toList(growable: false);
  }

  Future<void> _saveFields(Map<String, dynamic> fields) async {
    const permitted = {'aboutYou', 'typeOfMan'};
    if (fields.keys.any((key) => !permitted.contains(key))) {
      throw StateError('This profile field cannot be edited here.');
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('You must be signed in.');
    await _playerRef(uid).set({
      ...fields,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$error')),
    );
  }

  Future<void> _openPersonaSetup() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ProfileSetupScreen(editMode: true),
      ),
    );
  }

  Future<void> _editAbout(String current) async {
    var draft = current == _defaultAbout ? '' : current;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'About You',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: TextFormField(
          initialValue: draft,
          maxLines: 4,
          maxLength: 180,
          onChanged: (value) => draft = value,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Tell the universe about yourself...',
            hintStyle: const TextStyle(color: AppColors.textSecondary),
            filled: true,
            fillColor: AppColors.elevatedSurface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
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

  Future<void> _editTypes(List<String> current) async {
    final selected = current.toSet();
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, refresh) => SafeArea(
          top: false,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .82,
            ),
            padding: EdgeInsets.fromLTRB(
              20, 14, 20, 16 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Your Type of Man',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Choose up to 6 traits to guide your future matches.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (final type in _typeOptions)
                        FilterChip(
                          label: Text(type),
                          selected: selected.contains(type),
                          showCheckmark: false,
                          backgroundColor: AppColors.elevatedSurface,
                          selectedColor: AppColors.primary,
                          side: BorderSide(
                            color: selected.contains(type)
                                ? AppColors.primary
                                : AppColors.border,
                          ),
                          labelStyle: TextStyle(
                            color: selected.contains(type)
                                ? AppColors.onPrimary
                                : AppColors.textPrimary,
                            fontWeight: selected.contains(type)
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                          onSelected: (active) {
                            if (active && selected.length >= 6) {
                              ScaffoldMessenger.of(sheetContext).showSnackBar(
                                const SnackBar(
                                  content: Text('Choose up to 6 traits.'),
                                ),
                              );
                              return;
                            }
                            refresh(() {
                              if (active) {
                                selected.add(type);
                              } else {
                                selected.remove(type);
                              }
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => Navigator.pop(
                        sheetContext,
                        _typeOptions.where(selected.contains).toList(),
                      ),
                      child: const Text('Save preferences'),
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preferences saved.')),
        );
      }
    } catch (error) {
      _showError('Could not save preferences: $error');
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
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
            child: const Text('Log Out'),
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

  // ====================================================
  // LUNAR LAVENDER — EDITORIAL PROFILE UI
  // No local background. main.dart owns bg.jpg + dark overlay.
  // ====================================================

  static const Color _ink = AppColors.textPrimary;
  static const Color _muted = AppColors.textSecondary;
  static const Color _lilac = AppColors.primary;

  static const Map<String, String> _zodiacSymbols = {
    'Aries': '♈', 'Taurus': '♉', 'Gemini': '♊', 'Cancer': '♋',
    'Leo': '♌', 'Virgo': '♍', 'Libra': '♎', 'Scorpio': '♏',
    'Sagittarius': '♐', 'Capricorn': '♑', 'Aquarius': '♒',
    'Pisces': '♓',
  };

  TextStyle _serif(double fontSize, {bool italic = true}) {
    return TextStyle(
      fontFamily: 'serif',
      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      fontSize: fontSize,
      fontWeight: FontWeight.w400,
      color: _ink,
      height: 1.12,
    );
  }

  Widget _hairline() => Container(
    height: 1,
    color: AppColors.border.withValues(alpha: .72),
  );

  Widget _ornamentDivider() => Row(
    children: [
      Expanded(child: _hairline()),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 13),
        child: Text(
          '✧',
          style: TextStyle(color: _lilac, fontSize: 25, height: 1),
        ),
      ),
      Expanded(child: _hairline()),
    ],
  );

  // Shared non-interactive, centered section title.
  // Editing is controlled through explicit buttons below the content.
  Widget _centeredSectionTitle(String title) => SizedBox(
    width: double.infinity,
    child: Text(
      title,
      textAlign: TextAlign.center,
      style: _serif(26),
    ),
  );

  Widget _profilePicture(OrbitProfile profile, Map<String, dynamic> data) {
    final raw = data['photoUrl'];
    final photoUrl = raw is String && raw.trim().isNotEmpty ? raw.trim() : null;

    final fallback = Image.asset(
      'lib/core/assets/player_avatar.png',
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Image.asset(
        'lib/core/assets/bg4.png',
        fit: BoxFit.cover,
        alignment: const Alignment(-.32, -.72),
        errorBuilder: (_, __, ___) => ColoredBox(
          color: AppColors.elevatedSurface,
          child: Center(
            child: Text(
              profile.username.isEmpty
                  ? '?'
                  : profile.username.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 38,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );

    return Container(
      width: 106,
      height: 106,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: _lilac.withValues(alpha: .82),
          width: 1.3,
        ),
      ),
      child: ClipOval(
        child: photoUrl == null
            ? fallback
            : Image.network(
          photoUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallback,
        ),
      ),
    );
  }

  Widget _identity(OrbitProfile profile, Map<String, dynamic> data) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _profilePicture(profile, data),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.username,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _serif(30),
              ),
              const SizedBox(height: 9),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 9,
                runSpacing: 5,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _zodiacSymbols[profile.zodiac] ?? '✧',
                        style: const TextStyle(
                          color: _lilac,
                          fontSize: 21,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        profile.zodiac,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    '│',
                    style: TextStyle(color: _muted, fontSize: 13),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.satellite_alt_outlined,
                        size: 19,
                        color: _lilac,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        profile.origin_sector,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 15),
              FilledButton.icon(
                onPressed: _openPersonaSetup,
                icon: const Icon(Icons.edit_outlined, size: 17),
                label: const Text('Edit persona'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE2D0F1),
                  foregroundColor: AppColors.onPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 11,
                  ),
                  minimumSize: const Size(0, 42),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  elevation: 0,
                  shape: const StadiumBorder(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Cosmic details are READ-ONLY. Labels stay left, values stay right.
  Widget _detailRow({
    required Widget icon,
    required String label,
    required String value,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: Center(child: icon),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showDivider) _hairline(),
      ],
    );
  }

  Widget _cosmicDetails(OrbitProfile profile, Map<String, dynamic> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _centeredSectionTitle('Cosmic details'),
        const SizedBox(height: 14),
        _detailRow(
          icon: const Icon(
            Icons.calendar_today_outlined,
            color: _lilac,
            size: 22,
          ),
          label: 'Fictional birthday',
          value: _birthday(profile, data),
        ),
        _detailRow(
          icon: Text(
            _zodiacSymbols[profile.zodiac] ?? '✧',
            style: const TextStyle(color: _lilac, fontSize: 24),
          ),
          label: 'Zodiac',
          value: profile.zodiac,
        ),
        _detailRow(
          icon: const Icon(
            Icons.satellite_alt_outlined,
            color: _lilac,
            size: 25,
          ),
          label: 'Origin sector',
          value: profile.origin_sector,
        ),
      ],
    );
  }

  Widget _aboutSection(String about) {
    final isPlaceholder = about == _defaultAbout;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _centeredSectionTitle('About you'),
        const SizedBox(height: 15),
        Text(
          about,
          style: const TextStyle(
            color: _muted,
            fontSize: 14.5,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: () => _editAbout(about),
          icon: Icon(
            isPlaceholder ? Icons.add_rounded : Icons.edit_outlined,
            size: 18,
          ),
          label: Text(isPlaceholder ? 'Add about you' : 'Edit about you'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _lilac,
            side: const BorderSide(color: AppColors.border),
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: const StadiumBorder(),
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
    );
  }

  Future<void> _removeTrait(String trait, List<String> selected) async {
    try {
      await _saveFields({
        'typeOfMan': selected.where((type) => type != trait).toList(),
      });
    } catch (error) {
      _showError('Could not remove $trait: $error');
    }
  }

  Widget _traitChip(String trait, List<String> selected) {
    return Material(
      color: AppColors.elevatedSurface.withValues(alpha: .9),
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: () => _removeTrait(trait, selected),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                trait,
                style: const TextStyle(color: _ink, fontSize: 13.5),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.close_rounded, size: 15, color: _muted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeSection(List<String> selected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _centeredSectionTitle('Your type of man'),
        const SizedBox(height: 15),
        const Text(
          'Your preferences help personalize your matches.',
          style: TextStyle(color: _muted, fontSize: 14.5, height: 1.5),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 9,
          runSpacing: 10,
          children: [
            for (final trait in selected) _traitChip(trait, selected),
            OutlinedButton.icon(
              onPressed: () => _editTypes(selected),
              icon: const Icon(Icons.add_rounded, size: 19),
              label: const Text('Add'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _lilac,
                side: const BorderSide(color: _lilac, width: 1),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                visualDensity: VisualDensity.compact,
                minimumSize: const Size(0, 40),
                shape: const StadiumBorder(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _openSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text(
                  'Profile settings',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: _lilac),
                title: const Text('Edit persona',
                    style: TextStyle(color: _ink)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openPersonaSetup();
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout_rounded, color: _muted),
                title: const Text('Log out',
                    style: TextStyle(color: _ink)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _logout();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(OrbitProfile profile, Map<String, dynamic> data) {
    final about = _about(data);
    final selected = _selectedTypes(data);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 36),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Profile', style: _serif(40, italic: false))),
                  IconButton(
                    onPressed: _openSettings,
                    tooltip: 'Profile settings',
                    icon: const Icon(
                      Icons.settings_outlined,
                      color: _lilac,
                      size: 28,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 25),
              _identity(profile, data),
              const SizedBox(height: 29),
              _ornamentDivider(),
              const SizedBox(height: 24),
              _cosmicDetails(profile, data),
              const SizedBox(height: 26),
              _ornamentDivider(),
              const SizedBox(height: 24),
              _aboutSection(about),
              const SizedBox(height: 26),
              _ornamentDivider(),
              const SizedBox(height: 24),
              _typeSection(selected),
              const SizedBox(height: 28),
              _ornamentDivider(),
              const SizedBox(height: 16),
              if (widget.showEnterButton)
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                        (_) => false,
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _lilac,
                    foregroundColor: AppColors.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('Enter ORBIT Universe'),
                )
              else
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _logout,
                    style: TextButton.styleFrom(
                      foregroundColor: _muted,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.logout_rounded, size: 21),
                    label: const Text('Log out'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Text(
            'Please sign in.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    // No local image, gradient, or dim layer: use main.dart's global bg.jpg.
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
                child: CircularProgressIndicator(color: AppColors.primary),
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
                  child: const Text('Create your persona'),
                ),
              );
            }
            try {
              final profile = OrbitProfile.fromJson({
                ...data,
                'gender': data['gender'] ?? '',
              });
              return _body(profile, data);
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