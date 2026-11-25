import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'orbit_profile.dart';
import 'profile_screen.dart';

/// ORBIT • Lunar Lavender persona setup.
/// editMode = false: first-time onboarding.
/// editMode = true: prefill existing profile, save and return to Profile.
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key, this.editMode = false});

  final bool editMode;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  String? _gender;
  String _originSector = 'Velara Expanse';
  int _month = 7;
  int _day = 16;
  bool _privacyAccepted = false;
  bool _saving = false;
  bool _loading = false;
  String? _loadingError;
  String? _savedUsername;

  static const _months = <String>[
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  static const _sectors = <String>[
    'Velara Expanse',
    'Nebula District',
    'Moonring Station',
    'Orion Gate',
    'Cassio Habitat',
  ];

  static const _genders = <String>['Woman', 'Man', 'Others'];

  static const _zodiacTraits = <String, String>{
    'Aries': 'Bold · Energetic · Adventurous',
    'Taurus': 'Loyal · Grounded · Patient',
    'Gemini': 'Curious · Playful · Expressive',
    'Cancer': 'Caring · Family-oriented · Intuitive',
    'Leo': 'Confident · Warm · Creative',
    'Virgo': 'Thoughtful · Observant · Practical',
    'Libra': 'Charming · Social · Diplomatic',
    'Scorpio': 'Passionate · Loyal · Mysterious',
    'Sagittarius': 'Free-spirited · Optimistic · Bold',
    'Capricorn': 'Ambitious · Disciplined · Dependable',
    'Aquarius': 'Independent · Inventive · Open-minded',
    'Pisces': 'Dreamy · Empathetic · Imaginative',
  };

  String get _registeredUsername {
    if (_savedUsername != null && _savedUsername!.trim().isNotEmpty) {
      return _savedUsername!.trim();
    }
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }
    final email = user?.email;
    if (email != null && email.contains('@')) {
      return email.split('@').first;
    }
    return '';
  }

  String get _zodiac => ZodiacService.fromBirthday(_month, _day);

  int get _maxDay => DateTime(2000, _month + 1, 0).day;

  @override
  void initState() {
    super.initState();
    if (widget.editMode) _loadSavedPersona();
  }

  Future<void> _loadSavedPersona() async {
    setState(() {
      _loading = true;
      _loadingError = null;
    });
    try {
      final profile = await OrbitProfileStore.load();
      if (!mounted) return;
      if (profile == null) {
        setState(() {
          _loadingError = 'No saved persona was found. Please try again.';
        });
        return;
      }
      setState(() {
        _savedUsername = profile.username;
        _gender = profile.gender;
        _originSector = profile.origin_sector;
        _month = profile.birth_month;
        _day = profile.birth_day;
        _privacyAccepted = true;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _loadingError = 'Could not load persona: $error');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _continue() async {
    if (_saving || _loading) return;
    if (_loadingError != null) {
      _showError('Load your saved persona before editing.');
      return;
    }
    final username = _registeredUsername;
    if (username.length < 3) {
      _showError('Please sign in with a username of at least 3 characters.');
      return;
    }
    if (_gender == null) {
      _showError('Please select your gender.');
      return;
    }
    if (!widget.editMode && !_privacyAccepted) {
      _showError('Please acknowledge the privacy notice.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    try {
      await OrbitProfileStore.save(
        OrbitProfile(
          username: username,
          gender: _gender!,
          origin_sector: _originSector,
          birth_month: _month,
          birth_day: _day,
        ),
      );
      if (!mounted) return;

      if (widget.editMode) {
        Navigator.of(context).pop(true);
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const ProfileScreen(showEnterButton: true),
          ),
              (_) => false,
        );
      }
    } catch (error) {
      _showError('Could not save profile: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // --- LUNAR LAVENDER COMPONENTS ---

  Widget _panel({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.surface.withValues(alpha: .94),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: AppColors.border.withValues(alpha: .6),
        width: .8,
      ),
    ),
    child: child,
  );

  Widget _label(String title, IconData icon) => Row(
    children: [
      Icon(icon, color: AppColors.primary, size: 19),
      const SizedBox(width: 9),
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );

  Widget _optionChip({
    required String text,
    required bool selected,
    required VoidCallback onTap,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(22),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 170),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : AppColors.elevatedSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.border,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          color: selected ? AppColors.onPrimary : AppColors.textPrimary,
        ),
      ),
    ),
  );

  Widget _dateDropdown({
    required int value,
    required List<DropdownMenuItem<int>> items,
    required ValueChanged<int?> onChanged,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: AppColors.elevatedSurface,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: AppColors.border),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<int>(
        value: value,
        items: items,
        onChanged: onChanged,
        isExpanded: true,
        dropdownColor: AppColors.surface,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 13,
        ),
        icon: const Icon(
          Icons.keyboard_arrow_down_rounded,
          color: AppColors.textSecondary,
        ),
      ),
    ),
  );

  Widget _buildIdentity() => _panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Your cosmic identity', Icons.person_outline_rounded),
        const SizedBox(height: 12),
        Text(
          _registeredUsername.isEmpty ? 'Traveler' : _registeredUsername,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Your username is linked to your account.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12.5,
          ),
        ),
      ],
    ),
  );

  Widget _buildGender() => _panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Gender', Icons.people_outline_rounded),
        const SizedBox(height: 14),
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [
            for (final gender in _genders)
              _optionChip(
                text: gender,
                selected: _gender == gender,
                onTap: () => setState(() => _gender = gender),
              ),
          ],
        ),
      ],
    ),
  );

  Widget _buildOrigin() => _panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Origin sector', Icons.public_outlined),
        const SizedBox(height: 6),
        const Text(
          'Where does your fictional story begin?',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final sector in _sectors)
              _optionChip(
                text: sector,
                selected: _originSector == sector,
                onTap: () => setState(() => _originSector = sector),
              ),
          ],
        ),
      ],
    ),
  );

  Widget _buildBirthday() => _panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Fictional birthday', Icons.calendar_today_outlined),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: _dateDropdown(
                value: _month,
                items: List.generate(
                  12,
                      (index) => DropdownMenuItem<int>(
                    value: index + 1,
                    child: Text(_months[index]),
                  ),
                ),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _month = value;
                    if (_day > _maxDay) _day = _maxDay;
                  });
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _dateDropdown(
                value: _day,
                items: List.generate(
                  _maxDay,
                      (index) => DropdownMenuItem<int>(
                    value: index + 1,
                    child: Text('${index + 1}'),
                  ),
                ),
                onChanged: (value) {
                  if (value != null) setState(() => _day = value);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          'A made-up date is enough. Your real birthday is not needed.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    ),
  );

  Widget _buildZodiacPreview() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: AppColors.elevatedSurface.withValues(alpha: .94),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.nightlight_round,
          color: AppColors.primary,
          size: 29,
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _zodiac,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _zodiacTraits[_zodiac] ?? '',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildPrivacy() => _panel(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: _privacyAccepted,
          activeColor: AppColors.primary,
          checkColor: AppColors.onPrimary,
          onChanged: (value) => setState(
                () => _privacyAccepted = value ?? false,
          ),
        ),
        const SizedBox(width: 4),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your privacy matters',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 7),
              Text(
                'I understand that ORBIT is fictional. I should not use '
                    'my real name or actual date of birth.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Use the shared global galaxy, but keep this screen subtle.
          const Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(color: Color(0xA612101D)),
            ),
          ),
          SafeArea(
            child: _loading
                ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
                : _loadingError != null
                ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _loadingError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: _loadSavedPersona,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
                : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 38),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 540),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          if (widget.editMode) ...[
                            IconButton(
                              onPressed: () => Navigator.maybePop(context),
                              icon: const Icon(
                                Icons.arrow_back_rounded,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Image.asset(
                            'lib/core/assets/orbit_wordmark.png',
                            width: 110,
                            height: 44,
                            alignment: Alignment.centerLeft,
                            errorBuilder: (_, __, ___) => const Text(
                              'ORBIT',
                              style: TextStyle(
                                fontSize: 21,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Text(
                        widget.editMode ? 'Edit your persona' : 'Build your identity',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.editMode
                            ? 'Make changes to your fictional identity.'
                            : 'A little about you, before your story begins.',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildIdentity(),
                      const SizedBox(height: 12),
                      _buildGender(),
                      const SizedBox(height: 12),
                      _buildOrigin(),
                      const SizedBox(height: 12),
                      _buildBirthday(),
                      const SizedBox(height: 12),
                      _buildZodiacPreview(),
                      if (!widget.editMode) ...[
                        const SizedBox(height: 12),
                        _buildPrivacy(),
                      ],
                      const SizedBox(height: 23),
                      FilledButton(
                        onPressed: _saving ? null : _continue,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(double.infinity, 52),
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.onPrimary,
                          disabledBackgroundColor: AppColors.elevatedSurface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox.square(
                          dimension: 19,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.onPrimary,
                          ),
                        )
                            : Text(
                          widget.editMode ? 'Save changes' : 'Continue',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
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
