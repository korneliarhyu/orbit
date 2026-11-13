import 'dart:math';

class NpcOutfitGenerator {
  NpcOutfitGenerator._();

  static final Random _random = Random();
  // Career -> available outfit variations.
  static const Map<String, List<String>> careerOutfits = {
    'Software Engineer': [
      'hoodie',
      'graphic_tee',
    ],
    'Astronomer': [
      'turtleneck',
      'lab_coat',
    ],
    'Doctor': [
      'medical_scrubs',
      'lab_coat',
    ],
    'Photographer': [
      'field_jacket',
      'graphic_tee',
    ],
    'Chef': [
      'chef_jacket',
      'apron',
    ],
    'Pilot': [
      'pilot_uniform',
      'oxford_shirt',
    ],
    'Music Producer': [
      'graphic_tee',
      'leather_jacket',
    ],
    'Teacher': [
      'knit_sweater',
      'oxford_shirt',
    ],
    'Wildlife Researcher': [
      'field_jacket',
      'utility_jacket',
    ],
    'Journalist': [
      'field_jacket',
      'oxford_shirt',
    ],
    'Architect': [
      'turtleneck',
      'blazer',
    ],
    'Barista': [
      'apron',
      'graphic_tee',
    ],
    'Game Designer': [
      'hoodie',
      'graphic_tee',
    ],
    'Linguist': [
      'knit_sweater',
      'oxford_shirt',
    ],
    'Florist': [
      'apron',
      'knit_sweater',
    ],
    'Cybersecurity Analyst': [
      'hoodie',
      'turtleneck',
    ],
    'Paramedic': [
      'medical_scrubs',
      'utility_jacket',
    ],
    'Spacecraft Mechanic': [
      'utility_jacket',
      'graphic_tee',
    ],
    'Starship Navigator': [
      'pilot_uniform',
      'utility_jacket',
    ],
    'Hologram Artist': [
      'graphic_tee',
      'turtleneck',
    ],
    'Cafe Owner': [
      'apron',
      'oxford_shirt',
    ],
    'Marine Biologist': [
      'field_jacket',
      'lab_coat',
    ],
    'Lawyer': [
      'blazer',
      'oxford_shirt',
    ],
    'Writer': [
      'knit_sweater',
      'turtleneck',
    ],
    'Athlete': [
      'sports_jersey',
      'graphic_tee',
    ],
    'Diplomat': [
      'blazer',
      'oxford_shirt',
    ],
    'Data Analyst': [
      'oxford_shirt',
      'hoodie',
    ],
    'Fashion Designer': [
      'turtleneck',
      'leather_jacket',
    ],
  };

  static String generate(
      String career, {
        Random? random,
      }) {
    final rng = random ?? _random;

    final outfits = careerOutfits[career] ??
        const ['graphic_tee'];

    return outfits[rng.nextInt(outfits.length)];
  }

  static List<String> getAvailableOutfits(String career) {
    return List.unmodifiable(
      careerOutfits[career] ?? const ['graphic_tee'],
    );
  }

  static bool supportsCareer(String career) {
    return careerOutfits.containsKey(career);
  }
}
