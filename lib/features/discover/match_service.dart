
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'npc_persona.dart';

class MatchOutcome {
  final bool isMatch;
  final bool npcStarts;
  final String? firstMessage;

  const MatchOutcome({
    required this.isMatch,
    this.npcStarts = false,
    this.firstMessage,
  });
}

class OrbitMatch {
  final String npcId;
  final String name;
  final String archetype;
  final String preview;
  final bool unread;
  final Timestamp? matchedAt;

  const OrbitMatch({
    required this.npcId,
    required this.name,
    required this.archetype,
    required this.preview,
    required this.unread,
    required this.matchedAt,
  });

  factory OrbitMatch.fromDoc(
      QueryDocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    final data = doc.data();

    return OrbitMatch(
      npcId: doc.id,
      name: data['name'] as String? ?? 'Unknown',
      archetype: data['archetype'] as String? ?? '',
      preview: data['firstMessage'] as String? ??
          "It's a match! Say hello ✨",
      unread: data['npcStarts'] == true &&
          data['opened'] != true,
      matchedAt: data['matchedAt'] as Timestamp?,
    );
  }

  String get timeLabel {
    final date = matchedAt?.toDate();
    if (date == null) return 'New';

    if (DateTime.now().difference(date).inHours < 24) {
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }

    return '${date.day}/${date.month}';
  }
}

class MatchService {
  MatchService._();

  static final instance = MatchService._();

  final Random _random = Random();

  // Temporary probabilities.
  // Later: calculate matchChance from player + NPC traits.
  static const double matchChance = 0.55;
  static const double npcFirstChance = 0.50;

  CollectionReference<Map<String, dynamic>> get _matches {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      throw StateError('Player must be logged in.');
    }

    return FirebaseFirestore.instance
        .collection('players')
        .doc(uid)
        .collection('matches');
  }

  String _generateFirstMessage(NpcPersona npc) {
    final messages = switch (npc.archetype.id) {
      'golden_retriever' => [
        "Heyyy! I'm glad we matched! 💜",
        "Okay, hi! You seem really fun to talk to!",
      ],
      'black_cat' => [
        "You caught my attention. That's rare.",
        "Hello. Something about your profile intrigued me.",
      ],
      'sunshine' => [
        "Hey! What's the most exciting thing you did today?",
        "Hiii! Ready for a little adventure? ✨",
      ],
      'lover' => [
        "I'm really happy we found each other.",
        "Tell me something that makes you smile.",
      ],
      'quiet_genius' => [
        "Random question: do you believe in parallel universes?",
        "I have a theory about why we matched.",
      ],
      'wildcard' => [
        "So, would you run away to another planet with me?",
        "Tell me something unexpected about yourself.",
      ],
      'charming_tease' => [
        "You swiped right? Excellent taste, obviously.",
        "I was going to play it cool, but hey.",
      ],
      'gentle_soul' => [
        "Hi. How has your day been?",
        "I'm glad we crossed paths. ✨",
      ],
      _ => [
        "Hey, nice to meet you! 💜",
        "Looks like the universe brought us together.",
      ],
    };

    return messages[_random.nextInt(messages.length)];
  }

  Future<MatchOutcome> tryMatch(NpcPersona npc) async {
    final matched = _random.nextDouble() < matchChance;

    if (!matched) {
      return const MatchOutcome(isMatch: false);
    }

    final npcStarts = _random.nextDouble() < npcFirstChance;

    final firstMessage = npcStarts
        ? _generateFirstMessage(npc)
        : null;

    await _matches.doc(npc.id).set({
      'npcId': npc.id,
      'name': npc.name,
      'age': npc.age,
      'species': npc.species,
      'avatarIndex': npc.avatarIndex,
      'bio': npc.bio,
      'archetypeId': npc.archetype.id,
      'archetype': npc.archetype.name,
      'traits': npc.traits.map((t) => t.label).toList(),
      'npcStarts': npcStarts,
      'firstMessage': firstMessage,
      'opened': false,
      'matchedAt': FieldValue.serverTimestamp(),
    });

    return MatchOutcome(
      isMatch: true,
      npcStarts: npcStarts,
      firstMessage: firstMessage,
    );
  }

  Stream<List<OrbitMatch>> watchMatches() {
    return _matches
        .orderBy('matchedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
          .map(OrbitMatch.fromDoc)
          .toList(),
    );
  }

  Future<void> markOpened(String npcId) async {
    await _matches.doc(npcId).update({
      'opened': true,
    });
  }
}
