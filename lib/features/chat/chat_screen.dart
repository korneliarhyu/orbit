import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_radius.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_avatar.dart';
import '../../core/widgets/app_icon_button.dart';
import '../../core/services/ai_service.dart';
import '../../core/services/active_conversation_tracker.dart';
import '../../core/utils/message_visibility.dart';
import '../../core/utils/message_read_status.dart';
import '../../core/utils/orbit_logger.dart';
import '../discover/match_service.dart';
import 'npc_chat_service.dart';

// ======================================================
// ORBIT - LUNAR LAVENDER CHAT SCREEN
// ======================================================
class ChatScreen extends StatefulWidget {
  final String npcId;

  const ChatScreen({super.key, required this.npcId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

// ======================================================
// CHAT SCREEN STATE
// ======================================================

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final TextEditingController _controller = TextEditingController();

  final ScrollController _scrollController = ScrollController();

  Stream<DocumentSnapshot<Map<String, dynamic>>>? _matchStream;

  Stream<QuerySnapshot<Map<String, dynamic>>>? _messagesStream;

  bool _sending = false;

  int _previousMessageCount = -1;

  StreamSubscription<NpcReplyFailure>? _replyFailureSubscription;
  Timer? _revealTimer;

  DateTime? _nextReveal;
  static const _typingWindow = Duration(seconds: 3);

  final _readWrites = <String>{};
  final _markedRead = <String>{};
  String? _readOwnerUid;
  bool _openingMatch = false;
  bool _openedMatch = false;

  final _ai = AiService.instance;

  // ====================================================
  // INITIALIZATION
  // ====================================================
  @override
  void initState() {
    super.initState();
    _readOwnerUid = FirebaseAuth.instance.currentUser?.uid;
    WidgetsBinding.instance.addObserver(this);

    final service = NpcChatService.instance;

    _matchStream = service.watchMatch(widget.npcId);
    _messagesStream = service.watchMessages(widget.npcId);
    _ai.addListener(_onReplyStateChanged);
    _replyFailureSubscription = _ai.failures.listen(_onReplyFailure);
  }

  void _onReplyStateChanged() {
    if (mounted) setState(() {});
  }

  void _onReplyFailure(NpcReplyFailure failure) {
    if (failure.uid != _readOwnerUid ||
        failure.npcId != widget.npcId ||
        !_canMarkRead) {
      return;
    }
    OrbitLogger.error('NPC reply failed', error: failure.error);
    final error = failure.error;
    if (error is FirebaseFunctionsException &&
        error.code == 'resource-exhausted') {
      final details = error.details;
      final reason = details is Map ? details['reason'] : null;
      if (reason == 'ai_daily_quota') {
        _showChatNotice('Daily demo limit reached. Your messages are saved.');
        return;
      }
      if (reason == 'ai_rate_limit') {
        _showChatNotice('Your messages are saved. Try again in a moment.');
        return;
      }
    }
    _showChatNotice(
      'Your messages are saved. Your companion could not reply right now.',
    );
  }

  // Keep technical details out of user-facing notifications.
  void _showChatNotice(String message) {
    if (!_canMarkRead) return;

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.elevatedSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: const BorderSide(color: AppColors.border),
        ),
        content: Text(message, style: AppTextStyles.body),
      ),
    );
  }

  String _sendErrorMessage(Object error) {
    if (error is FirebaseFunctionsException) {
      switch (error.code) {
        case 'resource-exhausted':
          return 'Slow down a little. Try again shortly.';
        case 'unauthenticated':
          return 'Your session has expired. Please sign in again.';
        case 'failed-precondition':
          return 'This conversation is no longer active.';
        case 'not-found':
          return 'This conversation is no longer available.';
        case 'unavailable':
        case 'deadline-exceeded':
          return 'Could not confirm delivery. Check your connection.';
        case 'invalid-argument':
          return 'Check your message and try again.';
        case 'permission-denied':
          return 'You cannot send messages to this conversation.';
      }
    }

    return 'Could not send your message. Please try again.';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    ActiveConversationTracker.instance.register(
      owner: this,
      npcId: widget.npcId,
      route: ModalRoute.of(context),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (mounted && state == AppLifecycleState.resumed) {
      setState(() {});
    }
  }

  bool get _canMarkRead {
    if (!mounted ||
        _readOwnerUid == null ||
        FirebaseAuth.instance.currentUser?.uid != _readOwnerUid) {
      return false;
    }
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    return (lifecycle == null || lifecycle == AppLifecycleState.resumed) &&
        ModalRoute.of(context)?.isCurrent == true &&
        ActiveConversationTracker.instance.isActive(widget.npcId);
  }

  // Run only after the visible conversation has been built.
  void _queueReadTracking(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> documents, {
    required bool markFirstMessage,
  }) {
    final now = DateTime.now();
    final unread = documents
        .where(
          (doc) =>
              !doc.metadata.hasPendingWrites &&
              !_readWrites.contains(doc.id) &&
              !_markedRead.contains(doc.id) &&
              MessageReadStatus.isUnread(doc.data(), now: now),
        )
        .toList();
    if (unread.isEmpty &&
        (!markFirstMessage || _openingMatch || _openedMatch)) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_canMarkRead) return;
      if (markFirstMessage && !_openingMatch && !_openedMatch) {
        unawaited(_markFirstMessageRead());
      }
      for (final doc in unread) {
        if (!_canMarkRead) break;
        if (_markedRead.contains(doc.id) || !_readWrites.add(doc.id)) continue;
        unawaited(_markNpcMessageRead(doc.id));
      }
    });
  }

  Future<void> _markNpcMessageRead(String messageId) async {
    try {
      await NpcChatService.instance.markMessageAsRead(widget.npcId, messageId);
      _markedRead.add(messageId);
    } catch (error) {
      OrbitLogger.debug('ORBIT mark message read: $error');
    } finally {
      _readWrites.remove(messageId);
    }
  }

  Future<void> _markFirstMessageRead() async {
    _openingMatch = true;
    try {
      await MatchService.instance.markOpened(widget.npcId);
      _openedMatch = true;
    } catch (error) {
      OrbitLogger.debug('ORBIT mark first message read: $error');
    } finally {
      _openingMatch = false;
    }
  }

  // ====================================================
  // SCROLL HANDLING
  // ====================================================
  void _scrollToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }

      final target = _scrollController.position.maxScrollExtent;

      if (jump) {
        _scrollController.jumpTo(target);
      } else {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ====================================================
  // SEND PLAYER MESSAGE
  // ====================================================
  Future<void> _sendMessage() async {
    final text = _controller.text.trim();

    if (text.isEmpty || _sending) return;
    final ownerUid = FirebaseAuth.instance.currentUser?.uid;
    if (ownerUid == null || ownerUid != _readOwnerUid) return;
    final npcId = widget.npcId;

    // Firestore NPC chat
    setState(() => _sending = true);

    try {
      final messageId = await NpcChatService.instance.sendPlayerMessage(
        npcId: npcId,
        text: text,
      );

      // Schedule even if the player left while the send was in flight.
      _ai.queueReply(ownerUid: ownerUid, npcId: npcId, messageId: messageId);

      if (!mounted) return;

      if (_controller.text.trim() == text) {
        _controller.clear();
      }

      _scrollToBottom();
    } catch (error, stackTrace) {
      OrbitLogger.error(
        'Send player message failed',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;

      _showChatNotice(_sendErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  // ====================================================
  // UNMATCH NPC
  // ====================================================
  Future<void> _confirmUnmatch() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text(
            'End this connection?',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: const Text(
            'This conversation will end. '
            'You can still read the chat history.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Keep chatting'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Unmatch'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await NpcChatService.instance.endMatch(widget.npcId);

      final ownerUid = _readOwnerUid;
      if (ownerUid != null) {
        _ai.cancelQueuedReply(ownerUid: ownerUid, npcId: widget.npcId);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Connection ended.')));
    } catch (error, stackTrace) {
      OrbitLogger.error(
        'End match failed',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;

      _showChatNotice('Could not end this connection. Please try again.');
    }
  }

  // ====================================================
  // SCHEDULE NPC MESSAGE REVEAL
  // ====================================================
  void _scheduleReveal(DateTime? revealAt) {
    if (_nextReveal == revealAt) return;

    _revealTimer?.cancel();
    _nextReveal = revealAt;

    if (revealAt == null) return;

    final delay = revealAt.difference(DateTime.now());

    _revealTimer = Timer(
      delay.isNegative
          ? Duration.zero
          : delay + const Duration(milliseconds: 30),
      () {
        _nextReveal = null;

        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  // ====================================================
  // DISPOSE
  // ====================================================
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ActiveConversationTracker.instance.unregister(this);

    _ai.removeListener(_onReplyStateChanged);
    unawaited(_replyFailureSubscription?.cancel());
    _revealTimer?.cancel();

    _controller.dispose();
    _scrollController.dispose();

    super.dispose();
  }

  // ====================================================
  // MAIN SCREEN
  // ====================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The shared MaterialApp background provides the subtle cosmic texture.
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: SafeArea(child: _buildNpcRoom()),
    );
  }

  // ====================================================
  // NPC FIRESTORE ROOM
  // ====================================================
  Widget _buildNpcRoom() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _matchStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _status(
            'Cannot load this match. '
            'Check your connection.',
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        final document = snapshot.data!;

        if (!document.exists) {
          return _status('Match not found.');
        }

        final npc = document.data()!;

        final name = npc['name'] as String? ?? 'Traveler';

        final age = (npc['age'] as num?)?.toInt();

        final career = (npc['career'] as String?)?.trim();

        final species = (npc['species'] as String?)?.trim();

        final avatarIndex = OrbitAvatar.indexFromMatchData(npc);

        final displayName = age == null ? name : '$name, $age';

        final subtitle = [
          if (career != null && career.isNotEmpty) career,
          if (species != null && species.isNotEmpty) species,
        ].join(' · ');

        final intimacy = npc['intimacy'];

        final rawScore = intimacy is Map ? intimacy['score'] : null;

        final score = rawScore is num
            ? rawScore.toDouble().clamp(0.0, 100.0).toDouble()
            : 0.0;

        final status = npc['relationshipStatus'] as String? ?? 'active';

        final ended = status != 'active';

        return _roomLayout(
          name: displayName,
          subtitle: subtitle,
          avatarIndex: avatarIndex,
          intimacyLabel: _resolveIntimacyLabel(score),
          ended: ended,
          endedByNpc: status == 'unmatched_npc',
          content: _buildNpcMessages(npc, ended: ended),
        );
      },
    );
  }

  // ====================================================
  // SHARED CHAT ROOM LAYOUT
  // ====================================================
  Widget _roomLayout({
    required String name,
    required String subtitle,
    required Widget content,
    int? avatarIndex,
    String? intimacyLabel,
    bool ended = false,
    bool endedByNpc = false,
  }) {
    return Column(
      children: [
        _buildHeader(
          name,
          subtitle,
          avatarIndex: avatarIndex,
          intimacyLabel: intimacyLabel,
          ended: ended,
        ),

        Expanded(child: content),

        if (ended) _endedChatBanner(endedByNpc) else _buildInput(name),
      ],
    );
  }

  // ====================================================
  // STATUS MESSAGE
  // ====================================================
  Widget _status(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMuted,
        ),
      ),
    );
  }

  // ====================================================
  // NPC'S LABEL
  // ====================================================
  String _resolveIntimacyLabel(double score) {
    if (score >= 80) return 'Deep Bond';
    if (score >= 60) return 'Close';
    if (score >= 40) return 'Comfortable';
    if (score >= 20) return 'Getting Closer';

    return 'Strangers';
  }

  void _openCharacterProfile() {
    _showComingSoon('Character profile');
  }

  Widget _intimacyBadge(String label) {
    return Semantics(
      label: 'Intimacy: $label',
      excludeSemantics: true,
      child: Text(
        '✦  $label',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.badge,
      ),
    );
  }

  Widget _buildHeader(
    String name,
    String subtitle, {
    int? avatarIndex,
    String? intimacyLabel,
    bool ended = false,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.94),
        border: const Border(
          bottom: BorderSide(color: AppColors.border, width: 0.6),
        ),
      ),
      child: Row(
        children: [
          OrbitIconButton(
            tooltip: 'Back',
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.maybePop(context),
            variant: OrbitIconButtonVariant.ghost,
            size: 48,
            iconSize: 19,
          ),
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: Tooltip(
                message: 'View character profile',
                child: InkWell(
                  onTap: _openCharacterProfile,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xs,
                    ),
                    child: Row(
                      children: [
                        OrbitAvatar(
                          name: name,
                          avatarIndex: avatarIndex,
                          size: 48,
                        ),
                        const SizedBox(width: AppSpacing.avatarGap),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.title,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                ended
                                    ? 'Connection ended'
                                    : subtitle.isNotEmpty
                                    ? subtitle
                                    : 'AI Companion',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.caption,
                              ),
                              if (intimacyLabel != null && !ended) ...[
                                const SizedBox(height: AppSpacing.xs),
                                _intimacyBadge(intimacyLabel),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          if (!ended)
            OrbitIconButton(
              tooltip: 'Unmatch',
              icon: Icons.link_off_rounded,
              onTap: _confirmUnmatch,
              variant: OrbitIconButtonVariant.ghost,
              size: 48,
              iconSize: 22,
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$feature coming soon in ORBIT.')));
  }

  // ====================================================
  // WATCH NPC MESSAGES
  // ====================================================
  Widget _buildNpcMessages(Map<String, dynamic> npc, {required bool ended}) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _messagesStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _status('Could not load messages.');
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        final documents = snapshot.data!.docs;
        final entries = <_ChatEntry>[];

        // Initial match message
        final first = npc['firstMessage'] as String?;

        if (npc['npcStarts'] == true && first != null && first.isNotEmpty) {
          final matchedAt = npc['matchedAt'];

          entries.add(
            _ChatEntry(
              text: first,
              isMine: false,
              at: matchedAt is Timestamp ? matchedAt.toDate() : null,
            ),
          );
        }

        // Find current reply batch and read status.
        String? awaitingBatchId;
        bool awaitingMessageRead = false;

        final awaitingReplyToMessageId = _ai.activeMessageId(widget.npcId);
        if (awaitingReplyToMessageId != null) {
          for (final doc in documents) {
            if (doc.id == awaitingReplyToMessageId) {
              final data = doc.data();

              awaitingMessageRead = data['readAt'] is Timestamp;

              final batchId = data['replyBatchId'];

              if (batchId is String &&
                  batchId.isNotEmpty &&
                  batchId != 'legacy') {
                awaitingBatchId = batchId;
              }

              break;
            }
          }
        }

        DateTime? upcomingReveal;
        DateTime? upcomingNpcReveal;
        bool hasVisibleReply = false;

        final now = DateTime.now();

        // Apply the same reveal-time rules as Inbox.
        for (final doc in documents) {
          final message = doc.data();
          final at = MessageVisibility.revealAt(message);
          if (at == null) continue;

          if (at.isAfter(now)) {
            if (upcomingReveal == null || at.isBefore(upcomingReveal)) {
              upcomingReveal = at;
            }
            if (message['sender'] == 'npc' &&
                (upcomingNpcReveal == null || at.isBefore(upcomingNpcReveal))) {
              upcomingNpcReveal = at;
            }
            continue;
          }

          if (awaitingBatchId != null &&
              message['sender'] == 'npc' &&
              message['inReplyTo'] == awaitingBatchId) {
            hasVisibleReply = true;
          }

          entries.add(
            _ChatEntry(
              text: message['text'] as String? ?? '',
              isMine: message['sender'] == 'player',
              at: at,
              deliveryStatus: _resolveDeliveryStatus(message),
            ),
          );
        }

        // A message created earlier can be revealed after a newer message.
        // Sort by visible time, preserving the original order for ties.
        final chronological = entries.indexed.toList()
          ..sort((a, b) {
            final aTime = a.$2.at;
            final bTime = b.$2.at;
            final order = aTime == null
                ? (bTime == null ? 0 : -1)
                : (bTime == null ? 1 : aTime.compareTo(bTime));
            return order == 0 ? a.$1.compareTo(b.$1) : order;
          });
        final visibleEntries = chronological.map((item) => item.$2).toList();

        // Wake up both when typing should start and when a message is due.
        final typingAt = upcomingNpcReveal?.subtract(_typingWindow);
        final scheduledTyping = typingAt != null && !typingAt.isAfter(now);
        var nextRefresh = upcomingReveal;
        if (!ended &&
            typingAt != null &&
            typingAt.isAfter(now) &&
            (nextRefresh == null || typingAt.isBefore(nextRefresh))) {
          nextRefresh = typingAt;
        }
        _scheduleReveal(nextRefresh);

        // Preserve normal AI typing while a read message is being processed,
        // but do not show it throughout a long scheduled delay.
        final reactiveTyping =
            upcomingNpcReveal == null &&
            awaitingReplyToMessageId != null &&
            awaitingMessageRead &&
            !hasVisibleReply;
        final showTyping = !ended && (reactiveTyping || scheduledTyping);

        // Auto-scroll when a message becomes visible.
        if (_previousMessageCount != visibleEntries.length) {
          _previousMessageCount = visibleEntries.length;
          _scrollToBottom();
        }

        _queueReadTracking(
          documents,
          markFirstMessage:
              npc['npcStarts'] == true &&
              first != null &&
              first.isNotEmpty &&
              npc['opened'] != true,
        );

        return _messageList(
          visibleEntries,
          companionName: npc['name'] as String? ?? 'NPC',
          avatarIndex: OrbitAvatar.indexFromMatchData(npc),
          typingName: showTyping ? npc['name'] as String? ?? 'NPC' : null,
        );
      },
    );
  }

  // ====================================================
  // MESSAGE LIST WITH DATE SEPARATORS
  // ====================================================
  Widget _messageList(
    List<_ChatEntry> entries, {
    required String companionName,
    int? avatarIndex,
    String? typingName,
  }) {
    if (entries.isEmpty && typingName == null) {
      return _status("It's a match! Say hello 💜");
    }

    return ListView.builder(
      controller: _scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      itemCount: entries.length + (typingName == null ? 0 : 1),
      itemBuilder: (context, index) {
        if (index == entries.length) {
          return _TypingBubble(name: typingName!, avatarIndex: avatarIndex);
        }

        final entry = entries[index];

        final previous = index == 0 ? null : entries[index - 1];

        final showDate =
            entry.at != null &&
            (previous?.at == null || !_sameDay(previous!.at!, entry.at!));

        return Column(
          children: [
            if (showDate) _datePill(_dateLabel(entry.at!)),

            _buildMessageBubble(
              entry,
              companionName: companionName,
              avatarIndex: avatarIndex,
            ),
          ],
        );
      },
    );
  }

  // ====================================================
  // DATE HELPERS
  // ====================================================
  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _dateLabel(DateTime date) {
    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);

    final day = DateTime(date.year, date.month, date.day);

    if (day == today) {
      return 'Today';
    }

    if (day == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    }

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${date.day} '
        '${months[date.month - 1]} '
        '${date.year}';
  }

  Widget _datePill(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Expanded(child: Divider(color: AppColors.border)),
          const SizedBox(width: 12),
          Text('✦', style: TextStyle(color: AppColors.primary, fontSize: 11)),
          const SizedBox(width: 8),
          Text(label, style: AppTextStyles.timestamp),
          const SizedBox(width: 8),
          Text('✦', style: TextStyle(color: AppColors.primary, fontSize: 11)),
          const SizedBox(width: 12),
          const Expanded(child: Divider(color: AppColors.border)),
        ],
      ),
    );
  }

  // ====================================================
  // LUNAR LAVENDER MESSAGE BUBBLES
  // ====================================================
  Widget _buildMessageBubble(
    _ChatEntry message, {
    required String companionName,
    int? avatarIndex,
  }) {
    final mine = message.isMine;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final maxBubbleWidth = screenWidth * (mine ? 0.76 : 0.68);

    final bubble = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxBubbleWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.bubbleHorizontal,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: mine ? AppColors.primary : AppColors.elevatedSurface,
          border: mine ? null : Border.all(color: AppColors.border, width: 0.7),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppRadius.chatBubble),
            topRight: const Radius.circular(AppRadius.chatBubble),
            bottomLeft: Radius.circular(
              mine ? AppRadius.chatBubble : AppRadius.chatBubbleCorner,
            ),
            bottomRight: Radius.circular(
              mine ? AppRadius.chatBubbleCorner : AppRadius.chatBubble,
            ),
          ),
        ),
        child: Text(
          message.text,
          softWrap: true,
          style: mine ? AppTextStyles.messageMine : AppTextStyles.message,
        ),
      ),
    );

    final metadata = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (message.at != null)
          Text(_formatTime(message.at!), style: AppTextStyles.timestamp),
        if (mine) ...[
          if (message.at != null) const SizedBox(width: 5),
          Icon(
            message.deliveryStatus == _MessageDeliveryStatus.sent
                ? Icons.done_rounded
                : Icons.done_all_rounded,

            color: message.deliveryStatus == _MessageDeliveryStatus.read
                ? AppColors.receiptRead
                : AppColors.receiptPending,

            size: 16,
          ),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.messageGroupGap),
      child: Row(
        mainAxisAlignment: mine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!mine) ...[
            OrbitAvatar(
              name: companionName,
              avatarIndex: avatarIndex,
              size: 32,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: mine
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                bubble,
                if (message.at != null || mine)
                  Padding(
                    padding: EdgeInsets.only(
                      top: AppSpacing.timestampGap,
                      left: mine ? 0 : AppSpacing.xs,
                      right: mine ? AppSpacing.xs : 0,
                    ),
                    child: metadata,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ====================================================
  // TIME FORMAT
  // ====================================================
  String _formatTime(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour < 12 ? 'AM' : 'PM';

    return '$hour:$minute $period';
  }

  // ====================================================
  // LUNAR LAVENDER MESSAGE INPUT
  // ====================================================
  Widget _buildInput(String name) {
    final canSend = _controller.text.trim().isNotEmpty && !_sending;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.94),
        border: const Border(
          top: BorderSide(color: AppColors.border, width: 0.6),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Add attachment
          OrbitIconButton(
            icon: Icons.attach_file_rounded,
            tooltip: 'Attachments coming soon',
            variant: OrbitIconButtonVariant.ghost,
            size: 48,
            iconSize: 22,
            onTap: () {
              _showComingSoon('Attachments');
            },
          ),

          const SizedBox(width: AppSpacing.composerGap),

          // Message input
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.only(
                left: AppSpacing.inputHorizontal,
                right: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.composer),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: !_sending,
                      minLines: 1,
                      maxLines: 4,

                      inputFormatters: [LengthLimitingTextInputFormatter(1000)],

                      textCapitalization: TextCapitalization.sentences,

                      textInputAction: TextInputAction.send,

                      onChanged: (_) {
                        setState(() {});
                      },

                      onSubmitted: (_) {
                        _sendMessage();
                      },

                      style: AppTextStyles.input,

                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: AppTextStyles.inputHint,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          vertical: AppSpacing.inputVertical,
                        ),
                        isDense: true,
                      ),
                    ),
                  ),

                  // Emoji button
                  IconButton(
                    tooltip: 'Insert heart',
                    onPressed: _sending
                        ? null
                        : () {
                            final selection = _controller.selection;

                            final text = _controller.text;

                            final start = selection.isValid
                                ? selection.start
                                : text.length;

                            final end = selection.isValid
                                ? selection.end
                                : text.length;

                            const emoji = '💜';

                            _controller.value = TextEditingValue(
                              text: text.replaceRange(start, end, emoji),
                              selection: TextSelection.collapsed(
                                offset: start + emoji.length,
                              ),
                            );

                            setState(() {});
                          },
                    icon: const Icon(
                      Icons.sentiment_satisfied_alt_outlined,
                      color: AppColors.textSecondary,
                      size: 21,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: AppSpacing.composerGap),

          // Send button
          OrbitIconButton(
            tooltip: 'Send message',
            icon: Icons.send_rounded,
            variant: OrbitIconButtonVariant.primary,
            size: 48,
            iconSize: 21,
            onTap: canSend ? _sendMessage : null,
          ),
        ],
      ),
    );
  }
}

