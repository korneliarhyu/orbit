import 'package:flutter/material.dart';
import '../core/services/chat_storage.dart';
import '../core/theme/app_colors.dart';

class ChatScreen extends StatefulWidget {
  final String characterName;

  const ChatScreen({
    super.key,
    required this.characterName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller =
  TextEditingController();

  final ScrollController _scrollController =
  ScrollController();

  final ChatStore _store = ChatStore.instance;

  @override
  void initState() {
    super.initState();

    _store.addListener(_onChatUpdated);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _store.openChat(widget.characterName);
      _scrollToBottom(jump: true);
    });
  }

  void _onChatUpdated() {
    _scrollToBottom();
  }

  void _scrollToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _controller.text.trim();

    if (text.isEmpty) return;

    _controller.clear();

    setState(() {});

    _store.sendMessage(
      widget.characterName,
      text,
    );

    _scrollToBottom();
  }

  @override
  void dispose() {
    _store.removeListener(_onChatUpdated);
    _store.closeChat(widget.characterName);

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
          // COSMIC BACKGROUND
          Positioned.fill(
            child: Image.asset(
              'lib/core/assets/bg.jpg',
              fit: BoxFit.cover,
            ),
          ),

          // DARK OVERLAY
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0xE60B0914),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(),

                Expanded(
                  child: AnimatedBuilder(
                    animation: _store,
                    builder: (context, child) {
                      return _buildMessages();
                    },
                  ),
                ),

                _buildInput(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // CHAT HEADER
  Widget _buildHeader() {
    final isGroup =
        widget.characterName == 'Northside Crew';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 12,
      ),

      decoration: const BoxDecoration(
        color: Color(0xE8151024),
        border: Border(
          bottom: BorderSide(
            color: AppColors.border,
          ),
        ),
      ),

      child: Row(
        children: [
          IconButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            icon: const Icon(
              Icons.arrow_back_ios_new,
              size: 19,
              color: AppColors.textPrimary,
            ),
          ),

          CircleAvatar(
            radius: 23,
            backgroundColor: AppColors.primaryPurple,
            child: isGroup
                ? const Icon(
              Icons.groups_rounded,
              color: Colors.white,
            )
                : Text(
              widget.characterName[0],
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
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
                  widget.characterName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 4),

                const Text(
                  'AI Character · Demo',
                  style: TextStyle(
                    color: AppColors.softLilac,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          const Icon(
            Icons.auto_awesome,
            color: AppColors.primaryPink,
          ),

          const SizedBox(width: 16),
        ],
      ),
    );
  }

  // MESSAGE HISTORY
  Widget _buildMessages() {
    final messages =
    _store.messagesFor(widget.characterName);

    final typing =
    _store.isTyping(widget.characterName);

    return ListView.builder(
      controller: _scrollController,

      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 20,
      ),

      itemCount: messages.length + 1 + (typing ? 1 : 0),

      itemBuilder: (context, index) {
        // Conversation divider
        if (index == 0) {
          return Center(
            child: Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 7,
              ),
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

        // Typing indicator
        if (index > messages.length) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              '${widget.characterName} is typing...',
              style: const TextStyle(
                color: AppColors.softLilac,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          );
        }

        final message = messages[index - 1];

        return _buildMessageBubble(message);
      },
    );
  }

  // MESSAGE BUBBLE
  Widget _buildMessageBubble(OrbitMessage message) {
    return Align(
      alignment: message.isMine
          ? Alignment.centerRight
          : Alignment.centerLeft,

      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.76,
        ),

        margin: const EdgeInsets.only(bottom: 12),

        padding: const EdgeInsets.fromLTRB(
          14,
          12,
          12,
          8,
        ),

        decoration: BoxDecoration(
          gradient: message.isMine
              ? AppColors.primaryGradient
              : null,

          color: message.isMine
              ? null
              : AppColors.card,

          border: message.isMine
              ? null
              : Border.all(color: AppColors.border),

          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),

            bottomLeft: Radius.circular(
              message.isMine ? 20 : 5,
            ),

            bottomRight: Radius.circular(
              message.isMine ? 5 : 20,
            ),
          ),
        ),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                message.text,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),

            const SizedBox(height: 6),

            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _store.formatTime(message.sentAt),
                  style: TextStyle(
                    color: message.isMine
                        ? Colors.white70
                        : AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),

                if (message.isMine) ...[
                  const SizedBox(width: 4),

                  const Icon(
                    Icons.done_all_rounded,
                    size: 14,
                    color: Colors.white70,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // MESSAGE COMPOSER
  Widget _buildInput() {
    final canSend = _controller.text.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),

      decoration: const BoxDecoration(
        color: Color(0xF0151024),
        border: Border(
          top: BorderSide(
            color: AppColors.border,
          ),
        ),
      ),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.cardSoft,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: AppColors.border,
                ),
              ),

              padding: const EdgeInsets.symmetric(
                horizontal: 16,
              ),

              child: TextField(
                controller: _controller,

                minLines: 1,
                maxLines: 4,

                textCapitalization:
                TextCapitalization.sentences,

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

                decoration: InputDecoration(
                  hintText:
                  'Message ${widget.characterName}...',

                  hintStyle: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),

                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,

                  contentPadding:
                  const EdgeInsets.symmetric(
                    vertical: 13,
                  ),
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

              disabledBackgroundColor:
              AppColors.cardSoft,

              disabledForegroundColor:
              AppColors.textSecondary,

              minimumSize: const Size(46, 46),
            ),

            icon: const Icon(
              Icons.arrow_upward_rounded,
            ),
          ),
        ],
      ),
    );
  }
}
