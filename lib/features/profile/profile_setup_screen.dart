import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_radius.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/orbit_logo.dart';
import 'orbit_profile.dart';
import 'profile_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key, this.editMode = false});

  final bool editMode;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  int _step = 0;
  String? _gender;
  String _originSector = 'Velara Expanse';
  int _month = 7;
  int _day = 16;
  final Set<String> _selectedTypes = {};
  bool _privacyAccepted = false;
  bool _saving = false;
  bool _loading = false;
  String? _loadingError;
  String? _savedUsername;

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

  // Text presentation selector avoids colorful emoji where supported.
  static const _zodiacSymbols = <String, String>{
    'Aries': '\u2648\uFE0E',
    'Taurus': '\u2649\uFE0E',
    'Gemini': '\u264A\uFE0E',
    'Cancer': '\u264B\uFE0E',
    'Leo': '\u264C\uFE0E',
    'Virgo': '\u264D\uFE0E',
    'Libra': '\u264E\uFE0E',
    'Scorpio': '\u264F\uFE0E',
    'Sagittarius': '\u2650\uFE0E',
    'Capricorn': '\u2651\uFE0E',
    'Aquarius': '\u2652\uFE0E',
    'Pisces': '\u2653\uFE0E',
  };

  String get _registeredUsername {
    final saved = _savedUsername?.trim();
    if (saved != null && saved.isNotEmpty) return saved;
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;
    final email = user?.email;
    if (email != null && email.contains('@')) return email.split('@').first;
    return '';
  }

  String get _zodiac => ZodiacService.fromBirthday(_month, _day);
  int get _maxDay => DateTime(2000, _month + 1, 0).day;
  bool get _lastStep => _step == 2;

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
        _originSector = profile.originSector;
        _month = profile.birthMonth;
        _day = profile.birthDay;
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
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  bool _validateIdentity() {
    if (_registeredUsername.length < 3) {
      _showError('Please sign in with a username of at least 3 characters.');
      return false;
    }
    if (_gender == null) {
      _showError('Please select your gender.');
      return false;
    }
    return true;
  }

  void _goBack() {
    if (_saving || _step == 0) return;
    FocusScope.of(context).unfocus();
    setState(() => _step--);
  }

  Future<void> _continue() async {
    if (_saving || _loading || _loadingError != null) return;
    if (!_validateIdentity()) return;

    if (!widget.editMode && !_lastStep) {
      FocusScope.of(context).unfocus();
      setState(() => _step++);
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
          username: _registeredUsername,
          gender: _gender!,
          originSector: _originSector,
          birthMonth: _month,
          birthDay: _day,
        ),
        typeOfMan: widget.editMode
            ? null
            : OrbitPreferences.typeOptions
                  .where(_selectedTypes.contains)
                  .toList(),
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

  void _selectType(String type, bool selected) {
    if (_saving) return;
    if (selected &&
        !_selectedTypes.contains(type) &&
        _selectedTypes.length >= OrbitPreferences.maxTraits) {
      _showError('Choose up to ${OrbitPreferences.maxTraits} traits.');
      return;
    }
    setState(() {
      if (selected) {
        _selectedTypes.add(type);
      } else {
        _selectedTypes.remove(type);
      }
    });
  }

  Widget _dropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) => Container(
    constraints: const BoxConstraints(minHeight: 48),
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.inputHorizontal),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.input),
      border: Border.all(color: AppColors.border),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: value,
        items: items,
        onChanged: _saving ? null : onChanged,
        isExpanded: true,
        dropdownColor: AppColors.elevatedSurface,
        borderRadius: BorderRadius.circular(AppRadius.input),
        style: AppTextStyles.input,
        icon: const Icon(
          Icons.keyboard_arrow_down_rounded,
          color: AppColors.textSecondary,
        ),
      ),
    ),
  );

  Widget _intro(String title, String subtitle, {String? chapter}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (chapter != null) ...[
        Text(chapter, style: AppTextStyles.overline),
        const SizedBox(height: AppSpacing.md),
      ],
      Text(title, style: AppTextStyles.display),
      const SizedBox(height: AppSpacing.sm),
      Text(subtitle, style: AppTextStyles.bodyMuted),
    ],
  );

  Widget _identity() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text('Your cosmic username', style: AppTextStyles.title),
      const SizedBox(height: AppSpacing.sm),
      Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.input),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.alternate_email_rounded,
              size: 20,
              color: AppColors.primary,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                _registeredUsername.isEmpty ? 'Traveler' : _registeredUsername,
                style: AppTextStyles.body,
              ),
            ),
            const Icon(
              Icons.lock_outline_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      const Text(
        'Your username is linked to your account.',
        style: AppTextStyles.caption,
      ),
      const SizedBox(height: AppSpacing.sectionGap),
      const Text('Gender', style: AppTextStyles.title),
      const SizedBox(height: AppSpacing.sm),
      Wrap(
        spacing: AppSpacing.chipGap,
        children: [
          for (final gender in _genders)
            OrbitChip(
              label: gender,
              selected: _gender == gender,
              onSelected: (_) {
                if (!_saving) setState(() => _gender = gender);
              },
            ),
        ],
      ),
      const SizedBox(height: AppSpacing.sectionGap),
      const Text('Origin sector', style: AppTextStyles.title),
      const SizedBox(height: AppSpacing.xs),
      const Text(
        'Where does your fictional story begin?',
        style: AppTextStyles.caption,
      ),
      const SizedBox(height: AppSpacing.md),
      _dropdown<String>(
        value: _originSector,
        items: [
          for (final sector in {..._sectors, _originSector})
            DropdownMenuItem(value: sector, child: Text(sector)),
        ],
        onChanged: (value) {
          if (value != null) setState(() => _originSector = value);
        },
      ),
    ],
  );

  Widget _birthday() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text('Fictional birthday', style: AppTextStyles.title),
      const SizedBox(height: AppSpacing.md),
      Row(
        children: [
          Expanded(
            flex: 2,
            child: _dropdown<int>(
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
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _dropdown<int>(
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
      const SizedBox(height: AppSpacing.md),
      const Text(
        'A made-up date is enough. Your real birthday is not needed.',
        style: AppTextStyles.caption,
      ),
      const SizedBox(height: AppSpacing.xxxl),
      _zodiacPreview(),
    ],
  );

  Widget _zodiacPreview() => Column(
    children: [
      Text(
        _zodiacSymbols[_zodiac] ?? '✧',
        style: const TextStyle(
          fontSize: 72,
          height: 1.2,
          color: AppColors.primary,
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      Text(_zodiac, style: AppTextStyles.editorial.copyWith(fontSize: 32)),
      const SizedBox(height: AppSpacing.sm),
      Text(
        _zodiacTraits[_zodiac] ?? '',
        textAlign: TextAlign.center,
        style: AppTextStyles.body.copyWith(color: AppColors.primary),
      ),
      const SizedBox(height: AppSpacing.md),
      const Text(
        'A little cosmic inspiration for your fictional persona.',
        style: AppTextStyles.caption,
        textAlign: TextAlign.center,
      ),
    ],
  );

  Widget _preferences() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          const Expanded(
            child: Text('Your ideal type of man', style: AppTextStyles.title),
          ),
          Text(
            '${_selectedTypes.length}/${OrbitPreferences.maxTraits}',
            style: AppTextStyles.caption.copyWith(color: AppColors.primary),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.sm),
      const Text(
        'Choose the traits you appreciate most. This step is optional.',
        style: AppTextStyles.caption,
      ),
      const SizedBox(height: AppSpacing.md),
      Wrap(
        spacing: AppSpacing.chipGap,
        children: [
          for (final type in OrbitPreferences.typeOptions)
            OrbitChip(
              label: type,
              selected: _selectedTypes.contains(type),
              onSelected: (selected) => _selectType(type, selected),
            ),
        ],
      ),
      const SizedBox(height: AppSpacing.sm),
      const Text(
        'You can change your preferences later in your profile.',
        style: AppTextStyles.caption,
      ),
      const SizedBox(height: AppSpacing.sectionGap),
      const Divider(),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        activeColor: AppColors.primary,
        checkColor: AppColors.onPrimary,
        value: _privacyAccepted,
        onChanged: _saving
            ? null
            : (value) => setState(() => _privacyAccepted = value ?? false),
        title: const Text('Your privacy matters', style: AppTextStyles.title),
        subtitle: const Text(
          'I understand that ORBIT is fictional. I should not use my real name or actual date of birth.',
          style: AppTextStyles.caption,
        ),
      ),
    ],
  );

  Widget _header() => Column(
    children: [
      Row(
        children: [
          if (widget.editMode) ...[
            IconButton(
              onPressed: _saving ? null : () => Navigator.maybePop(context),
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: 'Back',
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          const OrbitLogo(
            wordmark: true,
            size: 110,
            height: 44,
            alignment: Alignment.centerLeft,
          ),
          const Spacer(),
          if (!widget.editMode)
            Text('0${_step + 1} / 03', style: AppTextStyles.caption),
        ],
      ),
      if (!widget.editMode) ...[
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 3,
                  decoration: BoxDecoration(
                    color: i <= _step
                        ? AppColors.primary
                        : AppColors.elevatedSurface,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    ],
  );

  Widget _stepContent() {
    if (widget.editMode) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _intro(
            'Edit your persona',
            'Make changes to your fictional identity.',
          ),
          const SizedBox(height: AppSpacing.xxxl),
          _identity(),
          const SizedBox(height: AppSpacing.xxxl),
          _birthday(),
        ],
      );
    }

    final (chapter, title, subtitle, content) = switch (_step) {
      0 => (
        'CHAPTER 01 — IDENTITY',
        'Who are you?',
        "Every universe begins with a story. Let's start with yours.",
        _identity(),
      ),
      1 => (
        'CHAPTER 02 — ZODIAC',
        'Written in the stars.',
        'Discover the cosmic identity of your fictional persona.',
        _birthday(),
      ),
      _ => (
        'CHAPTER 03 — CONNECTION',
        "What's your type?",
        'Tell us what makes someone special to you.',
        _preferences(),
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _intro(title, subtitle, chapter: chapter),
        const SizedBox(height: AppSpacing.xxxl),
        content,
      ],
    );
  }

  Widget _footer() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      OrbitButton(
        label: widget.editMode
            ? 'Save changes'
            : _lastStep
            ? 'Enter your universe'
            : 'Continue',
        fullWidth: true,
        icon: widget.editMode ? null : Icons.arrow_forward_rounded,
        isLoading: _saving,
        onPressed:
            _saving || (!widget.editMode && _lastStep && !_privacyAccepted)
            ? null
            : _continue,
      ),
      // Reserve the same footer height on each onboarding step.
      if (!widget.editMode)
        SizedBox(
          height: 48,
          child: _step > 0
              ? TextButton(
                  onPressed: _saving ? null : _goBack,
                  child: const Text('Back'),
                )
              : null,
        ),
    ],
  );

  Widget _form() => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 540),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageHorizontal,
          AppSpacing.pageVertical,
          AppSpacing.pageHorizontal,
          AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: SingleChildScrollView(
                key: ValueKey(widget.editMode ? -1 : _step),
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: _stepContent(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _footer(),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: !_saving && (widget.editMode || _step == 0),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !widget.editMode && !_saving && _step > 0) _goBack();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _loadingError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _loadingError!,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyMuted,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        FilledButton(
                          onPressed: _loadSavedPersona,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _form(),
        ),
      ),
    );
  }
}
