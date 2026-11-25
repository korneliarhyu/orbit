
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/services/ai_service.dart';
import 'chat_storage.dart';
import 'npc_chat_service.dart';

// ======================================================
// ORBIT - LUNAR LAVENDER CHAT SCREEN
// ======================================================

class ChatScreen extends StatefulWidget {
  final String? characterName;
  final String? npcId;

  const ChatScreen({
    super.key,
    this.characterName,
    this.npcId,
  }) : assert(
  (characterName == null) != (npcId == null),
  'Provide either characterName or npcId.',
  );

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

// ======================================================
// CHAT SCREEN STATE
// ======================================================

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller =
  TextEditingController();

  final ScrollController _scrollController =
  ScrollController();

  final ChatStore _legacyStore = ChatStore.instance;

  Stream<DocumentSnapshot<Map<String, dynamic>>>?
  _matchStream;

  Stream<QuerySnapshot<Map<String, dynamic>>>?
  _messagesStream;

  bool _sending = false;
  bool _npcTyping = false;
  bool _replyRunning = false;

  int _previousMessageCount = -1;

  Timer? _replyDebounce;
  Timer? _revealTimer;

  DateTime? _nextReveal;

  String? _pendingMessageId;
  String? _awaitingReplyToMessageId;

  bool get _isNpc => widget.npcId != null;

  // ====================================================
  // INITIALIZATION
  // ====================================================

  @override
  void initState() {
    super.initState();

    if (_isNpc) {
      final service = NpcChatService.instance;

      _matchStream = service.watchMatch(
        widget.npcId!,
      );

      _messagesStream = service.watchMessages(
        widget.npcId!,
      );
    } else {
      _legacyStore.addListener(
        _onLegacyChatUpdated,
      );

      WidgetsBinding.instance.addPostFrameCallback(
            (_) {
          if (!mounted) return;

          _legacyStore.openChat(
            widget.characterName!,
          );

          _scrollToBottom(jump: true);
        },
      );
    }
  }

  // ====================================================
  // SCROLL HANDLING
  // ====================================================

  void _onLegacyChatUpdated() {
    _scrollToBottom();
  }

  void _scrollToBottom({
    bool jump = false,
  }) {
    WidgetsBinding.instance.addPostFrameCallback(
          (_) {
        if (!mounted || !_scrollController.hasClients) {
          return;
        }

        final target =
            _scrollController.position.maxScrollExtent;

        if (jump) {
          _scrollController.jumpTo(target);
        } else {
          _scrollController.animateTo(
            target,
            duration: const Duration(
              milliseconds: 220,
            ),
            curve: Curves.easeOut,
          );
        }
      },
    );
  }

  // ====================================================
  // SEND PLAYER MESSAGE
  // ====================================================

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();

    if (text.isEmpty || _sending) return;

    // Legacy character chat
    if (!_isNpc) {
      _controller.clear();
      setState(() {});

      _legacyStore.sendMessage(
        widget.characterName!,
        text,
      );

      _scrollToBottom();
      return;
    }

    // Firestore NPC chat
    setState(() => _sending = true);

