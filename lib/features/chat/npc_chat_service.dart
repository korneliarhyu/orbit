import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Firestore repository for conversations with matched NPCs.
/// A room is uniquely identified by the signed-in player's UID + npcId.

class NpcChatService {
  NpcChatService._();

  static final NpcChatService instance = NpcChatService._();

  String get _uid {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      throw StateError('Please sign in first.');
    }
    return user.uid;
  }

  DocumentReference<Map<String, dynamic>> matchRef(String npcId) {
    if (npcId.isEmpty || npcId.contains('/')) {
      throw ArgumentError.value(npcId, 'npcId', 'Invalid NPC ID');
    }

    return FirebaseFirestore.instance
        .collection('players')
        .doc(_uid)
        .collection('matches')
        .doc(npcId);
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchMatch(
      String npcId,
      ) => matchRef(npcId).snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> watchMessages(
      String npcId,
      ) => matchRef(npcId)
      .collection('messages')
      .orderBy('createdAt')
      .snapshots();

  Future<void> sendPlayerMessage({
    required String npcId,
    required String text,
  }) async {
    final message = text.trim();
    if (message.isEmpty || message.length > 1000) {
      throw FormatException('Message must contain 1–1000 characters.');
    }

    await matchRef(npcId).collection('messages').add({
      'sender': 'player',
      'text': message,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
