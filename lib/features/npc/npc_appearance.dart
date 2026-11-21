
import 'dart:math';

import 'npc_outfit_generator.dart';

enum NpcAngle { front, left, right }

/// Visual identity for an ORBIT NPC.
///
/// Five asset categories:
/// faces, eyes, hair, noses, outfits.
class NpcAppearance {
  final int seed;
  final String career;
  final String outfit;
  final NpcAngle angle;

  final int face;
  final int eyes;
  final int hair;
  final int nose;
  final int outfitVariant;

  const NpcAppearance({
    required this.seed,
    required this.career,
    required this.outfit,
    this.angle = NpcAngle.front,
    required this.face,
    required this.eyes,
    required this.hair,
    required this.nose,
    required this.outfitVariant,
  });

  // =====================================================
  // ASSET CONFIGURATION
  // =====================================================

  static const String assetRoot =
      'lib/core/assets/npc';

  String get assetFolder => '$assetRoot/front';

  // =====================================================
  // LEGACY COMPATIBILITY
  // =====================================================

  @Deprecated('Use face instead')
  int get skinTone => face;

  @Deprecated('Use hair instead')
  int get hairFront => hair;

  @Deprecated('Eyes and eyebrows are a single asset now')
  int get eyebrows => eyes;

  @Deprecated('Mouth artwork is included in the face asset')
  int get mouth => face;

  @Deprecated('There is no independent back-hair layer')
  int? get hairBack => null;

  @Deprecated('Tattoos are not part of the five-layer asset pack')
  int? get tattoo => null;

  bool get hasHairBack => false;
  bool get hasTattoo => false;

  // =====================================================
  // RANDOM APPEARANCE GENERATOR
  // =====================================================

  /// Same seed produces the same generated selections.
  ///
  /// The avatar renderer maps these selections to
  /// the actual available assets.
  factory NpcAppearance.generate({
    required String career,
    required int seed,
  }) {
    final rng = Random(seed);

    int nextVariant() =>
        rng.nextInt(0x7fffffff) + 1;

    final face = nextVariant();
    final eyes = nextVariant();
    final hair = nextVariant();
    final nose = nextVariant();
    final outfitVariant = nextVariant();

    return NpcAppearance(
      seed: seed,
      career: career,
      outfit: NpcOutfitGenerator.generate(
        career,
        random: rng,
      ),
      face: face,
      eyes: eyes,
      hair: hair,
      nose: nose,
      outfitVariant: outfitVariant,
    );
  }

  // =====================================================
  // SERIALIZATION
  // =====================================================

  Map<String, dynamic> toJson() => {
    'seed': seed,
    'career': career,
    'outfit': outfit,
    'angle': angle.name,
    'face': face,
    'eyes': eyes,
    'hair': hair,
    'nose': nose,
    'outfitVariant': outfitVariant,
  };

  // =====================================================
  // DESERIALIZATION
  // =====================================================

  /// Supports older saved appearances.
  factory NpcAppearance.fromJson(
      Map<String, dynamic> json,
      ) {
    final seed = _readInt(json, ['seed']) ?? 0;

    final career =
        json['career']?.toString() ?? '';

    final fallback = NpcAppearance.generate(
      career: career,
      seed: seed,
    );

    final angleName =
        json['angle']?.toString() ?? 'front';

    final angle = NpcAngle.values.firstWhere(
          (value) => value.name == angleName,
      orElse: () => NpcAngle.front,
    );

    return NpcAppearance(
      seed: seed,
      career: career,
      outfit: json['outfit']?.toString() ??
          fallback.outfit,
      angle: angle,
      face: _readInt(
        json,
        ['face', 'skinTone'],
      ) ??
          fallback.face,
      eyes: _readInt(
        json,
        ['eyes'],
      ) ??
          fallback.eyes,
      hair: _readInt(
        json,
        ['hair', 'hairFront', 'hair_front'],
      ) ??
          fallback.hair,
      nose: _readInt(
        json,
        ['nose'],
      ) ??
          fallback.nose,
      outfitVariant: _readInt(
        json,
        ['outfitVariant', 'outfitIndex'],
      ) ??
          fallback.outfitVariant,
    );
  }

  // =====================================================
  // HELPERS
  // =====================================================

  static int? _readInt(
      Map<String, dynamic> json,
      List<String> keys,
      ) {
    for (final key in keys) {
      final value = json[key];

      if (value is int && value > 0) {
        return value;
      }

      if (value is num && value > 0) {
        return value.toInt();
      }

      if (value is String) {
        final parsed = int.tryParse(value);

        if (parsed != null && parsed > 0) {
          return parsed;
        }
      }
    }

    return null;
  }

  @override
  String toString() => 'NpcAppearance('
      'seed: $seed, '
      'career: $career, '
      'outfit: $outfit, '
      'face: $face, '
      'eyes: $eyes, '
      'hair: $hair, '
      'nose: $nose, '
      'outfitVariant: $outfitVariant'
      ')';
}
