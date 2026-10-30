import 'dart:math';
import 'npc_persona.dart';

class NpcCareerGenerator {
  NpcCareerGenerator._();

  static final Random _random = Random();

  // Affinity increases probability; it does not force a career.
  static const List<_Career> _careers = [
    _Career('Software Engineer', {
      NpcTrait.intellectual: 5,
      NpcTrait.serious: 2,
    }),
    _Career('Astronomer', {
      NpcTrait.intellectual: 4,
      NpcTrait.mysterious: 2,
    }),
    _Career('Doctor', {
      NpcTrait.kind: 4,
      NpcTrait.serious: 3,
    }),
    _Career('Photographer', {
      NpcTrait.adventurous: 3,
      NpcTrait.romantic: 2,
    }),
    _Career('Chef', {
      NpcTrait.playful: 2,
      NpcTrait.kind: 2,
      NpcTrait.romantic: 1,
    }),
    _Career('Pilot', {
      NpcTrait.adventurous: 4,
      NpcTrait.serious: 2,
    }),
    _Career('Music Producer', {
      NpcTrait.playful: 3,
      NpcTrait.witty: 2,
    }),
    _Career('Teacher', {
      NpcTrait.kind: 4,
      NpcTrait.intellectual: 2,
    }),
    _Career('Wildlife Researcher', {
      NpcTrait.openMinded: 3,
      NpcTrait.adventurous: 3,
    }),
    _Career('Journalist', {
      NpcTrait.witty: 3,
      NpcTrait.openMinded: 2,
    }),
    _Career('Architect', {
      NpcTrait.intellectual: 3,
      NpcTrait.serious: 2,
    }),
    _Career('Barista', {
      NpcTrait.playful: 2,
      NpcTrait.kind: 2,
    }),
    _Career('Game Designer', {
      NpcTrait.playful: 3,
      NpcTrait.intellectual: 2,
    }),
    _Career('Linguist', {
      NpcTrait.openMinded: 4,
      NpcTrait.intellectual: 3,
    }),
    _Career('Florist', {
      NpcTrait.romantic: 3,
      NpcTrait.kind: 3,
    }),
    _Career('Cybersecurity Analyst', {
      NpcTrait.mysterious: 3,
      NpcTrait.intellectual: 3,
    }),
    _Career('Paramedic', {
      NpcTrait.kind: 3,
      NpcTrait.adventurous: 2,
    }),
    _Career('Spacecraft Mechanic', {
      NpcTrait.adventurous: 3,
      NpcTrait.intellectual: 2,
    }),
    _Career('Starship Navigator', {
      NpcTrait.adventurous: 3,
      NpcTrait.serious: 2,
    }),
    _Career('Hologram Artist', {
      NpcTrait.romantic: 2,
      NpcTrait.openMinded: 3,
    }),
    _Career('Cafe Owner', {
      NpcTrait.kind: 2,
      NpcTrait.witty: 2,
    }),
    _Career('Marine Biologist', {
      NpcTrait.openMinded: 3,
      NpcTrait.adventurous: 2,
    }),
    _Career('Lawyer', {
      NpcTrait.serious: 3,
      NpcTrait.witty: 2,
    }),
    _Career('Writer', {
      NpcTrait.mysterious: 3,
      NpcTrait.romantic: 2,
    }),
    _Career('Athlete', {
      NpcTrait.adventurous: 3,
      NpcTrait.playful: 2,
    }),
    _Career('Diplomat', {
      NpcTrait.openMinded: 3,
      NpcTrait.witty: 2,
      NpcTrait.kind: 1,
    }),
    _Career('Data Analyst', {
      NpcTrait.intellectual: 4,
      NpcTrait.serious: 2,
    }),
    _Career('Fashion Designer', {
      NpcTrait.romantic: 2,
      NpcTrait.openMinded: 2,
      NpcTrait.playful: 2,
    }),
  ];

  static String generate(
      List<NpcTrait> traits, {
        Random? random,
      }) {
    final rng = random ?? _random;

    // 12% wildcard: any career can be chosen.
    if (rng.nextDouble() < 0.12) {
      return _careers[rng.nextInt(_careers.length)].name;
    }

    // All careers have a base chance.
    // Matching traits increase the selection weight.
    final weights = _careers.map((career) {
      final affinity = traits.fold<int>(
        0,
            (sum, trait) => sum + (career.affinities[trait] ?? 0),
      );

      return 3 + affinity;
    }).toList();

    final totalWeight = weights.reduce((a, b) => a + b);
    var ticket = rng.nextInt(totalWeight);

    // Weighted random selection.
    for (var i = 0; i < _careers.length; i++) {
      ticket -= weights[i];

      if (ticket < 0) {
        return _careers[i].name;
      }
    }

    return _careers.last.name;
  }
}

class _Career {
  final String name;
  final Map<NpcTrait, int> affinities;

  const _Career(this.name, this.affinities);
}
