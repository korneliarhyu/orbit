import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/services/ai_service.dart';
import '../../core/services/active_conversation_tracker.dart';
import 'npc_chat_service.dart';
import '../npc/npc_avatar_widget.dart';

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

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();

  final ScrollController _scrollController = ScrollController();

  Stream<DocumentSnapshot<Map<String, dynamic>>>? _matchStream;

  Stream<QuerySnapshot<Map<String, dynamic>>>? _messagesStream;

  bool _sending = false;
  bool _replyRunning = false;

  int _previousMessageCount = -1;

  Timer? _replyDebounce;
  Timer? _revealTimer;

  DateTime? _nextReveal;

  String? _pendingMessageId;
  String? _awaitingReplyToMessageId;

  // ====================================================
  // INITIALIZATION
  // ====================================================
  @override
  void initState() {
    super.initState();

    final service = NpcChatService.instance;

    _matchStream = service.watchMatch(widget.npcId);
    _messagesStream = service.watchMessages(widget.npcId);
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

    // Firestore NPC chat
    setState(() => _sending = true);

    try {
      final messageId = await NpcChatService.instance.sendPlayerMessage(
        npcId: widget.npcId,
        text: text,
      );

      if (!mounted) return;

      if (_controller.text.trim() == text) {
        _controller.clear();
      }

      setState(() {
        _pendingMessageId = messageId;
      });

      _replyDebounce?.cancel();

      _replyDebounce = Timer(const Duration(seconds: 2), _flushNpcReply);

      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Message not sent: $error')));
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
    if (!mounted || _replyRunning || _pendingMessageId == null) {
      return;
    }

    final messageId = _pendingMessageId!;

    setState(() {
      _pendingMessageId = null;
      _replyRunning = true;
      _awaitingReplyToMessageId = messageId;
    });

    var busy = false;

    try {
      final accepted = await AiService.instance.replyAsNpc(
        npcId: widget.npcId,
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
          content: Text('NPC reply failed; messages were saved: $error'),
        ),
      );
    } finally {
      _replyRunning = false;
      _awaitingReplyToMessageId = null;

      if (mounted) {
        setState(() {});
      }

      if (mounted && _pendingMessageId != null) {
        _replyDebounce?.cancel();

        _replyDebounce = Timer(
          busy
              ? const Duration(seconds: 2)
              : const Duration(milliseconds: 1800),
          _flushNpcReply,
        );
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

      _replyDebounce?.cancel();
      _pendingMessageId = null;

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Connection ended.')));
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not end match: $error')));
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
    ActiveConversationTracker.instance.unregister(this);

    _replyDebounce?.cancel();
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
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.8, 0.12),
            radius: 1.25,
            colors: [Color(0xFF211A2B), AppColors.background],
          ),
        ),
        child: SafeArea(child: _buildNpcRoom()),
      ),
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

        final avatarIndex = (npc['avatarIndex'] as num?)?.toInt() ?? 0;

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
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary),
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
    const lilac = Color(0xFFD8B9EE);
    return Semantics(
      label: 'Intimacy: $label',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF30253D),
          border: Border.all(color: const Color(0xFF594469), width: 0.7),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.favorite_border_rounded, color: lilac, size: 12),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: lilac,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  height: 1.15,
                ),
              ),
            ),
          ],
        ),
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
    final hasPilotCareer = subtitle.toLowerCase().contains('pilot');

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 7, 8, 8),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.6)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary,
              size: 19,
            ),
          ),
          // Avatar + name open the same future character profile.
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: Tooltip(
                message: 'View character profile',
                child: InkWell(
                  onTap: _openCharacterProfile,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        _ChatAvatar(
                          name: name,
                          avatarIndex: avatarIndex,
                          size: 50,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Icon(
                                    ended
                                        ? Icons.link_off_rounded
                                        : hasPilotCareer
                                        ? Icons.flight_takeoff_rounded
                                        : Icons.public_rounded,
                                    color: AppColors.primary,
                                    size: 13,
                                  ),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      ended
                                          ? 'Connection ended'
                                          : subtitle.isNotEmpty
                                          ? subtitle
                                          : 'AI Companion',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (intimacyLabel != null && !ended) ...[
                                const SizedBox(height: 5),
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
          const SizedBox(width: 4),
          if (!ended)
            IconButton(
              tooltip: 'Unmatch',
              onPressed: _confirmUnmatch,
              icon: const Icon(
                Icons.link_off_rounded,
                color: AppColors.textSecondary,
                size: 23,
              ),
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

        if (_awaitingReplyToMessageId != null) {
          for (final doc in documents) {
            if (doc.id == _awaitingReplyToMessageId) {
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
        bool hasVisibleReply = false;

        final now = DateTime.now();

        // Build visible messages
        for (final doc in documents) {
          final message = doc.data();
          final displayAt = message['displayAt'];

          if (displayAt is Timestamp) {
            final showAt = displayAt.toDate();

            if (showAt.isAfter(now)) {
              if (upcomingReveal == null || showAt.isBefore(upcomingReveal)) {
                upcomingReveal = showAt;
              }

              continue;
            }
          }

          if (awaitingBatchId != null &&
              message['sender'] == 'npc' &&
              message['inReplyTo'] == awaitingBatchId) {
            hasVisibleReply = true;
          }

          final createdAt = message['createdAt'];

          entries.add(
            _ChatEntry(
              text: message['text'] as String? ?? '',
              isMine: message['sender'] == 'player',
              at: createdAt is Timestamp ? createdAt.toDate() : null,
              deliveryStatus: _resolveDeliveryStatus(message),
            ),
          );
        }

        _scheduleReveal(upcomingReveal);

        // Auto-scroll
        if (_previousMessageCount != entries.length) {
          _previousMessageCount = entries.length;
          _scrollToBottom();
        }

        // NPC typing indicator
        final showTyping =
            !ended &&
            ((_replyRunning && awaitingMessageRead && !hasVisibleReply) ||
                upcomingReveal != null);

        return _messageList(
          entries,
          companionName: npc['name'] as String? ?? 'NPC',
          avatarIndex: (npc['avatarIndex'] as num?)?.toInt() ?? 0,
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
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
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
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ),
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
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
        decoration: BoxDecoration(
          color: mine ? const Color(0xFFD0B2D9) : const Color(0xFF302C36),
          border: mine
              ? null
              : Border.all(color: const Color(0xFF5B5264), width: 0.7),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(21),
            topRight: const Radius.circular(21),
            bottomLeft: Radius.circular(mine ? 21 : 6),
            bottomRight: Radius.circular(mine ? 6 : 21),
          ),
        ),
        child: Text(
          message.text,
          softWrap: true,
          style: TextStyle(
            color: mine ? const Color(0xFF211A2B) : AppColors.textPrimary,
            fontSize: 15.5,
            height: 1.4,
          ),
        ),
      ),
    );

    final metadata = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (message.at != null)
          Text(
            _formatTime(message.at!),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        if (mine) ...[
          if (message.at != null) const SizedBox(width: 5),
          Icon(
            message.deliveryStatus == _MessageDeliveryStatus.sent
                ? Icons.done_rounded
                : Icons.done_all_rounded,

            color: message.deliveryStatus == _MessageDeliveryStatus.read
                ? const Color(0xFFD7B6E5)
                : const Color(0xFF81778F),

            size: 16,
          ),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: mine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!mine) ...[
            _ChatAvatar(
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
                      top: 5,
                      left: mine ? 0 : 6,
                      right: mine ? 6 : 0,
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
      padding: const EdgeInsets.fromLTRB(10, 9, 12, 14),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border, width: 0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Add attachment
          _roundAction(
            icon: Icons.attach_file_rounded,
            tooltip: 'Attachments coming soon',
            onTap: () {
              _showComingSoon('Attachments');
            },
          ),

          const SizedBox(width: 9),

          // Message input
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 46),
              padding: const EdgeInsets.only(left: 15, right: 3),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(26),
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

                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),

                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(color: AppColors.textSecondary),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
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

          const SizedBox(width: 9),

          // Send button
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: canSend ? AppColors.primaryGradient : null,
              color: canSend ? null : AppColors.elevatedSurface,
            ),
            child: IconButton(
              tooltip: 'Send message',
              onPressed: canSend ? _sendMessage : null,
              icon: Icon(
                Icons.send_rounded,
                size: 21,
                color: canSend ? AppColors.onPrimary : AppColors.textSecondary,
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        icon: Icon(icon, color: AppColors.textPrimary, size: 23),
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
    padding: const EdgeInsets.all(16),
    color: AppColors.cardSoft,
    child: Text(
      endedByNpc
          ? 'This character decided to end '
                'the connection.'
          : 'You ended this connection.',
      textAlign: TextAlign.center,
      style: const TextStyle(color: AppColors.softLilac),
    ),
  );
}

// ======================================================
// COMPANION AVATAR PLACEHOLDER
// ======================================================
class _CompanionAvatar extends StatelessWidget {
  const _CompanionAvatar({required this.name, required this.radius});

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
        border: Border.all(color: AppColors.border, width: 1.2),
      ),
      child: Text(
        name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
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
// NPC AVATAR (uses the shared portrait asset widget)
// ======================================================
class _ChatAvatar extends StatelessWidget {
  const _ChatAvatar({required this.name, required this.size, this.avatarIndex});

  final String name;
  final double size;
  final int? avatarIndex;

  @override
  Widget build(BuildContext context) {
    if (avatarIndex == null) {
      return _CompanionAvatar(name: name, radius: size / 2);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border, width: 1.1),
      ),
      clipBehavior: Clip.antiAlias,
      child: ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: NpcAvatarWidget(avatarIndex: avatarIndex!, width: size),
        ),
      ),
    );
  }
}

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
            _ChatAvatar(
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
