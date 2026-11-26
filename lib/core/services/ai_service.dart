import 'package:cloud_functions/cloud_functions.dart';

// ======================================================
// ORBIT - AI SERVICE
// ======================================================
class AiService {
  AiService._();

  static final AiService instance = AiService._();

  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'asia-southeast1',
  );

  // ====================================================
  // GENERATE NPC REPLY
  // ====================================================
  Future<bool> replyAsNpc({
    required String npcId,
    required String messageId,
  }) async {
    final callable = _functions.httpsCallable(
      'replyAsNpc',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 70)),
    );

    final result = await callable.call({
      'npcId': npcId,
      'messageId': messageId,
    });

    final data = result.data;

    // Another reply batch is currently processing.
    if (data is Map && data['busy'] == true) {
      return false;
    }

    return true;
  }
}
