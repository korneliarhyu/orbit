import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// PLAYER'S IDENTITY [FICTIONAL]
class OrbitProfile{
  final String username;
  final String gender;
  final String origin_sector;
  final int birth_month;
  final int birth_day;

  const OrbitProfile({
    required this.username,
    required this.gender,
    required this.origin_sector,
    required this.birth_month,
    required this.birth_day
  });

  String get zodiac => ZodiacService.fromBirthday(birth_month, birth_day);

  Map<String, dynamic> toJson() => {
    'username': username,
    'gender': gender,
    'originSector': origin_sector,
    'birthMonth': birth_month,
    'birthDay': birth_day,
  };

  factory OrbitProfile.fromJson(Map<String, dynamic> json) {
    return OrbitProfile(
      username: json['username'] as String,
      gender: json['gender'] as String,
      origin_sector: json['origin_sector'] as String,
      birth_month: json['birth_month'] as int,
      birth_day: json['birth_day'] as int,
    );
  }
}

// Zodiac Generator
class ZodiacService{
  static String fromBirthday(int month, int day){
    const startDays = [ 20, 19, 21, 20, 21, 21, 23, 23, 23, 23, 22, 22];

    const signs = [
      'Capricorn', 'Aquarius', 'Pisces', 'Aries',
      'Taurus', 'Gemini', 'Cancer', 'Leo',
      'Virgo', 'Libra', 'Scorpio', 'Sagittarius',
    ];

    if (month < 1 || month > 12 ||
        day < 1 || day > DateTime(2000, month + 1, 0).day) {
      throw ArgumentError('Invalid date');
    }

    return day >= startDays[month - 1]
        ? signs[month % 12]
        : signs[month - 1];
  }
}

// LOCAL PROFILE STORAGE
class OrbitProfileStore {
  static const String _key = 'orbit_profile_v1';

  static final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  static Future<void> save(OrbitProfile profile) async {
    await _prefs.setString(
      _key,
      // SAVE THE PROFILE TO DATABASE USING JSON
      jsonEncode(profile.toJson()),
    );
  }

  static Future<OrbitProfile?> load() async {
    final saved = await _prefs.getString(_key);
    if (saved == null) return null;
    // IF PROFILE AVAILABLE, GET PROFILE
    return OrbitProfile.fromJson(
      Map<String, dynamic>.from(jsonDecode(saved) as Map),
    );
  }
}