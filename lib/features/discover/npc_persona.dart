import 'dart:math';

enum NpcTrait {
  intellectual,
  playful,
  kind,
  adventurous,
  openMinded,
  mysterious,
  romantic,
  witty,
  serious,
}

extension NpcTraitLabel on NpcTrait {
  String get label => switch (this) {
    NpcTrait.intellectual => 'Intellectual',
    NpcTrait.playful => 'Playful',
    NpcTrait.kind => 'Kind',
    NpcTrait.adventurous => 'Adventurous',
    NpcTrait.openMinded => 'Open-minded',
    NpcTrait.mysterious => 'Mysterious',
    NpcTrait.romantic => 'Romantic',
    NpcTrait.witty => 'Witty',
    NpcTrait.serious => 'Serious',
  };
}

class NpcArchetype {
  final String id;
  final String name;
  final List<NpcTrait> signature;

  const NpcArchetype({
    required this.id,
    required this.name,
    required this.signature,
  });
}

const npcArchetypes = <NpcArchetype>[
  NpcArchetype(
    id: 'golden_retriever',
    name: 'Golden Retriever Boy',
    signature: [
      NpcTrait.playful,
      NpcTrait.kind,
      NpcTrait.romantic,
    ],
  ),
  NpcArchetype(
    id: 'black_cat',
    name: 'Black Cat Boy',
    signature: [
      NpcTrait.intellectual,
      NpcTrait.mysterious,
      NpcTrait.serious,
    ],
  ),
  NpcArchetype(
    id: 'sunshine',
    name: 'Sunshine Boy',
    signature: [
      NpcTrait.playful,
      NpcTrait.adventurous,
      NpcTrait.kind,
    ],
  ),
  NpcArchetype(
    id: 'lover',
    name: 'Lover Boy',
    signature: [
      NpcTrait.romantic,
      NpcTrait.kind,
      NpcTrait.openMinded,
    ],
  ),
  NpcArchetype(
    id: 'quiet_genius',
    name: 'Quiet Genius',
    signature: [
      NpcTrait.intellectual,
      NpcTrait.witty,
      NpcTrait.serious,
    ],
  ),
  NpcArchetype(
    id: 'wildcard',
    name: 'Wildcard Boy',
    signature: [
      NpcTrait.adventurous,
      NpcTrait.openMinded,
      NpcTrait.mysterious,
    ],
  ),
  NpcArchetype(
    id: 'charming_tease',
    name: 'Charming Tease',
    signature: [
      NpcTrait.witty,
      NpcTrait.playful,
      NpcTrait.romantic,
    ],
  ),
  NpcArchetype(
    id: 'gentle_soul',
    name: 'Gentle Soul',
    signature: [
      NpcTrait.kind,
      NpcTrait.openMinded,
      NpcTrait.serious,
    ],
  ),
];

class NpcPersona {
  final String id;
  final String name;
  final int age;
  final String species;
  final int avatarIndex;
  final String bio;
  final List<NpcTrait> traits;
  final NpcArchetype archetype;

  const NpcPersona({
    required this.id,
    required this.name,
    required this.age,
    required this.species,
    required this.avatarIndex,
    required this.bio,
    required this.traits,
    required this.archetype,
  });
}

class NpcGenerator {
  final Random _random = Random();
  int _counter = 0;

  static const _names = [
    'Kael', 'Aiden', 'Ren', 'Zayne',
    'Lucien', 'Orion', 'Elian', 'Kairo',
    'Riven', 'Noah', 'Atlas', 'Ash',
    'Soren', 'Cyrus', 'Niko', 'Levi',
  ];

  static const _species = [
    'Human',
    'Stellarian',
    'Lunarian',
    'Android',
    'Nebulite',
    'Velarian',
  ];