    try {
      final messageId =
      await NpcChatService.instance.sendPlayerMessage(
        npcId: widget.npcId!,
        text: text,
      );

      if (!mounted) return;

      if (_controller.text.trim() == text) {
        _controller.clear();
      }

      setState(() {
        _pendingMessageId = messageId;
        _awaitingReplyToMessageId = messageId;
        _npcTyping = true;
      });

      _replyDebounce?.cancel();

      _replyDebounce = Timer(
        const Duration(seconds: 2),
        _flushNpcReply,
      );

      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Message not sent: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  // ====================================================
  // AI NPC REPLY
  // ====================================================

  Future<void> _flushNpcReply() async {
    if (!mounted ||
        _replyRunning ||
        _pendingMessageId == null) {
      return;
    }

    final messageId = _pendingMessageId!;

    _pendingMessageId = null;
    _replyRunning = true;

    setState(() => _npcTyping = true);

    var busy = false;

    try {
      final accepted =
      await AiService.instance.replyAsNpc(
        npcId: widget.npcId!,
        messageId: messageId,
      );

      if (!accepted) {
        busy = true;
        _pendingMessageId ??= messageId;
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'NPC reply failed; messages were saved: $error',
          ),
        ),
      );
    } finally {
      _replyRunning = false;

      if (mounted) {
        setState(() => _npcTyping = false);
      }

      if (mounted && _pendingMessageId != null) {
        _replyDebounce?.cancel();

        _replyDebounce = Timer(
          busy
              ? const Duration(seconds: 2)
              : const Duration(
            milliseconds: 1800,
          ),
          _flushNpcReply,
        );
      }
    }
  }

  // ====================================================
  // UNMATCH NPC
  // ====================================================

  Future<void> _confirmUnmatch() async {
    if (!_isNpc) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text(
            'End this connection?',
            style: TextStyle(
              color: AppColors.textPrimary,
            ),
          ),
          content: const Text(
            'This conversation will end. '
                'You can still read the chat history.',
            style: TextStyle(
              color: AppColors.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text('Keep chatting'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
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
      await NpcChatService.instance.endMatch(
        widget.npcId!,
      );

      _replyDebounce?.cancel();
      _pendingMessageId = null;

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connection ended.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not end match: $error',
          ),
        ),
      );
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

    final delay = revealAt.difference(
      DateTime.now(),
    );

    _revealTimer = Timer(
      delay.isNegative
          ? Duration.zero
          : delay +
          const Duration(milliseconds: 30),
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
    _replyDebounce?.cancel();
    _revealTimer?.cancel();

    if (!_isNpc) {
      _legacyStore.removeListener(
        _onLegacyChatUpdated,
      );

      _legacyStore.closeChat(
        widget.characterName!,
      );
    }

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
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.8, 0.12),
            radius: 1.25,
            colors: [
              Color(0xFF211A2B),
              AppColors.background,
            ],
          ),
        ),
        child: SafeArea(
          child: _isNpc
              ? _buildNpcRoom()
              : _buildLegacyRoom(),
        ),
      ),
    );
  }

  // ====================================================
  // LEGACY CHARACTER ROOM
  // ====================================================

  Widget _buildLegacyRoom() {
    final name = widget.characterName!;

    return _roomLayout(
      name: name,
      subtitle: 'AI Character · Demo',
      content: AnimatedBuilder(
        animation: _legacyStore,
        builder: (_, _) {
          final messages =
          _legacyStore.messagesFor(name);

          final typing =
          _legacyStore.isTyping(name);

          final entries = messages.map(
                (msg) {
              return _ChatEntry(
                text: msg.text,
                isMine: msg.isMine,
                at: msg.sentAt,
              );
            },
          ).toList();

          return _messageList(
            entries,
            companionName: name,
            typingName: typing ? name : null,
          );
        },
      ),
    );
  }

  // ====================================================
  // NPC FIRESTORE ROOM
  // ====================================================

  Widget _buildNpcRoom() {
    return StreamBuilder<
        DocumentSnapshot<Map<String, dynamic>>>(
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
            child: CircularProgressIndicator(
              color: AppColors.primary,
            ),
          );
        }

        final document = snapshot.data!;

        if (!document.exists) {
          return _status('Match not found.');
        }

        final npc = document.data()!;

        final name =
            npc['name'] as String? ?? 'Traveler';

        final age =
        (npc['age'] as num?)?.toInt();

        final career =
        (npc['career'] as String?)?.trim();

        final subtitle = [
          if (age != null) '$age',
          if (career != null && career.isNotEmpty)
            career,
        ].join(' • ');

        final intimacy = npc['intimacy'];

        final rawScore = intimacy is Map
            ? intimacy['score']
            : null;

        final score = rawScore is num
            ? rawScore
            .toDouble()
            .clamp(0.0, 100.0)
            .toDouble()
            : 0.0;

        final status =
            npc['relationshipStatus'] as String? ??
                'active';

        final ended = status != 'active';

        return _roomLayout(
          name: name,
          subtitle: subtitle,
          intimacyScore: score,
          ended: ended,
          endedByNpc:
          status == 'unmatched_npc',
          content: _buildNpcMessages(
            npc,
            ended: ended,
          ),
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
    double? intimacyScore,
    bool ended = false,
    bool endedByNpc = false,
  }) {
    return Column(
      children: [
        _buildHeader(
          name,
          subtitle,
          intimacyScore: intimacyScore,
          ended: ended,
        ),

        Expanded(
          child: content,
        ),

        if (ended)
          _endedChatBanner(endedByNpc)
        else
          _buildInput(name),
      ],
    );
  }

  // ====================================================
  // STATUS MESSAGE
  // ====================================================

  Widget _status(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  // ====================================================
  // LUNAR LAVENDER HEADER
  // ====================================================

  Widget _buildHeader(
      String name,
      String subtitle, {
        double? intimacyScore,
        bool ended = false,
      }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        6, 10, 12, 12,
      ),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(
          bottom: BorderSide(
            color: AppColors.border,
            width: 0.6,
          ),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Back button
              IconButton(
                tooltip: 'Back',
                onPressed: () {
                  Navigator.maybePop(context);
                },
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: AppColors.textPrimary,
                  size: 19,
                ),
              ),

              // Avatar
              _CompanionAvatar(
                name: name,
                radius: 24,
              ),

              const SizedBox(width: 11),

              // Name and status
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: ended
                                ? AppColors.textSecondary
                                : AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),

                        const SizedBox(width: 6),

                        Expanded(
                          child: Text(
                            ended
                                ? 'Connection ended'
                                : subtitle.isNotEmpty
                                ? subtitle
                                : 'AI Companion',
                            maxLines: 1,
                            overflow:
                            TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color:
                              AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Voice call
              IconButton(
                tooltip: 'Voice calls coming soon',
                onPressed: () {
                  _showComingSoon('Voice calls');
                },
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.call_outlined,
                  color: AppColors.textPrimary,
                  size: 22,
                ),
              ),

              // Video call
              IconButton(
                tooltip: 'Video calls coming soon',
                onPressed: () {
                  _showComingSoon('Video calls');
                },
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.videocam_outlined,
                  color: AppColors.textPrimary,
                  size: 23,
                ),
              ),

              // Options menu
              if (_isNpc && !ended)
                PopupMenuButton<String>(
                  tooltip: 'Chat options',
                  color: AppColors.elevatedSurface,
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  onSelected: (value) {
                    if (value == 'unmatch') {
                      _confirmUnmatch();
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem<String>(
                      value: 'unmatch',
                      child: Text('Unmatch'),
                    ),
                  ],
                ),
            ],
          ),

          // Intimacy indicator
          if (intimacyScore != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                18, 9, 18, 0,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                  value: intimacyScore / 100,
                  minHeight: 3,
                  backgroundColor: AppColors.border,
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$feature coming soon in ORBIT.',
        ),
      ),
    );
  }

  // ====================================================
  // WATCH NPC MESSAGES
  // ====================================================

  Widget _buildNpcMessages(
      Map<String, dynamic> npc, {
        required bool ended,
      }) {
    return StreamBuilder<
        QuerySnapshot<Map<String, dynamic>>>(
      stream: _messagesStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _status(
            'Could not load messages.',
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(
              color: AppColors.primary,
            ),
          );
        }

        final documents = snapshot.data!.docs;
        final entries = <_ChatEntry>[];

        // Initial match message
        final first =
        npc['firstMessage'] as String?;

        if (npc['npcStarts'] == true &&
            first != null &&
            first.isNotEmpty) {
          final matchedAt = npc['matchedAt'];

          entries.add(
            _ChatEntry(
              text: first,
              isMine: false,
              at: matchedAt is Timestamp
                  ? matchedAt.toDate()
                  : null,
            ),
          );
        }

        // Find current reply batch
        String? awaitingBatchId;

        if (_awaitingReplyToMessageId != null) {
          for (final doc in documents) {
            if (doc.id ==
                _awaitingReplyToMessageId) {
              final batchId =
              doc.data()['replyBatchId'];

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
        bool hasVisibleReply = false;

        final now = DateTime.now();

        // Build visible messages
        for (final doc in documents) {
          final message = doc.data();
          final displayAt = message['displayAt'];

          if (displayAt is Timestamp) {
            final showAt = displayAt.toDate();

            if (showAt.isAfter(now)) {
              if (upcomingReveal == null ||
                  showAt.isBefore(upcomingReveal)) {
                upcomingReveal = showAt;
              }

              continue;
            }
          }

          if (awaitingBatchId != null &&
              message['sender'] == 'npc' &&
              message['inReplyTo'] ==
                  awaitingBatchId) {
            hasVisibleReply = true;
          }

          final createdAt = message['createdAt'];

          entries.add(
            _ChatEntry(
              text:
              message['text'] as String? ?? '',
              isMine:
              message['sender'] == 'player',
              at: createdAt is Timestamp
                  ? createdAt.toDate()
                  : null,
            ),
          );
        }

        _scheduleReveal(upcomingReveal);

        // Auto-scroll
        if (_previousMessageCount !=
            entries.length) {
          _previousMessageCount = entries.length;
          _scrollToBottom();
        }

        // NPC typing indicator
        final showTyping = !ended &&
            ((_npcTyping && !hasVisibleReply) ||
                upcomingReveal != null);

        return _messageList(
          entries,
          companionName:
          npc['name'] as String? ?? 'NPC',
          typingName: showTyping
              ? npc['name'] as String? ?? 'NPC'
              : null,
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
        String? typingName,
      }) {
    if (entries.isEmpty && typingName == null) {
      return _status(
        "It's a match! Say hello 💜",
      );
    }

    return ListView.builder(
      controller: _scrollController,
      keyboardDismissBehavior:
      ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(
        14, 22, 14, 24,
      ),
      itemCount: entries.length +
          (typingName == null ? 0 : 1),
      itemBuilder: (context, index) {
        if (index == entries.length) {
          return _TypingBubble(
            name: typingName!,
          );
        }

        final entry = entries[index];

        final previous = index == 0
            ? null
            : entries[index - 1];

        final showDate = entry.at != null &&
            (previous?.at == null ||
                !_sameDay(
                  previous!.at!,
                  entry.at!,
                ));

        return Column(
          children: [
            if (showDate)
              _datePill(
                _dateLabel(entry.at!),
              ),

            _buildMessageBubble(
              entry,
              companionName: companionName,
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
    return a.year == b.year &&
        a.month == b.month &&
        a.day == b.day;
  }

  String _dateLabel(DateTime date) {
    final now = DateTime.now();

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final day = DateTime(
      date.year,
      date.month,
      date.day,
    );

    if (day == today) {
      return 'Today';
    }

    if (day ==
        today.subtract(
          const Duration(days: 1),
        )) {
      return 'Yesterday';
    }

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr',
      'May', 'Jun', 'Jul', 'Aug',
      'Sep', 'Oct', 'Nov', 'Dec',
    ];

    return '${date.day} '
        '${months[date.month - 1]} '
        '${date.year}';
  }

  Widget _datePill(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 19,
      ),
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.elevatedSurface,
            borderRadius:
            BorderRadius.circular(99),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 17,
              vertical: 7,
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ====================================================
  // LUNAR LAVENDER MESSAGE BUBBLES
  // ====================================================


  Widget _buildMessageBubble(
      _ChatEntry message, {
        required String companionName,
      }) {
    final mine = message.isMine;

    final screenWidth = MediaQuery.sizeOf(context).width;

    // Maximum bubble width.
    final maxBubbleWidth = screenWidth * 0.72;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: mine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // NPC Avatar
          if (!mine) ...[
            _CompanionAvatar(
              name: companionName,
              radius: 16,
            ),
            const SizedBox(width: 8),
          ],

          // Bubble adapts to text content.
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxBubbleWidth,
              ),
              child: IntrinsicWidth(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(
                    14,
                    10,
                    14,
                    8,
                  ),
                  decoration: BoxDecoration(
                    gradient: mine
                        ? AppColors.messageGradient
                        : null,

                    color: mine
                        ? null
                        : AppColors.elevatedSurface,

                    border: mine
                        ? null
                        : Border.all(
                      color: AppColors.border,
                      width: 0.6,
                    ),

                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(
                        mine ? 20 : 6,
                      ),
                      bottomRight: Radius.circular(
                        mine ? 6 : 20,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Message text
                      Text(
                        message.text,
                        softWrap: true,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),

                      // Timestamp
                      if (message.at != null) ...[
                        const SizedBox(height: 4),

                        Text(
                          _formatTime(message.at!),
                          style: TextStyle(
                            color: mine
                                ? AppColors.textPrimary
                                .withAlpha(190)
                                : AppColors.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
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
    final hour =
    value.hour.toString().padLeft(2, '0');

    final minute =
    value.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  // ====================================================
  // LUNAR LAVENDER MESSAGE INPUT
  // ====================================================

  Widget _buildInput(String name) {
    final canSend =
        _controller.text.trim().isNotEmpty &&
            !_sending;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        10, 9, 12, 14,
      ),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(
          top: BorderSide(
            color: AppColors.border,
            width: 0.6,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.end,
        children: [
          // Add attachment
          _roundAction(
            icon: Icons.add_rounded,
            tooltip: 'Attachments coming soon',
            onTap: () {
              _showComingSoon('Attachments');
            },
          ),

          const SizedBox(width: 9),

          // Message input
          Expanded(
            child: Container(
              constraints: const BoxConstraints(
                minHeight: 46,
              ),
              padding: const EdgeInsets.only(
                left: 15,
                right: 3,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius:
                BorderRadius.circular(26),
                border: Border.all(
                  color: AppColors.border,
                ),
              ),
              child: Row(
                crossAxisAlignment:
                CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: !_sending,
                      minLines: 1,
                      maxLines: 4,

                      inputFormatters: [
                        LengthLimitingTextInputFormatter(
                          1000,
                        ),
                      ],

                      textCapitalization:
                      TextCapitalization.sentences,

                      textInputAction:
                      TextInputAction.send,

                      onChanged: (_) {
                        setState(() {});
                      },

                      onSubmitted: (_) {
                        _sendMessage();
                      },

                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),

                      decoration:
                      const InputDecoration(
                        hintText: 'Message...',
                        hintStyle: TextStyle(
                          color:
                          AppColors.textSecondary,
                        ),
                        border: InputBorder.none,
                        enabledBorder:
                        InputBorder.none,
                        focusedBorder:
                        InputBorder.none,
                        contentPadding:
                        EdgeInsets.symmetric(
                          vertical: 12,
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
                      final selection =
                          _controller.selection;

                      final text =
                          _controller.text;

                      final start =
                      selection.isValid
                          ? selection.start
                          : text.length;

                      final end =
                      selection.isValid
                          ? selection.end
                          : text.length;

                      const emoji = '💜';

                      _controller.value =
                          TextEditingValue(
                            text: text.replaceRange(
                              start,
                              end,
                              emoji,
                            ),
                            selection:
                            TextSelection.collapsed(
                              offset:
                              start + emoji.length,
                            ),
                          );

                      setState(() {});
                    },
                    icon: const Icon(
                      Icons
                          .sentiment_satisfied_alt_outlined,
                      color: AppColors.textSecondary,
                      size: 21,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 9),

          // Send button
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: canSend
                  ? AppColors.primaryGradient
                  : null,
              color: canSend
                  ? null
                  : AppColors.elevatedSurface,
            ),
            child: IconButton(
              tooltip: 'Send message',
              onPressed:
              canSend ? _sendMessage : null,
              icon: Icon(
                Icons.send_rounded,
                size: 21,
                color: canSend
                    ? AppColors.onPrimary
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ====================================================
  // ROUND ACTION BUTTON
  // ====================================================

  Widget _roundAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        icon: Icon(
          icon,
          color: AppColors.textPrimary,
          size: 23,
        ),
      ),
    );
  }
}

// ======================================================
// INTERNAL MESSAGE MODEL
// ======================================================

class _ChatEntry {
  final String text;
  final bool isMine;
  final DateTime? at;

  const _ChatEntry({
    required this.text,
    required this.isMine,
    this.at,
  });
}

// ======================================================
// ENDED CONNECTION BANNER
// ======================================================

Widget _endedChatBanner(bool endedByNpc) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    color: AppColors.cardSoft,
    child: Text(
      endedByNpc
          ? 'This character decided to end '
          'the connection.'
          : 'You ended this connection.',
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: AppColors.softLilac,
      ),
    ),
  );
}

// ======================================================
// COMPANION AVATAR PLACEHOLDER
// ======================================================

class _CompanionAvatar extends StatelessWidget {
  const _CompanionAvatar({
    required this.name,
    required this.radius,
  });

  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.primaryGradient,
        border: Border.all(
          color: AppColors.border,
          width: 1.2,
        ),
      ),
      child: Text(
        name.isEmpty
            ? '?'
            : name.substring(0, 1).toUpperCase(),
        style: TextStyle(
          color: AppColors.onPrimary,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.80,
        ),
      ),
    );
  }
}

// ======================================================
// ANIMATED NPC TYPING BUBBLE
// ======================================================

class _TypingBubble extends StatefulWidget {
  const _TypingBubble({
    required this.name,
  });

  final String name;

  @override
  State<_TypingBubble> createState() =>
      _TypingBubbleState();
}

class _TypingBubbleState
    extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;

  @override
  void initState() {
    super.initState();

    _animation = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 900,
      ),
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
        padding: const EdgeInsets.only(
          bottom: 12,
        ),
        child: Row(
          crossAxisAlignment:
          CrossAxisAlignment.end,
          children: [
            _CompanionAvatar(
              name: widget.name,
              radius: 16,
            ),

            const SizedBox(width: 8),

            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 15,
              ),
              decoration: BoxDecoration(
                color: AppColors.elevatedSurface,
                border: Border.all(
                  color: AppColors.border,
                  width: 0.6,
                ),
                borderRadius:
                const BorderRadius.only(
                  topLeft: Radius.circular(21),
                  topRight: Radius.circular(21),
                  bottomLeft: Radius.circular(6),
                  bottomRight: Radius.circular(21),
                ),
              ),
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      3,
                          (index) {
                        final phase =
                            (_animation.value -
                                index * 0.20 +
                                1) %
                                1;

                        final opacity =
                        phase < 0.28
                            ? 1.0
                            : 0.35;

                        return Padding(
                          padding: EdgeInsets.only(
                            right:
                            index == 2 ? 0 : 5,
                          ),
                          child: Opacity(
                            opacity: opacity,
                            child:
                            const CircleAvatar(
                              radius: 3.5,
                              backgroundColor:
                              AppColors.primary,
                            ),
                          ),
                        );
                      },
                    ),
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
