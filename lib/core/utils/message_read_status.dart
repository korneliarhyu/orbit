import 'package:cloud_firestore/cloud_firestore.dart';

import 'message_visibility.dart';

class MessageReadStatus {
  MessageReadStatus._();

  static bool isUnread(Map<String, dynamic> message, {required DateTime now}) {
    return message['sender'] == 'npc' &&
        MessageVisibility.isVisible(message, now: now) &&
        message['playerReadAt'] is! Timestamp;
  }

  static int countUnread(
    Iterable<Map<String, dynamic>> messages, {
    required DateTime now,
  }) {
    return messages.where((message) => isUnread(message, now: now)).length;
  }
}
