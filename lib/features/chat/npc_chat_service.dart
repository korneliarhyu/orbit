import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

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

  // CHECK ALL NPC-PLAYER MESSAGE
  Stream<QuerySnapshot<Map<String, dynamic>>> watchMessages(
      String npcId,
      ) {
    return matchRef(npcId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots();
  }

  // GET ONLY LATEST MESSAGE
  Stream<QuerySnapshot<Map<String, dynamic>>> watchLastMessage(
      String npcId,
      ) {
    return matchRef(npcId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots();
  }

  Future<String> sendPlayerMessage({
    required String npcId,
    required String text,
  }) async {
    final cleanText = text.trim();

    if (cleanText.isEmpty || cleanText.length > 1000) {
      throw FormatException(
        'Message must contain 1–1000 characters.',
      );
    }

    final functions = FirebaseFunctions.instanceFor(
      region: 'asia-southeast1',
    );

    final callable = functions.httpsCallable('sendPlayerMessage');

    final result = await callable.call({
      'npcId': npcId,
      'text': cleanText,
    });

    final data = Map<String, dynamic>.from(result.data as Map);
    return data['messageId'] as String;
  }

  Future<void> endMatch(String npcId) async {
    final functions = FirebaseFunctions.instanceFor(
      region: 'asia-southeast1',
    );

    await functions.httpsCallable('endMatch').call({
      'npcId': npcId,
    });
  }
}
