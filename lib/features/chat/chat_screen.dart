// --------------------------------------------------------
// 1. IMPORTS & DEPENDENCIES
// --------------------------------------------------------
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/services/ai_service.dart';
import 'chat_storage.dart';
import 'npc_chat_service.dart';

// --------------------------------------------------------
// 2. CHAT SCREEN: MIKA & MATCHED NPC INPUTS
// --------------------------------------------------------
/// One chat UI for the legacy Mika flow and Firestore NPC matches.
/// Existing usage: ChatScreen(characterName: 'Mika')
/// New NPC usage: ChatScreen(npcId: npc.id)
class ChatScreen extends StatefulWidget {
  final String? characterName;
  final String? npcId;

  const ChatScreen({
    super.key,
    this.characterName,
    this.npcId,
  }) : assert(
  (characterName == null) != (npcId == null),
  'Provide either characterName or npcId, not both.',
  );

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

// --------------------------------------------------------
// 3. CHAT STATE: CONTROLLERS, STREAMS & TIMERS
// --------------------------------------------------------
class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatStore _legacyStore = ChatStore.instance;

  Stream<DocumentSnapshot<Map<String, dynamic>>>? _matchStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _messagesStream;
  bool _sending = false;
  bool _npcTyping = false;
  int _previousMessageCount = -1;

  Timer? _replyDebounce;
  Timer? _revealTimer;
  DateTime? _nextReveal;
  String? _pendingMessageId;
  String? _awaitingReplyToMessageId;
  bool _replyRunning = false;