  NpcArchetype _classify(List<NpcTrait> traits) {
    var best = npcArchetypes.first;
    var bestScore = -1;

    for (final archetype in npcArchetypes) {
      final score = archetype.signature
          .where(traits.contains)
          .length;

      if (score > bestScore) {
        bestScore = score;
        best = archetype;
      }
    }

    return best;
  }


  static const Map<String, List<String>> _archetypeBios = {
    'golden_retriever': [
      "I'd cross three galaxies just to see you smile.",
      "I believe the best adventures start with a little kindness.",
    ],
    'black_cat': [
      "I prefer meaningful conversations over small talk.",
      "Not great at introductions. Better at conversations worth having.",
    ],
    'sunshine': [
      "Life is too short to stay in one orbit.",
      "I'm collecting memories from every corner of the galaxy.",
    ],
    'lover': [
      "I still believe the stars can bring two people together.",
      "Some connections are worth traveling light-years for.",
    ],
    'quiet_genius': [
      "I have a thousand theories and very few good pickup lines.",
      "The universe is fascinating. People are even more complicated.",
    ],
    'wildcard': [
      "I never know where I'll be tomorrow. That's the fun part.",
      "Rules are interesting. Breaking expectations is better.",
    ],
    'charming_tease': [
      "I'm probably going to tease you. Consider yourself warned.",
      "Good banter is my favorite kind of chemistry.",
    ],
    'gentle_soul': [
      "I believe everyone deserves a place to feel understood.",
      "Quiet moments can mean more than a thousand words.",
    ],
  };

  static const Map<NpcTrait, List<String>> _traitBios = {
    NpcTrait.intellectual: [
      "I can talk about the universe for hours.",
      "I'm always curious about how things work.",
    ],
    NpcTrait.playful: [
      "Life's better when there's someone to laugh with.",
      "I take my jokes very seriously.",
    ],
    NpcTrait.kind: [
      "I always try to make people feel at home.",
      "Little acts of kindness matter to me.",
    ],
    NpcTrait.adventurous: [
      "I never say no to a spontaneous adventure.",
      "There's always somewhere new worth exploring.",
    ],
    NpcTrait.openMinded: [
      "I love hearing perspectives different from mine.",
      "Surprise me with something I've never considered.",
    ],
    NpcTrait.mysterious: [
      "There's more to me than I let on.",
      "Some stories are better told in person.",
    ],
    NpcTrait.romantic: [
      "I'm a believer in the little romantic gestures.",
      "I remember the small things about someone special.",
    ],
    NpcTrait.witty: [
      "Sarcasm is practically my second language.",
      "A clever comeback might just win me over.",
    ],
    NpcTrait.serious: [
      "I value honesty and meaningful connections.",
      "I don't make promises I can't keep.",
    ],
  };

  String _generateBio(
      NpcArchetype archetype,
      List<NpcTrait> traits,
      ) {
    final intros = _archetypeBios[archetype.id]!;
    final intro = intros[_random.nextInt(intros.length)];

    final trait = traits[_random.nextInt(traits.length)];
    final endings = _traitBios[trait]!;
    final ending = endings[_random.nextInt(endings.length)];

    return '$intro $ending';
  }

  NpcPersona generate() {
    final traits = List<NpcTrait>.of(NpcTrait.values)
      ..shuffle(_random);

    // Each NPC has 2-3 unique personality tags.
    final selected = traits
        .take(2 + _random.nextInt(2))
        .toList();

    final archetype = _classify(selected);
    final bio = _generateBio(archetype, selected);


    return NpcPersona(
      id: 'npc_${DateTime.now().microsecondsSinceEpoch}_${_counter++}',
      name: _names[_random.nextInt(_names.length)],
      age: 21 + _random.nextInt(10),
      species: _species[_random.nextInt(_species.length)],
      avatarIndex: _random.nextInt(6),
      bio: bio,
      traits: selected,
      archetype: archetype,
    );
  }

  List<NpcPersona> generateBatch(int count) {
    return List.generate(count, (_) => generate());
  }
}