// ======================================================
// INTERNAL MESSAGE MODEL
// ======================================================
enum _MessageDeliveryStatus { sent, delivered, read }

_MessageDeliveryStatus _resolveDeliveryStatus(Map<String, dynamic> message) {
  if (message['readAt'] is Timestamp) {
    return _MessageDeliveryStatus.read;
  }

  if (message['deliveredAt'] is Timestamp) {
    return _MessageDeliveryStatus.delivered;
  }

  return _MessageDeliveryStatus.sent;
}

class _ChatEntry {
  final String text;
  final bool isMine;
  final DateTime? at;
  final _MessageDeliveryStatus deliveryStatus;

  const _ChatEntry({
    required this.text,
    required this.isMine,
    this.at,
    this.deliveryStatus = _MessageDeliveryStatus.sent,
  });
}

// ======================================================
// ENDED CONNECTION BANNER
// ======================================================
Widget _endedChatBanner(bool endedByNpc) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AppSpacing.lg),
    color: AppColors.elevatedSurface,
    child: Text(
      endedByNpc
          ? 'This character decided to end '
                'the connection.'
          : 'You ended this connection.',
      textAlign: TextAlign.center,
      style: AppTextStyles.body.copyWith(color: AppColors.primary),
    ),
  );
}

// ======================================================
// ANIMATED NPC TYPING BUBBLE
// ======================================================
class _TypingBubble extends StatefulWidget {
  const _TypingBubble({required this.name, this.avatarIndex});

  final String name;
  final int? avatarIndex;

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;

  @override
  void initState() {
    super.initState();

    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${widget.name} is typing',
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            OrbitAvatar(
              name: widget.name,
              avatarIndex: widget.avatarIndex,
              size: 32,
            ),

            const SizedBox(width: 8),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              decoration: BoxDecoration(
                color: AppColors.elevatedSurface,
                border: Border.all(color: AppColors.border, width: 0.6),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppRadius.chatBubble),
                  topRight: Radius.circular(AppRadius.chatBubble),
                  bottomLeft: Radius.circular(AppRadius.chatBubbleCorner),
                  bottomRight: Radius.circular(AppRadius.chatBubble),
                ),
              ),
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(3, (index) {
                      final phase = (_animation.value - index * 0.20 + 1) % 1;

                      final opacity = phase < 0.28 ? 1.0 : 0.35;

                      return Padding(
                        padding: EdgeInsets.only(right: index == 2 ? 0 : 5),
                        child: Opacity(
                          opacity: opacity,
                          child: const CircleAvatar(
                            radius: 3.5,
                            backgroundColor: AppColors.primary,
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
