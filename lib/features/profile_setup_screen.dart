
import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/services/orbit_profile.dart';
import 'home_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() =>
      _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _usernameController = TextEditingController();

  String? _gender;
  String _origin_sector = 'Velara Expanse';
  int _month = 7;
  int _day = 16;
  bool _privacyAccepted = false;
  bool _saving = false;

  static const _months = [
    'January', 'February', 'March', 'April',
    'May', 'June', 'July', 'August',
    'September', 'October', 'November', 'December',
  ];

  static const _sectors = [
    'Velara Expanse', 'Nebula District', 'Moonring Station',
    'Orion Gate', 'Cassio Habitat',
  ];

  static const _genders = [
    'Woman',
    'Man',
    'Non-binary',
    'Prefer not to say',
  ];

  static const _zodiacSymbols = {
    'Aries': '♈', 'Taurus': '♉', 'Gemini': '♊', 'Cancer': '♋',
    'Leo': '♌', 'Virgo': '♍', 'Libra': '♎', 'Scorpio': '♏',
    'Sagittarius': '♐', 'Capricorn': '♑', 'Aquarius': '♒', 'Pisces': '♓',
  };

  static const _zodiacTraits = {
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

  String get _zodiac =>
      ZodiacService.fromBirthday(_month, _day);

  int get _maxDay => DateTime(2000, _month + 1, 0).day;

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _continue() async {
    if (_saving) return;

    final username = _usernameController.text.trim();

    if (username.length < 3) {
      _showError('Username must have at least 3 characters.');
      return;
    }

    if (_gender == null) {
      _showError('Please select your gender.');
      return;
    }

    if (!_privacyAccepted) {
      _showError('Please acknowledge the privacy notice.');
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() => _saving = true);

    try {
      final profile = OrbitProfile(
        username: username,
        gender: _gender!,
        origin_sector: _origin_sector,
        birth_month: _month,
        birth_day: _day,
      );

      await OrbitProfileStore.save(profile);

      if (!mounted) return;

      // Temporary destination until preferences screen exists.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const HomeScreen(),
        ),
            (route) => false,
      );
    } catch (error) {
      debugPrint('Profile save failed: $error');
      if (mounted) {
        _showError('Could not save profile. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _panel({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xED17132B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }

  Widget _label(String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.softLilac, size: 19),
        const SizedBox(width: 9),
        Text(
          text,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _chip({
    required String text,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0x994E245F)
              : const Color(0xFF242039),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? AppColors.primaryPink
                : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [
            BoxShadow(
              color: AppColors.primaryPink.withAlpha(55),
              blurRadius: 13,
            ),
          ]
              : null,
        ),
        child: Text(
          text,
          style: TextStyle(
            color: selected
                ? Colors.white
                : AppColors.softLilac,
            fontSize: 12,
            fontWeight:
            selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _dateDropdown({
    required int value,
    required List<DropdownMenuItem<int>> items,
    required ValueChanged<int?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF25203F),
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          isExpanded: true,
          dropdownColor: const Color(0xFF25203F),
          icon: const Icon(
            Icons.keyboard_arrow_down,
            color: AppColors.softLilac,
            size: 18,
          ),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
          ),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildUsername() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Username', Icons.person_outline),
          const SizedBox(height: 12),
          TextField(
            controller: _usernameController,
            maxLength: 20,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              counterText: '',
              hintText: 'e.g. LunaTraveler',
              hintStyle: const TextStyle(
                color: AppColors.textSecondary,
              ),
              filled: true,
              fillColor: const Color(0xFF25203F),
              prefixIcon: const Icon(
                Icons.alternate_email,
                color: AppColors.softLilac,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.border,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.primaryPink,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your fictional identity across the galaxy.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrigin() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Origin Sector', Icons.public),
          const SizedBox(height: 8),
          const Text(
            'Where do your roots reach across the stars?',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _sectors.map((sector) {
              return _chip(
                text: sector,
                selected: _origin_sector == sector,
                onTap: () {
                  setState(() => _origin_sector = sector);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildGender() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Gender', Icons.diversity_3_outlined),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _genders.map((gender) {
              return _chip(
                text: gender,
                selected: _gender == gender,
                onTap: () {
                  setState(() => _gender = gender);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBirthday() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(
            'Fictional Birthday',
            Icons.calendar_month_outlined,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _dateDropdown(
                  value: _month,
                  items: List.generate(
                    12,
                        (i) => DropdownMenuItem(
                      value: i + 1,
                      child: Text(_months[i]),
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
                        (i) => DropdownMenuItem(
                      value: i + 1,
                      child: Text('${i + 1}'),
                    ),
                  ),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _day = value);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Choose a made-up date. Your real birthday is not needed.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZodiac() {
    final zodiac = _zodiac;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF512277),
            Color(0xFF23163F),
            Color(0xFF16132D),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.primaryPurple,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Your Cosmic Zodiac', Icons.auto_awesome),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                width: 76,
                height: 76,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0x663B1B69),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryPink.withAlpha(55),
                      blurRadius: 25,
                    ),
                  ],
                ),
                child: Text(
                  _zodiacSymbols[zodiac] ?? '✦',
                  style: const TextStyle(
                    fontSize: 49,
                    color: Color(0xFFFFA9EE),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      zodiac,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _zodiacTraits[zodiac] ?? '',
                      style: const TextStyle(
                        color: AppColors.softLilac,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Inspired by astrology, created for your cosmic story.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacy() {
    return _panel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: _privacyAccepted,
            activeColor: AppColors.primaryPink,
            onChanged: (value) {
              setState(() {
                _privacyAccepted = value ?? false;
              });
            },
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Privacy Matters',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'I understand that ORBIT is a fictional world. '
                      'I should not use my real name or actual date of birth.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
            child: ColoredBox(
              color: Color(0xDB090718),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                20, 24, 20, 35,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.satellite_alt_rounded,
                        color: AppColors.primaryPink,
                        size: 27,
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'O R B I T',
                        style: TextStyle(
                          color: AppColors.softLilac,
                          letterSpacing: 3,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        '01 / 03',
                        style: TextStyle(
                          color: AppColors.softLilac,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 36),
                  const Text(
                    'Build Your',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Text(
                    'ORBIT Identity',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF9FDD),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Create your persona and step into a '
                        'universe of new connections.',
                    style: TextStyle(
                      color: AppColors.softLilac,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _buildUsername(),
                  const SizedBox(height: 14),
                  _buildOrigin(),
                  const SizedBox(height: 14),
                  _buildGender(),
                  const SizedBox(height: 14),
                  _buildBirthday(),
                  const SizedBox(height: 14),
                  _buildZodiac(),
                  const SizedBox(height: 14),
                  _buildPrivacy(),
                  const SizedBox(height: 25),
                  Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryPink.withAlpha(65),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _saving ? null : _continue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        disabledBackgroundColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                        width: 23,
                        height: 23,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                          : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Continue',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 10),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
