import 'package:cloud_functions/cloud_functions.dart';

class AiService {
  AiService._();

  static final AiService instance = AiService._();

  Future<String> replyAsMika(String message) async {
    final functions = FirebaseFunctions.instanceFor(
      region: 'asia-southeast1',
    );

    final callable = functions.httpsCallable(
      'replyAsMika',
      options: HttpsCallableOptions(
        timeout: const Duration(seconds: 45),
      ),
    );

    final result = await callable.call({
      'message' : message,
    });

    final data = Map<String, dynamic>.from(
      result.data as Map,
    );

    return data['reply'] as String;
  }

  Future<bool> replyAsNpc({
    required String npcId,
    required String messageId,
  }) async {
    final callable = FirebaseFunctions.instanceFor(
      region: 'asia-southeast1',
    ).httpsCallable('replyAsNpc');

    final result = await callable.call({
      'npcId': npcId,
      'messageId': messageId,
    });

    final data = result.data;
    // Return false when another NPC reply batch is processing.
    // Return true when the backend accepts the request.
    if (data is Map && data['busy'] == true) {
      return false;
    }

    return true;
  }

}