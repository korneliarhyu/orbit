import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_radius.dart';
import '../core/constants/app_spacing.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/widgets/app_avatar.dart';
import '../core/widgets/app_chat_tile.dart';
import '../core/widgets/orbit_logo.dart';
import 'chat/chat_screen.dart';
import 'chat/npc_chat_service.dart';
import 'discover/discover_screen.dart';
import 'discover/match_service.dart';
import 'profile/profile_screen.dart';

// ============================================================
// ORBIT - LUNAR LAVENDER CHAT INBOX
// ============================================================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String _favoriteKey = 'orbit_favorite_npc_ids';

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final PageController _pageController = PageController();

  late final Stream<List<OrbitMatch>> _matchesStream;

  final Set<String> _favorites = <String>{};
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _matchesStream = MatchService.instance.watchMatches();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _favorites
        ..clear()
        ..addAll(prefs.getStringList(_favoriteKey) ?? const <String>[]);
    });
  }

  Future<void> _toggleFavorite(String npcId) async {
    setState(() {
      if (!_favorites.add(npcId)) {
        _favorites.remove(npcId);
      }
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoriteKey, _favorites.toList());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _goToTab(int index) {
    if (!_pageController.hasClients) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _openMatch(OrbitMatch match) {
    MatchService.instance.markOpened(match.npcId).catchError((error) {
      debugPrint('Could not mark match as opened: $error');
    });

    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ChatScreen(npcId: match.npcId)),
    );
  }

  // Search only. Include active and ended conversations.
  List<OrbitMatch> _filterMatches(List<OrbitMatch> matches) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return matches;

    return matches
        .where((match) {
          return match.name.toLowerCase().contains(query) ||
              match.archetype.toLowerCase().contains(query) ||
              (match.career?.toLowerCase().contains(query) ?? false);
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) => setState(() => _selectedTab = index),
        children: [
          _buildChatsPage(),
          const DiscoverScreen(),
          const Center(child: Text('World')),
          const ProfileScreen(showEnterButton: false),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _buildChatsPage() {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageHorizontal,
              AppSpacing.sm,
              AppSpacing.pageHorizontal,
              AppSpacing.sm,
            ),
            child: _buildHeader(),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pageHorizontal,
              ),
              child: _buildMatchesList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const OrbitLogo(wordmark: true, size: 80),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: _buildSearchBar()),
      ],
    );
  }

  Widget _buildSearchBar() {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.searchBar),
      borderSide: BorderSide.none,
    );

    return TextField(
      controller: _searchController,
      focusNode: _searchFocusNode,
      onChanged: (_) => setState(() {}),
      style: AppTextStyles.input,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search conversations...',
        hintStyle: AppTextStyles.inputHint,
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                tooltip: 'Clear search',
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                },
              )
            : null,
        filled: true,
        fillColor: AppColors.surface,
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
      ),
    );
  }

  Widget _buildMatchesList() {
    return StreamBuilder<List<OrbitMatch>>(
      stream: _matchesStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _status('Unable to load matches.');
        }
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        final allMatches = snapshot.data!;
        final matches = _filterMatches(allMatches);
        if (matches.isEmpty) {
          return _buildEmptyState(noMatchesYet: allMatches.isEmpty);
        }

        // Open conversation list; the shared tile owns row styling.
        return ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: matches.length,
          itemBuilder: (context, index) {
            final match = matches[index];
            return _MatchConversationTile(
              key: ValueKey(match.npcId),
              match: match,
              isFavorite: _favorites.contains(match.npcId),
              onToggleFavorite: () => _toggleFavorite(match.npcId),
              onTap: () => _openMatch(match),
            );
          },
        );
      },
    );
  }

  Widget _status(String text) =>
      Center(child: Text(text, style: AppTextStyles.bodyMuted));

  Widget _buildEmptyState({required bool noMatchesYet}) {
    final hasSearch = _searchController.text.trim().isNotEmpty;
    final title = noMatchesYet
        ? 'No connections yet ✦'
        : hasSearch
        ? 'No conversations found'
        : 'No conversations yet';
    final subtitle = noMatchesYet
        ? 'Your next cosmic connection is just a swipe away.'
        : hasSearch
        ? 'Try another search.'
        : 'Your conversations will appear here.';

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.chat_bubble_outline_rounded,
            color: AppColors.primary,
            size: 42,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(title, textAlign: TextAlign.center, style: AppTextStyles.title),
          const SizedBox(height: AppSpacing.sm),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMuted,
          ),
          if (noMatchesYet) ...[
            const SizedBox(height: AppSpacing.xl),
            TextButton.icon(
              onPressed: () => _goToTab(1),
              icon: const Icon(Icons.explore_outlined),
              label: const Text('Explore Discover'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return BottomNavigationBar(
      currentIndex: _selectedTab,
      onTap: _goToTab,
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.chat_bubble_outline_rounded),
          activeIcon: Icon(Icons.chat_bubble_rounded),
          label: 'Chats',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.explore_outlined),
          activeIcon: Icon(Icons.explore_rounded),
          label: 'Discover',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.public_outlined),
          activeIcon: Icon(Icons.public_rounded),
          label: 'Upcoming Features',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline_rounded),
          activeIcon: Icon(Icons.person_rounded),
          label: 'Profile',
        ),
      ],
    );
  }
}

