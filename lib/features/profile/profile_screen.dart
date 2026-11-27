import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_radius.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_avatar.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/app_icon_button.dart';
import '../../core/widgets/app_section_title.dart';
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

  static const _defaultAbout =
      'Add a little about yourself to shape your story.';
  static const _oldDefaultAbout =
      'An astrology-inspired archetype for your fictional persona, '
      'not a fixed personality.';

  DocumentReference<Map<String, dynamic>> _playerRef(String uid) =>
      FirebaseFirestore.instance.collection('players').doc(uid);

  String _birthday(OrbitProfile profile, Map<String, dynamic> data) {
    final month = profile.birthMonth;

    if (month < 1 || month > 12) return 'Not set';

    final year = data['birth_year'];
    final value = '${_months[month - 1]} ${profile.birthDay}';

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
    return OrbitPreferences.typeOptions
        .where(set.contains)
        .toList(growable: false);
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
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$error')));
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
          style: AppTextStyles.body,
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
              20,
              14,
              20,
              16 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppRadius.bottomSheet),
              ),
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
                    'Choose up to ${OrbitPreferences.maxTraits} traits.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    '${selected.length}/${OrbitPreferences.maxTraits} selected',
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.chipGap,
                    runSpacing: AppSpacing.chipGap,
                    children: [
                      for (final type in OrbitPreferences.typeOptions)
                        OrbitChip(
                          label: type,
                          selected: selected.contains(type),
                          onSelected: (active) {
                            if (active &&
                                selected.length >= OrbitPreferences.maxTraits) {
                              ScaffoldMessenger.of(sheetContext).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Choose up to ${OrbitPreferences.maxTraits} traits.',
                                  ),
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
                  OrbitButton(
                    label: 'Save preferences',
                    fullWidth: true,
                    onPressed: selected.length > OrbitPreferences.maxTraits
                        ? null
                        : () => Navigator.pop(
                            sheetContext,
                            OrbitPreferences.typeOptions
                                .where(selected.contains)
                                .toList(),
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
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Preferences saved.')));
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

  // Shared design system — global background is supplied by main.dart.
  Widget _sectionDivider() => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
    child: Row(
      children: [
        Expanded(
          child: Divider(
            height: 1,
            color: AppColors.border.withValues(alpha: 0.7),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Text(
            '✧',
            style: TextStyle(color: AppColors.primary, fontSize: 15, height: 1),
          ),
        ),
        Expanded(
          child: Divider(
            height: 1,
            color: AppColors.border.withValues(alpha: 0.7),
          ),
        ),
      ],
    ),
  );

  Widget _profilePicture(OrbitProfile profile, Map<String, dynamic> data) {
    final raw = data['photoUrl'];
    final url = raw is String && raw.trim().isNotEmpty ? raw.trim() : null;

    return OrbitAvatar(
      name: profile.username,
      size: 112,
      imageUrl: url,
      fallbackAsset: 'lib/core/assets/bg4.png',
      fallbackAlignment: const Alignment(-.32, -.72),
    );
  }

  Widget _identity(OrbitProfile profile, Map<String, dynamic> data) => Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      _profilePicture(profile, data),

      const SizedBox(height: AppSpacing.md),

      Text(
        profile.username,
        style: AppTextStyles.heading1,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    ],
  );

  Widget _detailRow({
    required Widget icon,
    required String label,
    required String value,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(width: 24, height: 24, child: Center(child: icon)),
        const SizedBox(width: AppSpacing.iconGap),
        Expanded(child: Text(label, style: AppTextStyles.bodyMuted)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            value,
            style: AppTextStyles.body,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    ),
  );

  Widget _cosmicDetails(OrbitProfile profile, Map<String, dynamic> data) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const OrbitSectionTitle(title: 'Cosmic details'),
          const SizedBox(height: AppSpacing.xs),
          _detailRow(
            icon: const Icon(
              Icons.calendar_today_outlined,
              color: AppColors.primary,
              size: 20,
            ),
            label: 'Fictional birthday',
            value: _birthday(profile, data),
          ),
          _detailRow(
            icon: const Icon(
              Icons.auto_awesome_outlined,
              color: AppColors.primary,
              size: 20,
            ),
            label: 'Zodiac',
            value: profile.zodiac,
          ),
          _detailRow(
            icon: const Icon(
              Icons.public_outlined,
              color: AppColors.primary,
              size: 20,
            ),
            label: 'Origin sector',
            value: profile.originSector,
          ),
        ],
      );

  Widget _aboutSection(String about) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      OrbitSectionTitle(
        title: 'About you',
        actionText: about == _defaultAbout ? 'Add' : 'Edit',
        onTapAction: () => _editAbout(about),
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(about, style: AppTextStyles.bodyMuted),
    ],
  );

  Future<void> _removeTrait(String trait) async {
    try {
      // Remove just this trait, without overwriting other saved selections.
      await _saveFields({
        'typeOfMan': FieldValue.arrayRemove([trait]),
      });
    } catch (error) {
      _showError('Could not remove $trait: $error');
    }
  }

  Widget _typeSection(List<String> selected) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      OrbitSectionTitle(
        title: 'Your type of man',
        actionText: selected.isEmpty ? 'Add' : 'Edit',
        onTapAction: () => _editTypes(selected),
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(
        '${selected.length}/${OrbitPreferences.maxTraits} traits selected',
        style: AppTextStyles.caption,
      ),
      const SizedBox(height: AppSpacing.xs),
      if (selected.isEmpty)
        const Text(
          'Choose the personality traits you value most.',
          style: AppTextStyles.bodyMuted,
        )
      else
        Wrap(
          spacing: AppSpacing.chipGap,
          runSpacing: 0,
          children: [
            for (final trait in selected)
              OrbitChip(label: trait, onDeleted: () => _removeTrait(trait)),
          ],
        ),
    ],
  );

  Future<void> _openSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.bottomSheet),
        ),
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
                leading: const Icon(
                  Icons.edit_outlined,
                  color: AppColors.primary,
                ),
                title: const Text(
                  'Edit persona',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openPersonaSetup();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.logout_rounded,
                  color: AppColors.textSecondary,
                ),
                title: const Text(
                  'Log out',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
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
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        AppSpacing.sm,
        AppSpacing.pageHorizontal,
        AppSpacing.xl,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Profile', style: AppTextStyles.heading1),
                  ),
                  OrbitIconButton(
                    icon: Icons.settings_outlined,
                    variant: OrbitIconButtonVariant.ghost,
                    size: 48,
                    tooltip: 'Profile settings',
                    onTap: _openSettings,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _identity(profile, data),
              _sectionDivider(),
              _cosmicDetails(profile, data),
              _sectionDivider(),
              _aboutSection(about),
              _sectionDivider(),
              _typeSection(selected),
              if (widget.showEnterButton) ...[
                const SizedBox(height: AppSpacing.lg),
                OrbitButton(
                  label: 'Enter ORBIT Universe',
                  icon: Icons.arrow_forward_rounded,
                  fullWidth: true,
                  onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                    (_) => false,
                  ),
                ),
              ],
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
