
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/widgets/app_chat_tile.dart';

import 'chat/chat_screen.dart';
import 'chat/npc_chat_service.dart';
import 'discover/discover_screen.dart';
import 'discover/match_service.dart';
import 'profile/profile_screen.dart';

// ============================================================
// CHAT FILTER
// ============================================================
enum ChatFilter { all, unread }

// ============================================================
// HOME SCREEN
// ============================================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController =
  TextEditingController();

  final PageController _pageController = PageController();

  late final Stream<List<OrbitMatch>> _matchesStream;

  ChatFilter _selectedFilter = ChatFilter.all;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _matchesStream = MatchService.instance.watchMatches();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // ==========================================================
  // NAVIGATION
  // ==========================================================
  void _goToTab(int index) {
    if (!_pageController.hasClients) return;

    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _openMatch(OrbitMatch match) {
    MatchService.instance.markOpened(match.npcId).catchError(
          (error) {
        debugPrint('Could not mark match as opened: $error');
      },
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          npcId: match.npcId,
        ),
      ),
    );
  }

  // ==========================================================
  // SEARCH & FILTER
  // ==========================================================
  List<OrbitMatch> _filterMatches(
      List<OrbitMatch> matches,
      ) {
    final query = _searchController.text
        .trim()
        .toLowerCase();

    return matches.where((match) {
      final matchesSearch =
          match.name.toLowerCase().contains(query) ||
              match.archetype.toLowerCase().contains(query) ||
              (match.career?.toLowerCase().contains(query) ?? false);

      final matchesFilter =
          _selectedFilter == ChatFilter.all || match.unread;

      return matchesSearch && matchesFilter;
    }).toList(growable: false);
  }

  // ==========================================================
  // MAIN LAYOUT
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() => _selectedTab = index);
        },
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

  // ==========================================================
  // CHATS PAGE
  // ==========================================================

  Widget _buildChatsPage() {
    return SafeArea(
      top: true,
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          20,
          12,
          20,
          0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),

            const SizedBox(height: 24),

            _buildSearchBar(),

            const SizedBox(height: 18),

            _buildFilters(),

            const SizedBox(height: 22),

            const Text(
              'Your Messages',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 6),

            const Text(
              'Stay connected across your universe.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),

            const SizedBox(height: 20),

            Expanded(
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: const Color(0xF0181424),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.border,
                  ),
                ),
                child: _buildMatchesList(),
              ),
            ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // MATCH LIST
  // ==========================================================

  Widget _buildMatchesList() {
    return StreamBuilder<List<OrbitMatch>>(
      stream: _matchesStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'Unable to load matches',
              style: TextStyle(
                color: AppColors.textSecondary,
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(
              color: AppColors.primaryPink,
            ),
          );
        }

        final allMatches = snapshot.data!;
        final matches = _filterMatches(allMatches);

        if (matches.isEmpty) {
          return _buildEmptyState(
            noMatchesYet: allMatches.isEmpty,
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(
            vertical: 6,
          ),
          itemCount: matches.length,
          separatorBuilder: (_, _) => const Divider(
            height: 1,
            indent: 84,
            endIndent: 16,
            color: AppColors.border,
          ),
          itemBuilder: (context, index) {
            final match = matches[index];

            // Each tile watches its own latest message.
            return _MatchConversationTile(
              key: ValueKey(match.npcId),
              match: match,
              onTap: () => _openMatch(match),
            );
          },
        );
      },
    );
  }

  // ==========================================================
  // ORBIT HEADER
  // ==========================================================

  Widget _buildHeader() {
    return Row(
      children: [
        const Icon(
          Icons.auto_awesome_rounded,
          color: AppColors.primaryPink,
          size: 27,
        ),

        const SizedBox(width: 10),

        const Expanded(
          child: Text(
            'ORBIT',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 27,
              fontWeight: FontWeight.bold,
              letterSpacing: 3,
            ),
          ),
        ),

        IconButton(
          tooltip: 'Discover people',
          onPressed: () => _goToTab(1),
          icon: const Icon(
            Icons.edit_square,
            color: AppColors.softLilac,
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // SEARCH BAR
  // ==========================================================

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
        ),
        decoration: const InputDecoration(
          hintText: 'Search conversations...',
          prefixIcon: Icon(
            Icons.search_rounded,
            color: AppColors.textSecondary,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          contentPadding: EdgeInsets.symmetric(
            vertical: 14,
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // FILTER CHIPS
  // ==========================================================

  Widget _buildFilters() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final filter in ChatFilter.values)
          ChoiceChip(
            label: Text(
              filter == ChatFilter.all
                  ? 'All'
                  : 'Unread',
            ),
            selected: _selectedFilter == filter,
            onSelected: (_) {
              setState(() => _selectedFilter = filter);
            },
            showCheckmark: false,
            selectedColor: AppColors.primaryPurple,
            backgroundColor: AppColors.cardSoft,
            side: BorderSide(
              color: _selectedFilter == filter
                  ? AppColors.primaryPurple
                  : AppColors.border,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
            labelStyle: TextStyle(
              color: _selectedFilter == filter
                  ? Colors.white
                  : AppColors.softLilac,
              fontSize: 12,
              fontWeight: _selectedFilter == filter
                  ? FontWeight.w600
                  : FontWeight.w400,
            ),
          ),
      ],
    );
  }

  // ==========================================================
  // EMPTY STATE
  // ==========================================================

  Widget _buildEmptyState({
    required bool noMatchesYet,
  }) {
    final isUnread =
        _selectedFilter == ChatFilter.unread;

    final hasSearch =
        _searchController.text.trim().isNotEmpty;

    final title = noMatchesYet
        ? 'No connections yet ✦'
        : hasSearch
        ? 'No conversations found'
        : isUnread
        ? 'All caught up ✦'
        : 'No conversations found';

    final subtitle = noMatchesYet
        ? 'Your next cosmic connection is just a swipe away.'
        : hasSearch
        ? 'Try another search.'
        : isUnread
        ? 'You have no unread messages.'
        : 'Try another search.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.favorite_border_rounded,
              color: AppColors.primaryPink,
              size: 52,
            ),

            const SizedBox(height: 18),

            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),

            if (noMatchesYet) ...[
              const SizedBox(height: 24),

              ElevatedButton.icon(
                onPressed: () => _goToTab(1),
                icon: const Icon(
                  Icons.explore_rounded,
                ),
                label: const Text('Explore Discover'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // BOTTOM NAVIGATION
  // ==========================================================

  Widget _buildBottomNavigation() {
    return BottomNavigationBar(
      currentIndex: _selectedTab,
      onTap: _goToTab,
      type: BottomNavigationBarType.fixed,
      backgroundColor: AppColors.background,
      selectedItemColor: AppColors.primaryPink,
      unselectedItemColor: AppColors.textSecondary,
      selectedFontSize: 11,
      unselectedFontSize: 11,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(
            Icons.chat_bubble_outline_rounded,
          ),
          activeIcon: Icon(
            Icons.chat_bubble_rounded,
          ),
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
          label: 'World',
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
// REAL-TIME CONVERSATION TILE
// ============================================================

class _MatchConversationTile extends StatefulWidget {
  final OrbitMatch match;
  final VoidCallback onTap;

  const _MatchConversationTile({
    super.key,
    required this.match,
    required this.onTap,
  });

  @override
  State<_MatchConversationTile> createState() =>
      _MatchConversationTileState();
}

class _MatchConversationTileState
    extends State<_MatchConversationTile> {

  late Stream<QuerySnapshot<Map<String, dynamic>>>
  _latestMessageStream;

  @override
  void initState() {
    super.initState();
    _initializeStream();
  }

  @override
  void didUpdateWidget(
      covariant _MatchConversationTile oldWidget,
      ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.match.npcId != widget.match.npcId) {
      _initializeStream();
    }
  }

  void _initializeStream() {
    // Listen to only ONE message, not the full chat history.
    _latestMessageStream = NpcChatService.instance
        .matchRef(widget.match.npcId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots();
  }

  String _formatMessageTime(DateTime date) {
    final local = date.toLocal();
    final now = DateTime.now();

    final isToday =
        now.year == local.year &&
            now.month == local.month &&
            now.day == local.day;

    if (isToday) {
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
      builder: (context, snapshot) {
        Map<String, dynamic>? latest;

        if (snapshot.hasData &&
            snapshot.data!.docs.isNotEmpty) {
          latest = snapshot.data!.docs.first.data();
        }

        final lastText = latest?['text'] as String?;
        final sender = latest?['sender'] as String?;
        final createdAt = latest?['createdAt'];

        // Fall back to the original match message.
        String preview = widget.match.preview;
        String time = widget.match.timeLabel;

        if (lastText != null &&
            lastText.trim().isNotEmpty) {
          preview = sender == 'player'
              ? 'You: ${lastText.trim()}'
              : lastText.trim();
        }

        if (createdAt is Timestamp) {
          time = _formatMessageTime(createdAt.toDate());
        }

        return OrbitChatTile(
          name: widget.match.name,
          message: preview,
          time: time,
          unreadCount: widget.match.unread ? 1 : 0,
          isOnline: false,
          isGroup: false,
          avatarColor: AppColors.primaryPurple,
          onTap: widget.onTap,
        );
      },
    );
  }
}
