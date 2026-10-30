import 'dart:math';

import 'npc_persona.dart';
import 'npc_career.dart';
import 'npc_bio_generator.dart';

class NpcProfileGenerator {
  NpcProfileGenerator({
    NpcGenerator? identityGenerator,
    Random? random,
  })  : _identityGenerator = identityGenerator ?? NpcGenerator(),
        _random = random ?? Random();

  final NpcGenerator _identityGenerator;
  final Random _random;

  // Generate one complete NPC profile.
  NpcPersona generate() {
    final identity = _identityGenerator.generate();

    final career = NpcCareerGenerator.generate(
      identity.traits,
      random: _random,
    );

    final bio = NpcBioGenerator.generate(
      age: identity.age,
      archetype: identity.archetype,
      traits: identity.traits,
      career: career,
      random: _random,
    );

    return NpcPersona(
      id: identity.id,
      name: identity.name,
      age: identity.age,
      species: identity.species,
      avatarIndex: identity.avatarIndex,
      traits: identity.traits,
      archetype: identity.archetype,
      career: career,
      bio: bio,
    );
  }

  // Generate a mutable deck for Discover.
  List<NpcPersona> generateBatch(int count) {
    return List.generate(
      count,
          (_) => generate(),
      growable: true,
    );
  }
}
