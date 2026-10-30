import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/services/ai_service.dart';
import 'chat_storage.dart';
import 'npc_chat_service.dart';

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

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatStore _legacyStore = ChatStore.instance;

  Stream<DocumentSnapshot<Map<String, dynamic>>>? _matchStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _messagesStream;
  bool _sending = false;
  bool _npcTyping = false;
  int _previousMessageCount = -1;

  bool get _isNpc => widget.npcId != null;

  @override
  void initState() {
    super.initState();

    if (_isNpc) {
      final service = NpcChatService.instance;
      _matchStream = service.watchMatch(widget.npcId!);
      _messagesStream = service.watchLastMessage(widget.npcId!);
    } else {
      _legacyStore.addListener(_onLegacyChatUpdated);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _legacyStore.openChat(widget.characterName!);
        _scrollToBottom(jump: true);
      });
    }
  }

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
      setState(() => _npcTyping = true);
      _scrollToBottom();

      try {
        await AiService.instance.replyAsNpc(
          npcId: widget.npcId!,
          messageId: messageId,
        );
      } catch (error) {
        if (!mounted) return;
        // The player's message was saved. Only the AI reply failed.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Message saved, but NPC reply failed: $error')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Message not sent: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _npcTyping = false;
          _sending = false;
        });
      }
    }
  }

  @override
  void dispose() {
    if (!_isNpc) {
      _legacyStore.removeListener(_onLegacyChatUpdated);
      _legacyStore.closeChat(widget.characterName!);
    }
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

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

  Widget _buildLegacyRoom() {
    final name = widget.characterName!;
    return _roomLayout(
      name: name,
      subtitle: 'AI Character · Demo',
      content: AnimatedBuilder(
        animation: _legacyStore,
        builder: (_, __) {
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
        final archetype = npc['archetype'] as String? ?? 'Cosmic Connection';

        final intimacy = npc['intimacy'];
        final rawScore = intimacy is Map ? intimacy['score'] : null;
        final score = rawScore is num
            ? rawScore.toDouble().clamp(0.0, 100.0).toDouble()
            : 0.0;

        return _roomLayout(
          name: name,
          subtitle: archetype,
          intimacyScore: score,
          content: _buildNpcMessages(npc),
        );
      },
    );
  }

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

        final entries = <_ChatEntry>[];
        final first = npc['firstMessage'] as String?;
        if (npc['npcStarts'] == true && first != null && first.isNotEmpty) {
          final matchedAt = npc['matchedAt'];
          entries.add(_ChatEntry(
            text: first,
            isMine: false,
            at: matchedAt is Timestamp ? matchedAt.toDate() : null,
          ));
        }

        for (final doc in snapshot.data!.docs) {
          final message = doc.data();
          final createdAt = message['createdAt'];
          entries.add(_ChatEntry(
            text: message['text'] as String? ?? '',
            isMine: message['sender'] == 'player',
            at: createdAt is Timestamp ? createdAt.toDate() : null,
          ));
        }

        if (_previousMessageCount != entries.length) {
          _previousMessageCount = entries.length;
          _scrollToBottom();
        }

        return _messageList(
          entries,
          typingName: _npcTyping ? (npc['name'] as String? ?? 'NPC') : null,
        );
      },
    );
  }

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
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              '$typingName is typing...',
              style: const TextStyle(
                color: AppColors.softLilac,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          );
        }

        return _buildMessageBubble(entries[index - 1]);
      },
    );
  }

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

  String _formatTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

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
