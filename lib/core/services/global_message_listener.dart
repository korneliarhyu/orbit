import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../features/chat/npc_chat_service.dart';
import '../../features/discover/match_service.dart';
import '../../features/chat/chat_screen.dart';

import '../utils/message_visibility.dart';
import '../utils/orbit_logger.dart';

import 'active_conversation_tracker.dart';
import 'orbit_notification_service.dart';

typedef _MessageDoc = QueryDocumentSnapshot<Map<String, dynamic>>;
typedef _MessageSnapshot = QuerySnapshot<Map<String, dynamic>>;

/// One foreground listener per app, scoped to the authenticated player.
class GlobalMessageListener with WidgetsBindingObserver {
  GlobalMessageListener({required this.navigatorKey});

  final GlobalKey<NavigatorState> navigatorKey;
  final _auth = FirebaseAuth.instance;
  final _notifications = OrbitNotificationService.instance;
  final _watches = <String, _ConversationWatch>{};

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<List<OrbitMatch>>? _matchesSubscription;
  String? _uid;
  DateTime? _sessionStart;
  Object? _sessionToken;
  bool _started = false;
  bool _foreground = false;

  void start() {
    if (_started) return;
    _started = true;
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    _authSubscription = _auth.authStateChanges().listen(
      (_) => _syncSession(),
      onError: (Object error) => _logError('auth', error),
    );
    _syncSession();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncSession();
  }

  void _syncSession() {
    if (!_started) return;
    final user = _auth.currentUser;
    final uid = _foreground && user != null && !user.isAnonymous
        ? user.uid
        : null;
    if (uid == _uid) return;
    _stopSession();
    // Also clear any first-match banner when the account changes or app pauses.
    _notifications.dismiss();
    if (uid == null) return;

    _uid = uid;
    _sessionStart = DateTime.now();
    final token = Object();
    _sessionToken = token;
    _matchesSubscription = MatchService.instance.watchMatches().listen((
      matches,
    ) {
      if (_isSession(token)) _updateMatches(matches, token);
    }, onError: (Object error) => _logError('matches', error));
  }

  bool _isSession(Object token) =>
      _started &&
      _foreground &&
      identical(_sessionToken, token) &&
      _uid != null &&
      _auth.currentUser?.uid == _uid;

  bool _isCurrent(_ConversationWatch watch, Object token) =>
      _isSession(token) && identical(_watches[watch.match.npcId], watch);

  void _updateMatches(List<OrbitMatch> matches, Object token) {
    final active = {
      for (final match in matches)
        if (!match.isEnded) match.npcId: match,
    };
    for (final npcId in _watches.keys.toList()) {
      if (!active.containsKey(npcId)) {
        final watch = _watches.remove(npcId)!;
        _notifications.dismiss(owner: watch);
        watch.dispose();
      }
    }
    for (final match in active.values) {
      final existing = _watches[match.npcId];
      if (existing != null) {
        existing.match = match;
        continue;
      }
      final watch = _ConversationWatch(match);
      _watches[match.npcId] = watch;
      _watchMessages(watch, token);
    }
  }

  void _watchMessages(_ConversationWatch watch, Object token) {
    final cutoff = Timestamp.fromDate(_sessionStart!);
    try {
      final ref = NpcChatService.instance.messagesRef(watch.match.npcId);
      // createdAt covers new messages, including legacy messages without displayAt.
      // displayAt also covers messages created before this foreground session
      // but scheduled to become visible during or after it.
      for (final field in ['createdAt', 'displayAt']) {
        final sub = ref
            .where(field, isGreaterThanOrEqualTo: cutoff)
            .snapshots(includeMetadataChanges: true)
            .listen(
              (snapshot) => _onSnapshot(watch, token, field, snapshot),
              onError: (Object error) => _logError('$field listener', error),
            );
        watch.subscriptions.add(sub);
      }
    } catch (error) {
      _logError('start message listener', error);
    }
  }

  void _onSnapshot(
    _ConversationWatch watch,
    Object token,
    String field,
    _MessageSnapshot snapshot,
  ) {
    if (!_isCurrent(watch, token) || snapshot.metadata.isFromCache) return;
    // Do not show speculative client writes. Wait for the server snapshot.
    final docs = <String, _MessageDoc>{
      for (final doc in snapshot.docs)
        if (!doc.metadata.hasPendingWrites) doc.id: doc,
    };
    if (field == 'createdAt') {
      watch.createdDocs = docs;
    } else {
      watch.displayDocs = docs;
    }
    // Both queries can return the same document. Merge by document ID.
    final combined = watch.documents;
    for (final id in watch.pending.keys.toList()) {
      if (!combined.containsKey(id)) watch.pending.remove(id)?.timer.cancel();
    }
    for (final doc in combined.values) {
      _schedule(watch, token, doc);
    }
  }

  DateTime? _revealAt(_MessageDoc doc) {
    return MessageVisibility.revealAt(doc.data());
  }