  bool get _isNpc => widget.npcId != null;

// --------------------------------------------------------
// 4. INITIALIZE MIKA LISTENER OR NPC FIRESTORE STREAMS
// --------------------------------------------------------
  @override
  void initState() {
    super.initState();

    if (_isNpc) {
      final service = NpcChatService.instance;
      _matchStream = service.watchMatch(widget.npcId!);
      _messagesStream = service.watchMessages(widget.npcId!);
    } else {
      _legacyStore.addListener(_onLegacyChatUpdated);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _legacyStore.openChat(widget.characterName!);
        _scrollToBottom(jump: true);
      });
    }
  }

  // --------------------------------------------------------
  // 5. SCROLL HANDLING
  // --------------------------------------------------------
  void _onLegacyChatUpdated() => _scrollToBottom();

  void _scrollToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
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

  // --------------------------------------------------------
  // 6. SEND PLAYER BUBBLES & START 2-SECOND DEBOUNCE
  // --------------------------------------------------------
  // Save every user bubble immediately; do not call OpenAI yet.
  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    if (!_isNpc) {
      _controller.clear();
      setState(() {});
      _legacyStore.sendMessage(widget.characterName!, text);
      _scrollToBottom();
      return;
    }

    setState(() => _sending = true);
    try {
      final messageId = await NpcChatService.instance.sendPlayerMessage(
        npcId: widget.npcId!,
        text: text,
      );
      if (!mounted) return;
      if (_controller.text.trim() == text) _controller.clear();

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
        SnackBar(content: Text('Message not sent: $error')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // --------------------------------------------------------
  // 7. FLUSH BATCH: CALL AI ONCE & HANDLE BUSY STATE
  // --------------------------------------------------------
  // One callable request for the latest burst of user bubbles.
  Future<void> _flushNpcReply() async {
    if (!mounted || _replyRunning || _pendingMessageId == null) return;

    final messageId = _pendingMessageId!;
    _pendingMessageId = null;
    _replyRunning = true;
    setState(() => _npcTyping = true);
    var busy = false;

    try {
      final accepted = await AiService.instance.replyAsNpc(
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
        SnackBar(content: Text('NPC reply failed; messages were saved: $error')),
      );
    } finally {
      _replyRunning = false;
      if (mounted) setState(() => _npcTyping = false);

      // Messages sent while the AI was generating belong to the next batch.
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

  // --------------------------------------------------------
  // 8. SCHEDULE TIMED REVEAL FOR NPC BUBBLES
  // --------------------------------------------------------
  // Display stored NPC bubbles gradually (without additional AI requests).
  void _scheduleReveal(DateTime? revealAt) {
    if (_nextReveal == revealAt) return;
    _revealTimer?.cancel();
    _nextReveal = revealAt;
    if (revealAt == null) return;

    final delay = revealAt.difference(DateTime.now());
    _revealTimer = Timer(
      delay.isNegative ? Duration.zero : delay + const Duration(milliseconds: 30),
          () {
        _nextReveal = null;
        if (mounted) setState(() {});
      },
    );
  }

  // --------------------------------------------------------
  // 9. CLEAN UP TIMERS, LISTENERS & CONTROLLERS
  // --------------------------------------------------------
  @override
  void dispose() {
    _replyDebounce?.cancel();
    _revealTimer?.cancel();
    if (!_isNpc) {
      _legacyStore.removeListener(_onLegacyChatUpdated);
      _legacyStore.closeChat(widget.characterName!);
    }
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // --------------------------------------------------------
  // 10. CHAT PAGE SCAFFOLD & COSMIC BACKGROUND
  // --------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'lib/core/assets/bg.jpg',
              fit: BoxFit.cover,
            ),
          ),
          const Positioned.fill(
            child: ColoredBox(color: Color(0xE60B0914)),
          ),
          SafeArea(child: _isNpc ? _buildNpcRoom() : _buildLegacyRoom()),
        ],
      ),
    );
  }

  // --------------------------------------------------------
  // 11. LEGACY MIKA CONVERSATION
  // --------------------------------------------------------
  Widget _buildLegacyRoom() {
    final name = widget.characterName!;
    return _roomLayout(
      name: name,
      subtitle: 'AI Character · Demo',
      content: AnimatedBuilder(
        animation: _legacyStore,
        builder: (_, _) {
          final messages = _legacyStore.messagesFor(name);
          final typing = _legacyStore.isTyping(name);
          final entries = messages
              .map((msg) => _ChatEntry(
            text: msg.text,
            isMine: msg.isMine,
            at: msg.sentAt,
          ))
              .toList();
          return _messageList(
            entries,
            typingName: typing ? name : null,
          );
        },
      ),
    );
  }

  // --------------------------------------------------------
  // 12. NPC ROOM: LIVE PROFILE, AGE, CAREER & INTIMACY
  // --------------------------------------------------------
  Widget _buildNpcRoom() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _matchStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _status('Cannot load this match. Check your connection.');
        }
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primaryPink),
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
        final subtitle = [
          if (age != null) '$age',
          if (career != null && career.isNotEmpty) career,
        ].join(' • ');

        final intimacy = npc['intimacy'];
        final rawScore = intimacy is Map ? intimacy['score'] : null;
        final score = rawScore is num
            ? rawScore.toDouble().clamp(0.0, 100.0).toDouble()
            : 0.0;

        return _roomLayout(
          name: name,
          subtitle: subtitle,
          intimacyScore: score,
          content: _buildNpcMessages(npc),
        );
      },
    );
  }

  // --------------------------------------------------------
  // 13. SHARED LAYOUT: HEADER, MESSAGES & INPUT
  // --------------------------------------------------------
  Widget _roomLayout({
    required String name,
    required String subtitle,
    required Widget content,
    double? intimacyScore,
  }) {
    return Column(
      children: [
        _buildHeader(name, subtitle, intimacyScore: intimacyScore),
        Expanded(child: content),
        _buildInput(name),
      ],
    );
  }

  // --------------------------------------------------------
  // 14. EMPTY, LOADING & ERROR STATUS
  // --------------------------------------------------------

  Widget _status(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.softLilac),
        ),
      ),
    );
  }

  // --------------------------------------------------------
  // 15. CHAT HEADER & INTIMACY PROGRESS BAR
  // --------------------------------------------------------

  Widget _buildHeader(
      String name,
      String subtitle, {
        double? intimacyScore,
      }) {
    final score = intimacyScore;
    final stage = score == null
        ? null
        : score >= 80
        ? 'Deep Bond'
        : score >= 60
        ? 'Close'
        : score >= 40
        ? 'Comfortable'
        : score >= 20
        ? 'Getting Closer'
        : 'Strangers';

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 16, 12),
      decoration: const BoxDecoration(
        color: Color(0xE8151024),
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  size: 19,
                  color: AppColors.textPrimary,
                ),
              ),
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primaryPurple,
                child: Text(
                  name.isEmpty ? '?' : name[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.softLilac,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.auto_awesome, color: AppColors.primaryPink),
            ],
          ),
          if (score != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.favorite_rounded,
                        color: AppColors.primaryPink,
                        size: 14,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        '$stage · Intimacy ${score.toInt()}/100',
                        style: const TextStyle(
                          color: AppColors.softLilac,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      minHeight: 5,
                      value: score / 100,
                      color: AppColors.primaryPink,
                      backgroundColor: AppColors.border,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --------------------------------------------------------
  // 16. WATCH MESSAGE HISTORY & HIDE FUTURE NPC BUBBLES
  // --------------------------------------------------------
  Widget _buildNpcMessages(Map<String, dynamic> npc) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _messagesStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _status('Could not load messages.');
        }
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primaryPink),
          );
        }
        final documents = snapshot.data!.docs;
        final entries = <_ChatEntry>[];

        // --------------------------------------------------------
        // 1. ADD INITIAL MATCH MESSAGE
        // --------------------------------------------------------
        final first = npc['firstMessage'] as String?;
        if (npc['npcStarts'] == true && first != null && first.isNotEmpty) {
          final matchedAt = npc['matchedAt'];
          entries.add(_ChatEntry(
            text: first,
            isMine: false,
            at: matchedAt is Timestamp ? matchedAt.toDate() : null,
          ));
        }

        // --------------------------------------------------------
        // 2. FIND THE BATCH FOR THE LATEST PLAYER MESSAGE
        // --------------------------------------------------------
        String? awaitingBatchId;
        if (_awaitingReplyToMessageId != null) {
          for (final doc in documents) {
            if (doc.id == _awaitingReplyToMessageId) {
              final batchId = doc.data()['replyBatchId'];

              if (batchId is String &&
                  batchId.isNotEmpty &&
                  batchId != 'legacy') {
                awaitingBatchId = batchId;
              }

              break;
            }
          }
        }

        // --------------------------------------------------------
        // 3. BUILD VISIBLE MESSAGE HISTORY
        // --------------------------------------------------------
        DateTime? upcomingReveal;
        bool hasVisibleReply = false;
        final now = DateTime.now();
        for (final doc in snapshot.data!.docs) {
          final message = doc.data();
          final displayAt = message['displayAt'];

          // Hide NPC bubbles scheduled for a later reveal.
          if (displayAt is Timestamp) {
            final showAt = displayAt.toDate();
            if (showAt.isAfter(now)) {
              if (upcomingReveal == null || showAt.isBefore(upcomingReveal)) {
                upcomingReveal = showAt;
              }
              continue;
            }
          }

          // Check whether the current player batch
          // already has a visible NPC response.
          if (awaitingBatchId != null &&
              message['sender'] == 'npc' &&
              message['inReplyTo'] == awaitingBatchId) {
            hasVisibleReply = true;
          }

          final createdAt = message['createdAt'];
          entries.add(_ChatEntry(
            text: message['text'] as String? ?? '',
            isMine: message['sender'] == 'player',
            at: createdAt is Timestamp ? createdAt.toDate() : null,
          ));
        }

        // --------------------------------------------------------
        // 4. SCHEDULE NEXT NPC BUBBLE REVEAL
        // --------------------------------------------------------
        _scheduleReveal(upcomingReveal);

        // --------------------------------------------------------
        // 5. AUTO-SCROLL WHEN MESSAGE COUNT CHANGES
        // --------------------------------------------------------
        if (_previousMessageCount != entries.length) {
          _previousMessageCount = entries.length;
          _scrollToBottom();
        }

        // --------------------------------------------------------
        // 6. CONTROL NPC TYPING VISIBILITY
        // --------------------------------------------------------
        // Keep typing visible while waiting for the reply.
        // Hide when the first response is visible.
        // Show again if another NPC bubble is scheduled.
        final showTyping =
            (_npcTyping && !hasVisibleReply) ||
                upcomingReveal != null;

        // --------------------------------------------------------
        // 7. RENDER MESSAGES & TYPING INDICATOR
        // --------------------------------------------------------
        return _messageList(
            entries,
            typingName: showTyping
                ? (npc['name'] as String? ?? 'NPC')
                : null,
        );
      },
    );
  }

  // --------------------------------------------------------
  // 17. RENDER CONVERSATION LIST & TYPING INDICATOR
  // --------------------------------------------------------

  Widget _messageList(
      List<_ChatEntry> entries, {
        String? typingName,
      }) {
    if (entries.isEmpty && typingName == null) {
      return _status("It's a match! Say hello 💜");
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      itemCount: entries.length + 1 + (typingName == null ? 0 : 1),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Center(
            child: Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.cardSoft,
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Text(
                'YOUR CONVERSATION',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          );
        }
        if (index > entries.length) {
          return _TypingBubble(name: typingName!);
        }

        return _buildMessageBubble(entries[index - 1]);
      },
    );
  }

  // --------------------------------------------------------
  // 18. MESSAGE BUBBLE: SIZE, STYLE & TIMESTAMP
  // --------------------------------------------------------

  Widget _buildMessageBubble(_ChatEntry message) {
    return Align(
      alignment: message.isMine
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.76,
        ),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 8),
        decoration: BoxDecoration(
          gradient: message.isMine ? AppColors.primaryGradient : null,
          color: message.isMine ? null : AppColors.card,
          border: message.isMine
              ? null
              : Border.all(color: AppColors.border),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(message.isMine ? 20 : 5),
            bottomRight: Radius.circular(message.isMine ? 5 : 20),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message.text,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            if (message.at != null) ...[
              const SizedBox(height: 6),
              Text(
                _formatTime(message.at!),
                style: TextStyle(
                  color: message.isMine
                      ? Colors.white70
                      : AppColors.textSecondary,
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------
  // 19. FORMAT CHAT TIMESTAMPS
  // --------------------------------------------------------

  String _formatTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  // --------------------------------------------------------
  // 20. MESSAGE COMPOSER & SEND BUTTON
  // --------------------------------------------------------

  Widget _buildInput(String name) {
    final canSend = _controller.text.trim().isNotEmpty && !_sending;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: const BoxDecoration(
        color: Color(0xF0151024),
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.cardSoft,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                controller: _controller,
                enabled: !_sending,
                minLines: 1,
                maxLines: 4,
                inputFormatters: [LengthLimitingTextInputFormatter(1000)],
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.send,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _sendMessage(),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'Message $name...',
                  hintStyle: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filled(
            onPressed: canSend ? _sendMessage : null,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.primaryPink,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.cardSoft,
              disabledForegroundColor: AppColors.textSecondary,
              minimumSize: const Size(46, 46),
            ),
            icon: const Icon(Icons.arrow_upward_rounded),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------
// 21. INTERNAL MESSAGE DISPLAY MODEL
// --------------------------------------------------------

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

// --------------------------------------------------------
// 22. NPC TYPING BUBBLE: ANIMATED THREE DOTS
// --------------------------------------------------------
class _TypingBubble extends StatefulWidget {
  const _TypingBubble({required this.name});

  final String name;

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
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          border: Border.all(color: AppColors.border),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(5),
            bottomRight: Radius.circular(20),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${widget.name} is typing',
              style: const TextStyle(
                color: AppColors.softLilac,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(width: 8),
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (index) {
                    final phase = (_animation.value - index * 0.20 + 1) % 1;
                    final opacity = phase < 0.28 ? 1.0 : 0.30;
                    return Padding(
                      padding: EdgeInsets.only(right: index == 2 ? 0 : 4),
                      child: Opacity(
                        opacity: opacity,
                        child: const CircleAvatar(
                          radius: 2.5,
                          backgroundColor: AppColors.softLilac,
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}