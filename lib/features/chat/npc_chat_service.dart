import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

// ======================================================
// ORBIT - NPC CHAT SERVICE
// ======================================================
class NpcChatService {
  NpcChatService._();

  static final NpcChatService instance = NpcChatService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'asia-southeast1',
  );

  static final RegExp _validId = RegExp(r'^[A-Za-z0-9_-]{1,140}$');

  // ====================================================
  // AUTHENTICATION & VALIDATION
  // ====================================================
  String get _uid {
    final user = _auth.currentUser;

    if (user == null || user.isAnonymous) {
      throw StateError('Please sign in first.');
    }

    return user.uid;
  }

  void _validateNpcId(String npcId) {
    if (!_validId.hasMatch(npcId)) {
      throw ArgumentError.value(npcId, 'npcId', 'Invalid NPC ID');
    }
  }

  // ====================================================
  // FIRESTORE REFERENCES
  // ====================================================
  DocumentReference<Map<String, dynamic>> matchRef(String npcId) {
    _validateNpcId(npcId);

    return _db.collection('players').doc(_uid).collection('matches').doc(npcId);
  }

  CollectionReference<Map<String, dynamic>> messagesRef(String npcId) {
    return matchRef(npcId).collection('messages');
  }

  // ====================================================
  // REAL-TIME STREAMS
  // ====================================================
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchMatch(String npcId) {
    return matchRef(npcId).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchMessages(String npcId) {
    return messagesRef(npcId).orderBy('createdAt').snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchLastMessage(String npcId) {
    return messagesRef(npcId)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots();
  }

  // ====================================================
  // SEND PLAYER MESSAGE
  // ====================================================
  Future<String> sendPlayerMessage({
    required String npcId,
    required String text,
  }) async {
    _validateNpcId(npcId);

    final cleanText = text.trim();

    if (cleanText.isEmpty || cleanText.length > 1000) {
      throw const FormatException('Message must contain 1–1000 characters.');
    }

    final callable = _functions.httpsCallable('sendPlayerMessage');

    final result = await callable.call({'npcId': npcId, 'text': cleanText});

    final data = result.data;

    if (data is! Map || data['messageId'] is! String) {
      throw StateError('Invalid response from sendPlayerMessage.');
    }

    return data['messageId'] as String;
  }

  // ====================================================
  // END RELATIONSHIP
  // ====================================================
  Future<void> endMatch(String npcId) async {
    _validateNpcId(npcId);

    await _functions.httpsCallable('endMatch').call({'npcId': npcId});
  }

  // ====================================================
  // MARK MESSAGE AS READ
  // ====================================================
  Future<void> markMessageAsRead(String npcId, String messageId) async {
    await messagesRef(npcId)
        .doc(messageId)
        .update({'playerReadAt': FieldValue.serverTimestamp()});
  }
}
