import 'dart:math';

import 'npc_persona.dart';

class NpcBioGenerator {
  NpcBioGenerator._();

  static final Random _random = Random();

  static String generate({
    required int age,
    required NpcArchetype archetype,
    required List<NpcTrait> traits,
    required String career,
    Random? random,
  }) {
    final rng = random ?? _random;

    // 1. Determine personality tendency.
    final playfulScore =
        (traits.contains(NpcTrait.playful) ? 2 : 0) +
            (traits.contains(NpcTrait.witty) ? 2 : 0) +
            (_playfulArchetypes.contains(archetype.id) ? 2 : 0);

    final seriousScore =
        (traits.contains(NpcTrait.serious) ? 2 : 0) +
            (traits.contains(NpcTrait.intellectual) ? 1 : 0) +
            (traits.contains(NpcTrait.mysterious) ? 1 : 0) +
            (_seriousArchetypes.contains(archetype.id) ? 2 : 0);

    final mature = age >= 30;

    final _BioTone tone;

    if (playfulScore > seriousScore + 1) {
      tone = _BioTone.playful;
    } else if (seriousScore > playfulScore + 1) {
      tone = _BioTone.serious;
    } else {
      tone = _BioTone.balanced;
    }

    // 2. Sometimes mention their actual career by 25%[0.25].
    // Not every bio should read like a resume.
    if (career.trim().isNotEmpty && rng.nextDouble() < 0.25) {
      final workBios = _careerBios(
        career.trim(),
        tone,
        mature,
      );

      return workBios[rng.nextInt(workBios.length)];
    }

    // 3. Otherwise, focus on personality and connection.
    final bios = switch ((tone, mature)) {
      (_BioTone.playful, false) => _youngPlayful,
      (_BioTone.playful, true) => _maturePlayful,
      (_BioTone.serious, false) => _youngSerious,
      (_BioTone.serious, true) => _matureSerious,
      (_BioTone.balanced, false) => _youngBalanced,
      (_BioTone.balanced, true) => _matureBalanced,
    };

    return bios[rng.nextInt(bios.length)];
  }

  // ==========================================================
  // PERSONALITY CLASSIFICATION
  // ==========================================================
  static const _playfulArchetypes = {
    'golden_retriever',
    'sunshine',
    'wildcard',
    'charming_tease',
  };

  static const _seriousArchetypes = {
    'black_cat',
    'quiet_genius',
  };

  // ==========================================================
  // YOUNG PLAYFUL — 20s
  // ==========================================================
  static const _youngPlayful = [
    "Are you sugar? Because you're sooo sweettt. Sorry 😭",
    "I promise I'm funnier in person. Probably.",
    "Fluent in memes, sarcasm, and questionable flirting.",
    "Looking for someone who laughs at my terrible jokes.",
    "Cute dates, good music, and a little harmless chaos?",
    "I had a clever bio planned, but then I got distracted.",
  ];

  // ==========================================================
  // MATURE PLAYFUL — 30+
  // ==========================================================
  static const _maturePlayful = [
    "I have my life together. My sleep schedule disagrees.",
    "Responsible adult, occasionally terrible decision-maker.",
    "I can cook, communicate, and make awful dad jokes.",
    "Old enough to know better. Still funny enough to try.",
    "Looking for good chemistry and someone to laugh with.",
    "My flirting skills are still a work in progress.",
  ];

  // ==========================================================
  // YOUNG SERIOUS — 20s
  // ==========================================================
  static const _youngSerious = [
    "Not great at small talk, but I'd love to hear your story.",
    "A little reserved at first. I open up around good people.",
    "Looking for someone I can genuinely connect with.",
    "I appreciate honesty, ambition, and meaningful talks.",
    "Building my future. Would be nice to share the journey.",
    "Quiet at first, but there's more to me than that.",
  ];

  // ==========================================================
  // MATURE SERIOUS — 30+
  // ==========================================================
  static const _matureSerious = [
    "Looking for something genuine. No need to rush.",
    "Life's been good. I'd love someone to share it with.",
    "I value consistency, kindness, and good conversations.",
    "I know what matters to me. Connection is one of them.",
    "Looking for someone to share the little things with.",
    "Not chasing perfection. Just something real.",
  ];

  // ==========================================================
  // YOUNG BALANCED — 20s
  // ==========================================================
  static const _youngBalanced = [
    "Here for good conversations and whatever feels natural.",
    "Tell me about something that makes you genuinely happy.",
    "Good playlists, long walks, and someone to talk to.",
    "A little shy at first, but I promise I have stories.",
    "Just hoping to meet someone I really click with.",
  ];

  // ==========================================================
  // MATURE BALANCED — 30+
  // ==========================================================
  static const _matureBalanced = [
    "Good coffee, quiet weekends, and interesting company.",
    "I enjoy the simple things. Better when shared.",
    "Big fan of honest conversations and comfortable silence.",
    "Hoping to find something easy, genuine, and meaningful.",
    "A good connection doesn't have to be complicated.",
  ];

  // ==========================================================
  // CAREER-AWARE BIOS
  // ==========================================================
  static List<String> _careerBios(
      String career,
      _BioTone tone,
      bool mature,
      ) {
    final article = RegExp(
      r'^[aeiou]',
      caseSensitive: false,
    ).hasMatch(career)
        ? 'an'
        : 'a';

    final profession = '$article $career';

    switch (tone) {
      case _BioTone.playful:
        return [
          "I'm $profession. My flirting skills? Under review.",
          "$career by day, professional overthinker after work.",
          "I work as $profession. Still terrible at writing bios.",
          mature
              ? "I have a career in $career. My humor? Questionable."
              : "Career: $career. Personality: still loading... ",
        ];

      case _BioTone.serious:
        return [
          "I'm $profession, but there's more to me than work.",
          "I work as $profession. Looking for a genuine connection.",
          "My career is in $career. I'd love to hear your story.",
          "Work keeps me busy, but I always make time for people.",
        ];

      case _BioTone.balanced:
        return [
          "I'm $profession. Outside work, I enjoy good company.",
          "$career is what I do. Getting to know people is the fun part.",
          "Work: $career. Free time: good food and better conversations.",
          "I'm $profession, hoping to find someone I click with.",
        ];
    }
  }
}

enum _BioTone {
  playful,
  serious,
  balanced,
}
