import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// PLAYER PROFILE
class OrbitProfile {
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
    required this.birth_day,
  });

  String get zodiac =>
      ZodiacService.fromBirthday(birth_month, birth_day);

  Map<String, dynamic> toJson() => {
    'username': username,
    'gender': gender,
    'origin_sector': origin_sector,
    'birth_month': birth_month,
    'birth_day': birth_day,
  };

  factory OrbitProfile.fromJson(Map<String, dynamic> json) {
    return OrbitProfile(
      username: json['username'] as String,
      gender: json['gender'] as String,
      origin_sector: (
          json['origin_sector'] ?? json['originSector']
      ) as String,
      birth_month: (
          json['birth_month'] ?? json['birthMonth']
      ) as int,
      birth_day: (
          json['birth_day'] ?? json['birthDay']
      ) as int,
    );
  }
}


// STORING PLAYER'S PROFILE
class OrbitProfileStore {
  static final FirebaseFirestore _db =
      FirebaseFirestore.instance;

  static String get _uid {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw StateError('Player is not logged in.');
    }

    return user.uid;
  }

  // SAVE PROFILE TO FIRESTORE
  static Future<void> save(OrbitProfile profile) async {
    await _db
        .collection('players')
        .doc(_uid)
        .set({
      ...profile.toJson(),
      'zodiac': profile.zodiac,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // LOAD PROFILE FROM FIRESTORE
  static Future<OrbitProfile?> load() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return null;

    final snapshot = await _db
        .collection('players')
        .doc(user.uid)
        .get();

    final data = snapshot.data();
    if (data == null) return null;
    return OrbitProfile.fromJson(data);
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