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

}