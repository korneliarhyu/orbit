
import 'package:flutter/material.dart';

import '../core/services/orbit_profile.dart';
import '../core/theme/app_colors.dart';
import 'home_screen.dart';
import 'profile_setup_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    this.showEnterButton = false,
  });

  final bool showEnterButton;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<OrbitProfile?> _profileFuture;

  static const _months = [
    'January', 'February', 'March', 'April',
    'May', 'June', 'July', 'August',
    'September', 'October', 'November', 'December',
  ];

  static const _zodiacSymbols = {
    'Aries': '♈',
    'Taurus': '♉',
    'Gemini': '♊',
    'Cancer': '♋',
    'Leo': '♌',
    'Virgo': '♍',
    'Libra': '♎',
    'Scorpio': '♏',
    'Sagittarius': '♐',
    'Capricorn': '♑',
    'Aquarius': '♒',
    'Pisces': '♓',
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

  @override
  void initState() {
    super.initState();
    _profileFuture = OrbitProfileStore.load();
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xEA19152F),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }

  Widget _infoRow(
      IconData icon,
      String title,
      String value,
      ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Icon(
            icon,
            color: AppColors.softLilac,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfile(OrbitProfile profile) {
    final zodiac = profile.zodiac;
    final birthday =
        '${_months[profile.birth_month - 1]} ${profile.birth_day}';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 25, 20, 35),
      child: Column(
        children: [
          const Text(
            'O R B I T',
            style: TextStyle(
              color: AppColors.softLilac,
              letterSpacing: 4,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 24),

          const Text(
            'Your Cosmic Identity',
            style: TextStyle(
              color: Colors.white,
              fontSize: 27,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'A new story begins among the stars.',
            style: TextStyle(
              color: AppColors.softLilac,
              fontSize: 13,
            ),
          ),

          const SizedBox(height: 30),

          // Cosmic profile avatar
          Container(
            width: 132,
            height: 132,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.primaryGradient,
              border: Border.all(
                color: const Color(0xFFFFB6F0),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryPink.withAlpha(110),
                  blurRadius: 42,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: Text(
              profile.username.isNotEmpty
                  ? profile.username[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 60,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 22),

          Text(
            profile.username,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 29,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF472064),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: AppColors.primaryPurple,
              ),
            ),
            child: Text(
              '${_zodiacSymbols[zodiac] ?? '✦'} $zodiac',
              style: const TextStyle(
                color: Color(0xFFFFB6F0),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          const SizedBox(height: 26),

          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '✦ Cosmic Details',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _infoRow(
                  Icons.public,
                  'Origin Sector',
                  profile.origin_sector,
                ),
                _infoRow(
                  Icons.diversity_3_outlined,
                  'Gender',
                  profile.gender,
                ),
                _infoRow(
                  Icons.calendar_month_outlined,
                  'Fictional Birthday',
                  birthday,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '✦ Your Zodiac Vibe',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '${_zodiacSymbols[zodiac] ?? '✦'} $zodiac',
                  style: const TextStyle(
                    color: Color(0xFFFFA7E4),
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _zodiacTraits[zodiac] ?? '',
                  style: const TextStyle(
                    color: AppColors.softLilac,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'An astrology-inspired archetype for your '
                      'fictional persona, not a fixed personality.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),
          // Continue to ORBIT universe button
          // Only show during onboarding
          if (widget.showEnterButton)
            Container(
              width: double.infinity,
              height: 55,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(28),
              ),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (_) => const HomeScreen(),
                    ),
                        (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: const Text(
                  'Enter ORBIT Universe  →',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
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
              color: Color(0xD9090718),
            ),
          ),
          SafeArea(
            child: FutureBuilder<OrbitProfile?>(
              future: _profileFuture,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  debugPrint('❌ PROFILE ERROR: ${snapshot.error}');

                  return Center(
                    child: Text(
                      'ERROR: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.redAccent,
                      ),
                    ),
                  );
                }
                final profile = snapshot.data;

                if (profile == null) {
                  return Center(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) =>
                            const ProfileSetupScreen(),
                          ),
                        );
                      },
                      child: const Text('Create Your Persona'),
                    ),
                  );
                }
                return _buildProfile(profile);
              },
            ),
          ),
        ],
      ),
    );
  }
}
