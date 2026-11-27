import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

// App-scoped reply dispatcher. A ChatScreen does not own its timers.
class AiService extends ChangeNotifier {
  AiService._() {
    _ownerUid = _auth.currentUser?.uid;
    _auth.authStateChanges().listen((_) => _syncOwner());
  }

  static final AiService instance = AiService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'asia-southeast1',
  );
  final _rooms = <String, _ReplyRoom>{};
  final _failures = StreamController<NpcReplyFailure>.broadcast();
  String? _ownerUid;

  static const _debounce = Duration(seconds: 2);
  static const _maxBusyRetries = 40;
  static const _maxErrorRetries = 3;

  Stream<NpcReplyFailure> get failures => _failures.stream;

  String? activeMessageId(String npcId) {
    if (_auth.currentUser?.uid != _ownerUid) return null;
    return _rooms[npcId]?.activeMessageId;
  }

  void _syncOwner() {
    final uid = _auth.currentUser?.uid;
    if (uid == _ownerUid) return;
    for (final room in _rooms.values) {
      room.timer?.cancel();
    }
    _rooms.clear();
    _ownerUid = uid;
    notifyListeners();
  }

  bool _isCurrent(String npcId, _ReplyRoom room) =>
      _ownerUid == room.uid &&
      _auth.currentUser?.uid == room.uid &&
      identical(_rooms[npcId], room);

  // The backend groups pending messages up to the newest trigger. Keep
  // the newest queued trigger while an earlier request is in flight.
  void queueReply({
    required String ownerUid,
    required String npcId,
    required String messageId,
  }) {
    _syncOwner();
    if (_ownerUid != ownerUid) return;
    final room = _rooms.putIfAbsent(npcId, () => _ReplyRoom(ownerUid));
    room.pendingMessageId = messageId;
    if (room.activeMessageId == null) {
      _schedule(npcId, room, _debounce);
    }
  }

  // Called after an explicit unmatch succeeds, never when a page closes.
  void cancelQueuedReply({required String ownerUid, required String npcId}) {
    _syncOwner();
    if (_ownerUid != ownerUid) return;
    final room = _rooms.remove(npcId);
    room?.timer?.cancel();
    if (room != null) notifyListeners();
  }

  void _schedule(String npcId, _ReplyRoom room, Duration delay) {
    if (!_isCurrent(npcId, room)) return;
    room.timer?.cancel();
    room.timer = Timer(delay, () {
      room.timer = null;
      unawaited(_flush(npcId, room));
    });
  }

  Future<void> _flush(String npcId, _ReplyRoom room) async {
    if (!_isCurrent(npcId, room) || room.activeMessageId != null) return;
    final messageId = room.pendingMessageId;
    if (messageId == null) return;

    room.pendingMessageId = null;
    room.activeMessageId = messageId;
    notifyListeners();
    var nextDelay = _debounce;
    Object? failure;

    try {
      final accepted = await replyAsNpc(npcId: npcId, messageId: messageId);
      if (!_isCurrent(npcId, room)) return;
      if (accepted) {
        room.busyRetries = 0;
        room.errorRetries = 0;
      } else if (room.busyRetries < _maxBusyRetries) {
        room.busyRetries++;
        room.pendingMessageId ??= messageId;
      } else {
        failure = StateError('NPC reply stayed busy; messages were saved.');
      }
    } catch (error) {
      if (!_isCurrent(npcId, room)) return;
      final retryable =
          error is FirebaseFunctionsException &&
          const {
            'unavailable',
            'deadline-exceeded',
            'aborted',
          }.contains(error.code);
      if (retryable && room.errorRetries < _maxErrorRetries) {
        room.errorRetries++;
        room.pendingMessageId ??= messageId;
        nextDelay = Duration(seconds: 1 << room.errorRetries);
      } else {
        failure = error;
      }
    } finally {
      // An old request must not mutate the queue of a different login.
      if (_isCurrent(npcId, room)) {
        room.activeMessageId = null;
        if (failure != null) {
          debugPrint('ORBIT NPC reply ($npcId): $failure');
          _failures.add(NpcReplyFailure(room.uid, npcId, failure));
          room.busyRetries = 0;
          room.errorRetries = 0;
        }
        if (room.pendingMessageId != null) {
          _schedule(npcId, room, nextDelay);
        } else {
          _rooms.remove(npcId);
        }
        notifyListeners();
      }
    }
  }

  // Existing callable contract remains unchanged.
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
    return !(data is Map && data['busy'] == true);
  }
}

class NpcReplyFailure {
  const NpcReplyFailure(this.uid, this.npcId, this.error);

  final String uid;
  final String npcId;
  final Object error;
}

class _ReplyRoom {
  _ReplyRoom(this.uid);

  final String uid;
  Timer? timer;
  String? pendingMessageId;
  String? activeMessageId;
  int busyRetries = 0;
  int errorRetries = 0;
}
