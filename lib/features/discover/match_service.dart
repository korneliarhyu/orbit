import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'npc_persona.dart';
import 'npc_career.dart';

// ============================================================
// MATCH RESULT
// ============================================================
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

// ============================================================
// MATCH MODEL
// ============================================================
class OrbitMatch {
  final String npcId;
  final String name;
  final String archetype;
  final String? career;
  final String preview;
  final bool unread;
  final Timestamp? matchedAt;

  const OrbitMatch({
    required this.npcId,
    required this.name,
    required this.archetype,
    this.career,
    required this.preview,
    required this.unread,
    required this.matchedAt,
  });

  factory OrbitMatch.fromDoc(
      QueryDocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    final data = doc.data();

    final firstMessage = data['firstMessage'] as String?;

    return OrbitMatch(
      npcId: doc.id,
      name: data['name'] as String? ?? 'Unknown',
      archetype: data['archetype'] as String? ?? '',
      career: data['career'] as String?,
      preview: firstMessage != null && firstMessage.trim().isNotEmpty
          ? firstMessage
          : "It's a match! Say hello ✨",
      unread: data['npcStarts'] == true && data['opened'] != true,
      matchedAt: data['matchedAt'] as Timestamp?,
    );
  }

  String get timeLabel {
    final date = matchedAt?.toDate();

    if (date == null) return 'New';

    final difference = DateTime.now().difference(date);

    if (difference.inHours < 24) {
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');

      return '$hour:$minute';
    }

    return '${date.day}/${date.month}';
  }
}

// ============================================================
// MATCH SERVICE
// ============================================================
class MatchService {
  MatchService._();

  static final MatchService instance = MatchService._();

  final Random _random = Random();

  static const double matchChance = 0.55;
  static const double npcFirstChance = 0.50;

  // ----------------------------------------------------------
  // 1. FIRESTORE REFERENCES
  // ----------------------------------------------------------
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

  // ----------------------------------------------------------
  // 2. FIRST MESSAGE TEMPLATES
  // ----------------------------------------------------------
  static const Map<String, List<String>> _firstMessages = {
    'golden_retriever': [
      "Heyyy! I'm glad we matched! 💜",
      "Okay, hi! You seem really fun to talk to!",
    ],
    'black_cat': [
      "You caught my attention. That's rare.",
      "Hello. Something about your profile intrigued me.",
    ],
    'sunshine': [
      "Hey! What's the most exciting thing you did today?",
      "Hiii! Ready for a little adventure? ✨",
    ],
    'lover': [
      "I'm really happy we found each other.",
      "Tell me something that makes you smile.",
    ],
    'quiet_genius': [
      "Random question: do you believe in parallel universes?",
      "I have a theory about why we matched.",
    ],
    'wildcard': [
      "So, would you run away to another planet with me?",
      "Tell me something unexpected about yourself.",
    ],
    'charming_tease': [
      "You swiped right? Excellent taste, obviously.",
      "I was going to play it cool, but hey.",
    ],
    'gentle_soul': [
      "Hi. How has your day been?",
      "I'm glad we crossed paths. ✨",
    ],
  };

  static const List<String> _defaultMessages = [
    "Hey, nice to meet you! 💜",
    "Looks like the universe brought us together.",
  ];

  String _generateFirstMessage(NpcPersona npc) {
    final messages =
        _firstMessages[npc.archetype.id] ?? _defaultMessages;

    return messages[_random.nextInt(messages.length)];
  }

  // ----------------------------------------------------------
  // 3. INITIAL INTIMACY
  // ----------------------------------------------------------
  static Map<String, dynamic> _initialIntimacy() {
    return {
      'score': 0,
      'level': 1,
      'totalExchanges': 0,
      'activeDays': 0,
      'xpToday': 0,
      'lastActiveDay': null,
    };
  }

  // ----------------------------------------------------------
  // 4. MATCH GENERATION
  // ----------------------------------------------------------
  Future<MatchOutcome> tryMatch(NpcPersona npc) async {
    // Step 1: Determine whether a match occurs.
    final isMatch = _random.nextDouble() < matchChance;

    if (!isMatch) {
      return const MatchOutcome(isMatch: false);
    }

    // Step 2: Determine who starts the conversation.
    final npcStarts = _random.nextDouble() < npcFirstChance;

    final firstMessage = npcStarts
        ? _generateFirstMessage(npc)
        : null;

    // Step 3: Generate career based on NPC traits.
    // Weighted random keeps career varied, not deterministic.
    final career = NpcCareerGenerator.generate(npc.traits);

    // Step 4: Prepare Firestore reference.
    final matchRef = _matches.doc(npc.id);

    // Step 5: Save only if this match does not exist yet.
    return FirebaseFirestore.instance.runTransaction<MatchOutcome>((transaction) async {
        final existing = await transaction.get(matchRef);

        // Preserve an existing match and its career/intimacy.
        if (existing.exists) {
          final data = existing.data() ?? {};

          return MatchOutcome(
            isMatch: true,
            npcStarts: data['npcStarts'] == true,
            firstMessage: data['firstMessage'] as String?,
          );
        }

        transaction.set(matchRef, {
          // NPC identity
          'npcId': npc.id,
          'name': npc.name,
          'age': npc.age,
          'species': npc.species,
          'avatarIndex': npc.avatarIndex,
          'bio': npc.bio,

          // Personality
          'archetypeId': npc.archetype.id,
          'archetype': npc.archetype.name,
          'traits': npc.traits
              .map((trait) => trait.label)
              .toList(),

          // Career
          'career': career,

          // Chat state
          'npcStarts': npcStarts,
          'firstMessage': firstMessage,
          'opened': false,
          'matchedAt': FieldValue.serverTimestamp(),

          // Relationship progression
          'intimacy': _initialIntimacy(),
        });

        return MatchOutcome(
          isMatch: true,
          npcStarts: npcStarts,
          firstMessage: firstMessage,
        );
      },
    );
  }

  // ----------------------------------------------------------
  // 5. WATCH MATCHES (REAL-TIME)
  // ----------------------------------------------------------
  Stream<List<OrbitMatch>> watchMatches() {
    return _matches
        .orderBy('matchedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
          .map(OrbitMatch.fromDoc)
          .toList(growable: false),
    );
  }

  // ----------------------------------------------------------
  // 6. MARK CHAT AS OPENED
  // ----------------------------------------------------------
  Future<void> markOpened(String npcId) async {
    final matchRef = _matches.doc(npcId);

    await FirebaseFirestore.instance.runTransaction(
          (transaction) async {
        final snapshot = await transaction.get(matchRef);

        // No document: nothing to update.
        if (!snapshot.exists) return;

        // Already opened: skip the write.
        if (snapshot.data()?['opened'] == true) return;

        transaction.update(matchRef, {
          'opened': true,
        });
      },
    );
  }
}