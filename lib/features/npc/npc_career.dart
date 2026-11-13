import 'dart:math';
import 'npc_persona.dart';

class NpcCareerGenerator {
  NpcCareerGenerator._();

  static final Random _random = Random();

  static const double wildcardChance = 0.12;
  static const int baseWeight = 3;

  // Career name -> trait affinity weights.
  static const Map<String, Map<NpcTrait, int>> _careers = {
    'Software Engineer': {
      NpcTrait.intellectual: 5,
      NpcTrait.serious: 2,
    },
    'Astronomer': {
      NpcTrait.intellectual: 4,
      NpcTrait.mysterious: 2,
    },
    'Doctor': {
      NpcTrait.kind: 4,
      NpcTrait.serious: 3,
    },
    'Photographer': {
      NpcTrait.adventurous: 3,
      NpcTrait.romantic: 2,
    },
    'Chef': {
      NpcTrait.playful: 2,
      NpcTrait.kind: 2,
      NpcTrait.romantic: 1,
    },
    'Pilot': {
      NpcTrait.adventurous: 4,
      NpcTrait.serious: 2,
    },
    'Music Producer': {
      NpcTrait.playful: 3,
      NpcTrait.witty: 2,
    },
    'Teacher': {
      NpcTrait.kind: 4,
      NpcTrait.intellectual: 2,
    },
    'Wildlife Researcher': {
      NpcTrait.openMinded: 3,
      NpcTrait.adventurous: 3,
    },
    'Journalist': {
      NpcTrait.witty: 3,
      NpcTrait.openMinded: 2,
    },
    'Architect': {
      NpcTrait.intellectual: 3,
      NpcTrait.serious: 2,
    },
    'Barista': {
      NpcTrait.playful: 2,
      NpcTrait.kind: 2,
    },
    'Game Designer': {
      NpcTrait.playful: 3,
      NpcTrait.intellectual: 2,
    },
    'Linguist': {
      NpcTrait.openMinded: 4,
      NpcTrait.intellectual: 3,
    },
    'Florist': {
      NpcTrait.romantic: 3,
      NpcTrait.kind: 3,
    },
    'Cybersecurity Analyst': {
      NpcTrait.mysterious: 3,
      NpcTrait.intellectual: 3,
    },
    'Paramedic': {
      NpcTrait.kind: 3,
      NpcTrait.adventurous: 2,
    },
    'Spacecraft Mechanic': {
      NpcTrait.adventurous: 3,
      NpcTrait.intellectual: 2,
    },
    'Starship Navigator': {
      NpcTrait.adventurous: 3,
      NpcTrait.serious: 2,
    },
    'Hologram Artist': {
      NpcTrait.romantic: 2,
      NpcTrait.openMinded: 3,
    },
    'Cafe Owner': {
      NpcTrait.kind: 2,
      NpcTrait.witty: 2,
    },
    'Marine Biologist': {
      NpcTrait.openMinded: 3,
      NpcTrait.adventurous: 2,
    },
    'Lawyer': {
      NpcTrait.serious: 3,
      NpcTrait.witty: 2,
    },
    'Writer': {
      NpcTrait.mysterious: 3,
      NpcTrait.romantic: 2,
    },
    'Athlete': {
      NpcTrait.adventurous: 3,
      NpcTrait.playful: 2,
    },
    'Diplomat': {
      NpcTrait.openMinded: 3,
      NpcTrait.witty: 2,
      NpcTrait.kind: 1,
    },
    'Data Analyst': {
      NpcTrait.intellectual: 4,
      NpcTrait.serious: 2,
    },
    'Fashion Designer': {
      NpcTrait.romantic: 2,
      NpcTrait.openMinded: 2,
      NpcTrait.playful: 2,
    },
  };

  static String generate(
      List<NpcTrait> traits, {
        Random? random,
      }) {
    final rng = random ?? _random;
    final names = _careers.keys.toList(growable: false);

    // 12% chance of a completely random career.
    if (rng.nextDouble() < wildcardChance) {
      return names[rng.nextInt(names.length)];
    }

    // Calculate trait-based weights.
    final weights = [
      for (final affinity in _careers.values)
        baseWeight +
            traits.fold<int>(
              0,
                  (sum, trait) => sum + (affinity[trait] ?? 0),
            ),
    ];

    final totalWeight = weights.fold<int>(
      0,
          (sum, weight) => sum + weight,
    );

    // Weighted random selection.
    var ticket = rng.nextInt(totalWeight);

    for (var i = 0; i < names.length; i++) {
      ticket -= weights[i];

      if (ticket < 0) return names[i];
    }

    return names.last;
  }
}
