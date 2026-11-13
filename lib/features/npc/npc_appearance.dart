import 'dart:math';
import 'npc_outfit_generator.dart';

enum NpcAngle {
  left,
  front,
  right,
}

class NpcAppearance {
  final int seed;
  final String career;
  final String outfit;
  final NpcAngle angle;

  final int skinTone;
  final int faceShape;
  final int eyes;
  final int eyebrows;
  final int nose;
  final int mouth;
  final int hair;
  final int tattoo;

  const NpcAppearance({
    required this.seed,
    required this.career,
    required this.outfit,
    required this.angle,
    required this.skinTone,
    required this.faceShape,
    required this.eyes,
    required this.eyebrows,
    required this.nose,
    required this.mouth,
    required this.hair,
    required this.tattoo,
  });

  // Generate appearance once per NPC.
  factory NpcAppearance.generate({
    required String career,
    required int seed,
    List<NpcAngle> supportedAngles = const [
      NpcAngle.front,
    ],
  }) {
    if (supportedAngles.isEmpty) {
      throw ArgumentError('supportedAngles cannot be empty');
    }

    final rng = Random(seed);

    final angle = supportedAngles[
    rng.nextInt(supportedAngles.length)
    ];

    final skinTone = rng.nextInt(6) + 1;
    final faceShape = rng.nextInt(3) + 1;

    final eyes = rng.nextInt(6) + 1;
    final eyebrows = rng.nextInt(6) + 1;
    final nose = rng.nextInt(6) + 1;
    final mouth = rng.nextInt(6) + 1;

    // Hair uses matching back/front variants.
    final hair = rng.nextInt(8) + 1;

    // 45% chance of having a tattoo.
    final tattoo = rng.nextDouble() < 0.45
        ? rng.nextInt(8) + 1
        : 0;

    // Career-based outfit.
    final outfit = NpcOutfitGenerator.generate(
      career,
      random: rng,
    );

    return NpcAppearance(
      seed: seed,
      career: career,
      outfit: outfit,
      angle: angle,
      skinTone: skinTone,
      faceShape: faceShape,
      eyes: eyes,
      eyebrows: eyebrows,
      nose: nose,
      mouth: mouth,
      hair: hair,
      tattoo: tattoo,
    );
  }

  static const String assetRoot =
      'lib/core/assets/npc';

  static String _id(int value) =>
      value.toString().padLeft(2, '0');

  String get _root => '$assetRoot/${angle.name}';

  // Image order: back -> front.
  List<String> get layers => [
    '$_root/hair_back/hair_${_id(hair)}.png',

    '$_root/base/skin_${_id(skinTone)}.png',

    if (tattoo != 0)
      '$_root/tattoos/tattoo_${_id(tattoo)}.png',

    '$_root/outfits/$outfit.png',

    '$_root/eyes/eyes_${_id(eyes)}.png',

    '$_root/eyebrows/brows_${_id(eyebrows)}.png',

    '$_root/noses/nose_${_id(nose)}.png',

    '$_root/mouths/mouth_${_id(mouth)}.png',

    '$_root/hair_front/hair_${_id(hair)}.png',
  ];

  Map<String, dynamic> toJson() => {
    'seed': seed,
    'career': career,
    'outfit': outfit,
    'angle': angle.name,
    'skinTone': skinTone,
    'faceShape': faceShape,
    'eyes': eyes,
    'eyebrows': eyebrows,
    'nose': nose,
    'mouth': mouth,
    'hair': hair,
    'tattoo': tattoo,
  };

  factory NpcAppearance.fromJson(
      Map<String, dynamic> json,
      ) {
    return NpcAppearance(
      seed: json['seed'] as int,
      career: json['career'] as String,
      outfit: json['outfit'] as String,
      angle: NpcAngle.values.byName(
        json['angle'] as String,
      ),
      skinTone: json['skinTone'] as int,
      faceShape: json['faceShape'] as int,
      eyes: json['eyes'] as int,
      eyebrows: json['eyebrows'] as int,
      nose: json['nose'] as int,
      mouth: json['mouth'] as int,
      hair: json['hair'] as int,
      tattoo: json['tattoo'] as int,
    );
  }
}