  bool _isEligible(_MessageDoc doc) {
    final data = doc.data();
    final text = data['text'];
    final at = _revealAt(doc);
    final start = _sessionStart;
    return data['sender'] == 'npc' &&
        text is String &&
        text.trim().isNotEmpty &&
        at != null &&
        start != null &&
        !at.isBefore(start);
  }

  void _schedule(_ConversationWatch watch, Object token, _MessageDoc doc) {
    if (watch.consumed.contains(doc.id)) return;
    if (!_isEligible(doc)) {
      watch.pending.remove(doc.id)?.timer.cancel();
      return;
    }
    final at = _revealAt(doc)!;
    final existing = watch.pending[doc.id];
    if (existing != null && existing.at == at) return;
    existing?.timer.cancel();
    watch.pending.remove(doc.id);
    final delay = at.difference(DateTime.now());
    if (delay <= Duration.zero) {
      _deliver(watch, token, doc.id);
      return;
    }
    final timer = Timer(delay, () {
      watch.pending.remove(doc.id);
      _deliver(watch, token, doc.id);
    });
    watch.pending[doc.id] = (at: at, timer: timer);
  }

  void _deliver(_ConversationWatch watch, Object token, String messageId) {
    if (!_isCurrent(watch, token) || watch.consumed.contains(messageId)) return;
    final doc = watch.documents[messageId];
    if (doc == null || !_isEligible(doc)) return;
    if (!MessageVisibility.isVisible(doc.data(), now: DateTime.now())) {
      _schedule(watch, token, doc);
      return;
    }

    watch.consumed.add(messageId);
    if (!_canShow(watch, token, messageId)) return;

    final overlay = navigatorKey.currentState?.overlay;
    if (overlay == null || !overlay.mounted) return;
    _notifications.show(
      overlay.context,
      targetOverlay: overlay,
      owner: watch,
      name: watch.match.name,
      avatarIndex: watch.match.avatarIndex,
      message: doc.data()['text'] as String,

      // Re-check at dequeue time, not just when the message arrives.
      shouldShow: () => _canShow(watch, token, messageId),
      // Global tap navigation
      onTap: () => _openConversation(watch, token),
    );
  }

  void _openConversation(_ConversationWatch watch, Object token) {
    if (!_isCurrent(watch, token) || watch.match.isEnded) {
      return;
    }

    final npcId = watch.match.npcId;

    if (ActiveConversationTracker.instance.isActive(npcId)) {
      return;
    }

    final navigator = navigatorKey.currentState;

    if (navigator == null || !navigator.mounted) return;

    navigator.pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => ChatScreen(npcId: npcId)),
      (route) => route.isFirst,
    );
  }

  bool _canShow(_ConversationWatch watch, Object token, String messageId) {
    if (!_isCurrent(watch, token) || watch.match.isEnded) return false;
    if (ActiveConversationTracker.instance.isActive(watch.match.npcId)) {
      return false;
    }

    final doc = watch.documents[messageId];
    if (doc == null || !_isEligible(doc)) return false;
    if (!MessageVisibility.isVisible(doc.data(), now: DateTime.now())) {
      return false;
    }

    // The two query streams can update at different times. A confirmed
    // playerReadAt from either stream is enough to suppress a queued banner.
    final created = watch.createdDocs[messageId];
    final displayed = watch.displayDocs[messageId];
    return created?.data()['playerReadAt'] is! Timestamp &&
        displayed?.data()['playerReadAt'] is! Timestamp;
  }

  void _stopSession() {
    _sessionToken = null;
    _uid = null;
    _sessionStart = null;
    unawaited(_matchesSubscription?.cancel());
    _matchesSubscription = null;
    for (final watch in _watches.values) {
      _notifications.dismiss(owner: watch);
      watch.dispose();
    }
    _watches.clear();
  }

  void _logError(String source, Object error) {
    OrbitLogger.debug('ORBIT notifications ($source): $error');
  }

  void dispose() {
    if (!_started) return;
    _started = false;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_authSubscription?.cancel());
    _authSubscription = null;
    _stopSession();
  }
}

class _ConversationWatch {
  _ConversationWatch(this.match);

  OrbitMatch match;
  final subscriptions = <StreamSubscription<_MessageSnapshot>>[];
  final consumed = <String>{};
  final pending = <String, ({DateTime at, Timer timer})>{};
  Map<String, _MessageDoc> createdDocs = {};
  Map<String, _MessageDoc> displayDocs = {};

  Map<String, _MessageDoc> get documents => {...createdDocs, ...displayDocs};

  void dispose() {
    for (final sub in subscriptions) {
      unawaited(sub.cancel());
    }
    for (final item in pending.values) {
      item.timer.cancel();
    }
    subscriptions.clear();
    pending.clear();
    consumed.clear();
    createdDocs.clear();
    displayDocs.clear();
  }
}