// ============================================================
// REAL-TIME CONVERSATION ROW
// ============================================================

class _MatchConversationTile extends StatefulWidget {
  const _MatchConversationTile({
    super.key,
    required this.match,
    required this.onTap,
    required this.isFavorite,
    required this.onToggleFavorite,
  });

  final OrbitMatch match;
  final VoidCallback onTap;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;

  @override
  State<_MatchConversationTile> createState() => _MatchConversationTileState();
}

class _MatchConversationTileState extends State<_MatchConversationTile> {
  late Stream<QuerySnapshot<Map<String, dynamic>>> _latestMessageStream;
  late Stream<DocumentSnapshot<Map<String, dynamic>>> _matchDetailStream;

  @override
  void initState() {
    super.initState();
    _initializeStreams();
  }

  @override
  void didUpdateWidget(covariant _MatchConversationTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.match.npcId != widget.match.npcId) {
      _initializeStreams();
    }
  }

  void _initializeStreams() {
    final service = NpcChatService.instance;
    _matchDetailStream = service.watchMatch(widget.match.npcId);
    _latestMessageStream = service.watchLastMessage(widget.match.npcId);
  }

  String _formatMessageTime(DateTime date) {
    final local = date.toLocal();
    final now = DateTime.now();
    if (now.year == local.year &&
        now.month == local.month &&
        now.day == local.day) {
      final hour = local.hour.toString().padLeft(2, '0');
      final minute = local.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }
    return '${local.day}/${local.month}';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _latestMessageStream,
      builder: (context, messageSnapshot) {
        Map<String, dynamic>? latest;
        if (messageSnapshot.hasData && messageSnapshot.data!.docs.isNotEmpty) {
          latest = messageSnapshot.data!.docs.first.data();
        }
        final lastText = latest?['text'] as String?;
        final sender = latest?['sender'] as String?;
        final createdAt = latest?['createdAt'];

        String preview = widget.match.preview;
        String time = widget.match.timeLabel;
        if (lastText != null && lastText.trim().isNotEmpty) {
          preview = sender == 'player'
              ? 'You: ${lastText.trim()}'
              : lastText.trim();
        }
        if (createdAt is Timestamp) {
          time = _formatMessageTime(createdAt.toDate());
        }
        if (widget.match.isEnded) preview = 'Ended · $preview';

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _matchDetailStream,
          builder: (context, detailSnapshot) {
            final avatarIndex = OrbitAvatar.indexFromMatchData(
              detailSnapshot.data?.data(),
            );

            return OrbitChatTile(
              name: widget.match.name,
              message: preview,
              time: time,
              avatarIndex: avatarIndex,
              unreadCount: widget.match.unread ? 1 : 0,
              isFavorite: widget.isFavorite,
              onToggleFavorite: widget.onToggleFavorite,
              onTap: widget.onTap,
            );
          },
        );
      },
    );
  }
}
