import 'package:flutter/widgets.dart';

class ActiveConversationTracker {
  ActiveConversationTracker._();

  static final ActiveConversationTracker instance =
      ActiveConversationTracker._();

  final _conversations =
      <Object, ({String npcId, ModalRoute<dynamic> route})>{};

  void register({
    required Object owner,
    required String npcId,
    required ModalRoute<dynamic>? route,
  }) {
    if (route == null) {
      unregister(owner);
      return;
    }

    _conversations[owner] = (npcId: npcId, route: route);
  }

  void unregister(Object owner) {
    _conversations.remove(owner);
  }

  String? get activeNpcId {
    for (final conversation in _conversations.values) {
      if (conversation.route.isCurrent) {
        return conversation.npcId;
      }
    }

    return null;
  }

  bool isActive(String npcId) => activeNpcId == npcId;
}
