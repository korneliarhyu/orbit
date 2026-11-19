
import 'dart:math';

import 'npc_outfit_generator.dart';

// ======================================================
// NPC PORTRAIT ANGLE
// ======================================================

enum NpcAngle {
  front,
  left,
  right,
}

// ======================================================
// NPC APPEARANCE MODEL
// ======================================================

class NpcAppearance {
  final int seed;

  // Character identity
  final String career;
  final String outfit;
  final NpcAngle angle;

  // Face components
  final int skinTone;
  final int eyes;
  final int eyebrows;
  final int nose;
  final int mouth;

  // Hair components
  final int hairFront;
  final int? hairBack;

  // Optional appearance
  final int? tattoo;

  const NpcAppearance({
    required this.seed,
    required this.career,
    required this.outfit,
    required this.angle,
    required this.skinTone,
    required this.eyes,
    required this.eyebrows,
    required this.nose,
    required this.mouth,
    required this.hairFront,
    this.hairBack,
    this.tattoo,
  });

  // ====================================================
  // ASSET CONFIGURATION
  // ====================================================

  static const String assetRoot =
      'lib/core/assets/npc';

  // Actual number of available PNG assets.
  static const int skinCount = 5;
  static const int eyesCount = 5;
  static const int eyebrowsCount = 5;
  static const int noseCount = 5;
  static const int mouthCount = 5;
  static const int hairFrontCount = 5;

  // Enable when tattoo assets are ready.
  static const bool enableTattoo = false;
  static const int tattooCount = 0;

  // Probability of having a tattoo.
  static const double tattooChance = 0.25;

  // Hair styles requiring a matching back layer.
  //
  // All five front hairstyles have matching hair_back_0X assets.
  // The same ID must be used for front and back to keep hair aligned.
  static const Set<int> hairStylesWithBack = {1, 2, 3, 4, 5};

  // ====================================================
  // HELPER GETTERS
  // ====================================================

  bool get hasTattoo => tattoo != null;

  bool get hasHairBack => hairBack != null;

  String get assetFolder =>
      '$assetRoot/${angle.name}';

  static String formatId(int value) {
    return value.toString().padLeft(2, '0');
  }

  // ====================================================
  // RANDOM APPEARANCE GENERATOR
  // ====================================================

  factory NpcAppearance.generate({
    required String career,
    required int seed,
  }) {
    // Deterministic random:
    // same seed + career = same appearance.
    final rng = Random(seed);

    // MVP: FRONT only.
    const angle = NpcAngle.front;

    // ------------------------------------------
    // 1. SKIN
    // ------------------------------------------

    final skinTone = rng.nextInt(skinCount) + 1;

    // ------------------------------------------
    // 2. FACIAL FEATURES
    // ------------------------------------------

    final eyes = rng.nextInt(eyesCount) + 1;

    final eyebrows =
        rng.nextInt(eyebrowsCount) + 1;

    final nose = rng.nextInt(noseCount) + 1;

    final mouth = rng.nextInt(mouthCount) + 1;

    // ------------------------------------------
    // 3. HAIRSTYLE
    // ------------------------------------------

    final hairFront =
        rng.nextInt(hairFrontCount) + 1;

    // Only certain hairstyles need back hair.
    final int? hairBack =
    hairStylesWithBack.contains(hairFront)
        ? hairFront
        : null;

    // ------------------------------------------
    // 4. OPTIONAL TATTOO
    // ------------------------------------------

    int? tattoo;

    if (enableTattoo && tattooCount > 0) {
      final hasTattoo =
          rng.nextDouble() < tattooChance;

      if (hasTattoo) {
        tattoo = rng.nextInt(tattooCount) + 1;
      }
    }

    // ------------------------------------------
    // 5. CAREER-BASED OUTFIT
    // ------------------------------------------

    final outfit = NpcOutfitGenerator.generate(
      career,
      random: rng,
    );

    // ------------------------------------------
    // 6. FINAL APPEARANCE
    // ------------------------------------------

    return NpcAppearance(
      seed: seed,
      career: career,
      outfit: outfit,
      angle: angle,
      skinTone: skinTone,
      eyes: eyes,
      eyebrows: eyebrows,
      nose: nose,
      mouth: mouth,
      hairFront: hairFront,
      hairBack: hairBack,
      tattoo: tattoo,
    );
  }

  // ====================================================
  // SERIALIZATION
  // ====================================================

  Map<String, dynamic> toJson() {
    return {
      'seed': seed,
      'career': career,
      'outfit': outfit,
      'angle': angle.name,
      'skinTone': skinTone,
      'eyes': eyes,
      'eyebrows': eyebrows,
      'nose': nose,
      'mouth': mouth,
      'hairFront': hairFront,
      'hairBack': hairBack,
      'tattoo': tattoo,
    };
  }

  factory NpcAppearance.fromJson(
      Map<String, dynamic> json,
      ) {
    // Compatibility with older saved NPCs.
    final rawHairFront =
        json['hairFront'] ??
            json['hair'] ??
            json['hair_front'];

    final rawHairBack = json['hairBack'];
    final rawTattoo = json['tattoo'];

    return NpcAppearance(
      seed: json['seed'] as int,
      career: json['career'] as String,
      outfit: json['outfit'] as String,
      angle: NpcAngle.values.byName(
        (json['angle'] as String?) ?? 'front',
      ),
      skinTone: json['skinTone'] as int,
      eyes: json['eyes'] as int,
      eyebrows: json['eyebrows'] as int,
      nose: json['nose'] as int,
      mouth: json['mouth'] as int,
      hairFront: rawHairFront as int,
      hairBack: rawHairBack is int &&
          rawHairBack > 0
          ? rawHairBack
          : null,
      tattoo: rawTattoo is int && rawTattoo > 0
          ? rawTattoo
          : null,
    );
  }

  // ====================================================
  // DEBUG INFORMATION
  // ====================================================

  @override
  String toString() {
    return 'NpcAppearance('
        'seed: $seed, '
        'career: $career, '
        'outfit: $outfit, '
        'angle: ${angle.name}, '
        'skin: $skinTone, '
        'eyes: $eyes, '
        'eyebrows: $eyebrows, '
        'nose: $nose, '
        'mouth: $mouth, '
        'hairFront: $hairFront, '
        'hairBack: $hairBack, '
        'tattoo: $tattoo'
        ')';
  }
}
