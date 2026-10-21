
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// MODEL PESAN
class OrbitMessage {
  final String text;
  final bool isMine;
  final DateTime sentAt;

  const OrbitMessage({
    required this.text,
    required this.isMine,
    required this.sentAt,
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    'isMine': isMine,
    'sentAt': sentAt.toIso8601String(),
  };

  factory OrbitMessage.fromJson(Map<String, dynamic> json) {
    return OrbitMessage(
      text: json['text'] as String,
      isMine: json['isMine'] as bool,
      sentAt: DateTime.parse(json['sentAt'] as String),
    );
  }
}

// CHAT STORE
class ChatStore extends ChangeNotifier {
  ChatStore._();

  static final ChatStore instance = ChatStore._();

  static const String _storageKey = 'orbit_chat_v1';

  final SharedPreferencesAsync _prefs =
  SharedPreferencesAsync();

  final Map<String, List<OrbitMessage>> _threads = {};
  final Map<String, int> _unread = {};
  final Set<String> _typing = {};

  String? _activeChat;
  Future<void> _writeQueue = Future<void>.value();

  // INITIAL LOAD
  Future<void> initialize() async {
    try {
      final saved = await _prefs.getString(_storageKey);

      if (saved == null) {
        _seedDemoMessages();
        _save();
        return;
      }

      final data = jsonDecode(saved) as Map<String, dynamic>;

      final threads = data['threads'] as Map<String, dynamic>;

      for (final entry in threads.entries) {
        _threads[entry.key] = (entry.value as List)
            .map(
              (item) => OrbitMessage.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
            .toList();
      }

      final unread =
          data['unread'] as Map<String, dynamic>? ?? {};

      for (final entry in unread.entries) {
        _unread[entry.key] = (entry.value as num).toInt();
      }
    } catch (error) {
      debugPrint('Failed to load chat: $error');
      _threads.clear();
      _unread.clear();
      _seedDemoMessages();
      _save();
    }
  }

  // INITIAL DEMO DATA
  void _seedDemoMessages() {
    final now = DateTime.now();

    OrbitMessage demo(
        String text,
        int minutesAgo, {
          bool mine = false,
        }) {
      return OrbitMessage(
        text: text,
        isMine: mine,
        sentAt: now.subtract(
          Duration(minutes: minutesAgo),
        ),
      );
    }

    _threads.addAll({
      'Mika': [
        demo('heyyyy!! you are finally here 😭💜', 12),
        demo('BROOO I have news 😭', 5),
      ],
      'Noah': [
        demo('you still playing tonight?', 45),
      ],
      'Aria': [
        demo(
          'Good luck with your project!',
          130,
          mine: true,
        ),
      ],
      'Ezra': [
        demo('sent you a photo 📸', 180),
      ],
      'Jules': [
        demo('Thanks. I appreciate it.', 240),
      ],
      'Northside Crew': [
        demo('Mika: guys, friday night??', 300),
      ],
    });

    _unread.addAll({
      'Mika': 2,
      'Noah': 1,
    });
  }

  // GET MESSAGES
  List<OrbitMessage> messagesFor(String name) {
    return List.unmodifiable(_threads[name] ?? []);
  }

  OrbitMessage? lastMessageFor(String name) {
    final messages = _threads[name];

    if (messages == null || messages.isEmpty) {
      return null;
    }

    return messages.last;
  }

  // HOME SCREEN PREVIEW
  String previewFor(String name) {
    final message = lastMessageFor(name);

    if (message == null) return 'Start a conversation';

    return message.isMine
        ? 'You: ${message.text}'
        : message.text;
  }

  String timeFor(String name) {
    final message = lastMessageFor(name);

    if (message == null) return '';

    final date = message.sentAt;
    final now = DateTime.now();

    if (DateUtils.isSameDay(date, now)) {
      return formatTime(date);
    }

    final yesterday = DateTime(
      now.year,
      now.month,
      now.day - 1,
    );

    if (DateUtils.isSameDay(date, yesterday)) {
      return 'Yesterday';
    }

    return '${date.day}/${date.month}';
  }

  String formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  DateTime? lastAt(String name) {
    return lastMessageFor(name)?.sentAt;
  }

  int unreadCount(String name) {
    return _unread[name] ?? 0;
  }

  bool isTyping(String name) {
    return _typing.contains(name);
  }

  // OPEN / CLOSE CHAT
  void openChat(String name) {
    _activeChat = name;
    markRead(name);
  }

  void closeChat(String name) {
    if (_activeChat == name) {
      _activeChat = null;
    }
  }

  void markRead(String name) {
    if ((_unread[name] ?? 0) == 0) return;

    _unread[name] = 0;
    notifyListeners();
    _save();
  }

  // SEND A NEW MESSAGE
  void sendMessage(String name, String text) {
    final cleanText = text.trim();

    if (cleanText.isEmpty) return;

    _addMessage(
      name,
      OrbitMessage(
        text: cleanText,
        isMine: true,
        sentAt: DateTime.now(),
      ),
    );

    // Simulate an AI character typing
    _typing.add(name);
    notifyListeners();

    Future.delayed(
      const Duration(milliseconds: 1300),
          () {
        _typing.remove(name);

        final reply = _demoReply(name, cleanText);

        _addMessage(
          name,
          OrbitMessage(
            text: reply,
            isMine: false,
            sentAt: DateTime.now(),
          ),
          markUnread: _activeChat != name,
        );
      },
    );
  }

  void _addMessage(
      String name,
      OrbitMessage message, {
        bool markUnread = false,
      }) {
    _threads.putIfAbsent(name, () => []);

    _threads[name]!.add(message);

    if (markUnread) {
      _unread[name] = (_unread[name] ?? 0) + 1;
    }

    notifyListeners();
    _save();
  }

  // MOCK NPC REPLIES
  // These will be replaced by the AI backend later.
  String _demoReply(String name, String text) {
    final message = text.toLowerCase();

    switch (name) {
      case 'Mika':
        if (message.contains('noah')) {
          return 'NOAH??? omg where do I even start 😭';
        }
        if (message.contains('hello') ||
            message.contains('hey') ||
            message.contains('hai')) {
          return 'HEYYYY how have you been?? 💜';
        }
        return 'waittt tell me more about that 👀';

      case 'Noah':
        if (message.contains('game')) {
          return 'yeah, maybe later tonight. you joining?';
        }
        return 'hmm interesting. what happened next?';

      case 'Aria':
        return 'I see. That is actually interesting.';

      case 'Ezra':
        return 'LMAOO okay we need to talk about this 😭';

      case 'Jules':
        return 'Noted. Tell me more.';

      case 'Northside Crew':
        return 'Mika: OMG YESSS 😭';

      default:
        return 'Hey! Tell me more.';
    }
  }

  // SAVE TO DEVICE
  void _save() {
    final payload = jsonEncode({
      'threads': _threads.map(
            (name, messages) => MapEntry(
          name,
          messages.map((m) => m.toJson()).toList(),
        ),
      ),
      'unread': _unread,
    });

    // Keep writes in order.
    _writeQueue = _writeQueue.then((_) async {
      try {
        await _prefs.setString(_storageKey, payload);
      } catch (error) {
        debugPrint('Failed to save chat: $error');
      }
    });
  }
}
