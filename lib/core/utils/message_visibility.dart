import 'package:cloud_firestore/cloud_firestore.dart';

class MessageVisibility {
  MessageVisibility._();

  static DateTime? revealAt(Map<String, dynamic> message) {
    final displayAt = message['displayAt'];

    if (displayAt is Timestamp) {
      return displayAt.toDate();
    }

    final createdAt = message['createdAt'];

    if (createdAt is Timestamp) {
      return createdAt.toDate();
    }

    return null;
  }

  static bool isVisible(Map<String, dynamic> message, {required DateTime now}) {
    final at = revealAt(message);

    return at != null && !at.isAfter(now);
  }
}
