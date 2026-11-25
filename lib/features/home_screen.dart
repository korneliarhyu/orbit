import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/app_colors.dart';
import '../core/widgets/app_avatar.dart';
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
  bool _showSearch = false;
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
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(npcId: match.npcId),
      ),
    );
  }

  // Search only. Include active and ended conversations.
  List<OrbitMatch> _filterMatches(List<OrbitMatch> matches) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return matches;

    return matches.where((match) {
      return match.name.toLowerCase().contains(query) ||
          match.archetype.toLowerCase().contains(query) ||
          (match.career?.toLowerCase().contains(query) ?? false);
    }).toList(growable: false);
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

  // ============================================================
  // WHATSAPP-INSPIRED INBOX - DIM GALAXY, NO DIVIDERS
  // ============================================================

  void _toggleSearch() {
    setState(() {
      _showSearch = !_showSearch;
      if (!_showSearch) _searchController.clear();
    });

    if (_showSearch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocusNode.requestFocus();
      });
    } else {
      _searchFocusNode.unfocus();
    }
  }

  Widget _buildChatsPage() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // The existing galaxy is painted by main.dart.
        // This overlay dims it only on the Chats tab.
        const Positioned.fill(
          child: IgnorePointer(
            child: ColoredBox(
              color: Color(0x8012101D),
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
                child: _buildHeader(context),
              ),

              // WhatsApp-style: search is shown on demand.
              if (_showSearch)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: _buildSearchBar(),
                ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                  child: _buildMatchesList(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(
          'lib/core/assets/orbit_wordmark.png',
          width: 80,
          fit: BoxFit.contain,
        ),

        const SizedBox(width: 14),

        Expanded(
          child: SizedBox(
            height: 42,
            child: _buildSearchBar(),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.93),
        borderRadius: BorderRadius.circular(25),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onChanged: (_) => setState(() {}),
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search conversations...',
          hintStyle: const TextStyle(color: AppColors.textSecondary),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.textSecondary,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
            tooltip: 'Clear search',
            icon: const Icon(Icons.close_rounded, size: 18),
            color: AppColors.textSecondary,
            onPressed: () {
              _searchController.clear();
              setState(() {});
            },
          )
              : null,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
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

        // WhatsApp-like conversation rows with no dividers or enclosing card.
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

  Widget _status(String text) => Center(
    child: Text(text, style: const TextStyle(color: AppColors.textSecondary)),
  );

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
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          if (noMatchesYet) ...[
            const SizedBox(height: 20),
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
      // Match the same Lunar Night dim used in Chats and Discover.
      backgroundColor: const Color(0x8012101D),
      elevation: 0,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textSecondary,
      selectedFontSize: 11,
      unselectedFontSize: 11,
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
    _latestMessageStream = service
        .matchRef(widget.match.npcId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots();
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
          preview = sender == 'player' ? 'You: ${lastText.trim()}' : lastText.trim();
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

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  child: Row(
                    children: [
                      OrbitAvatar(
                        name: widget.match.name,
                        radius: 29,
                        avatarIndex: avatarIndex,
                        // A wider crop: show hair and more of the shoulders.
                        portraitScale: 1.38,
                        highlighted: widget.match.unread,
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    widget.match.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 17,
                                      fontWeight: widget.match.unread
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  time,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    preview,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: widget.match.unread
                                          ? AppColors.textPrimary
                                          : AppColors.textSecondary,
                                      fontSize: 13,
                                      fontWeight: widget.match.unread
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                if (widget.match.unread) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    height: 21,
                                    width: 21,
                                    alignment: Alignment.center,
                                    decoration: const BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Text('1',
                                        style: TextStyle(
                                            color: AppColors.onPrimary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700)),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: widget.isFavorite
                            ? 'Remove from favorites'
                            : 'Add to favorites',
                        onPressed: widget.onToggleFavorite,
                        visualDensity: VisualDensity.compact,
                        iconSize: 19,
                        icon: Icon(
                          widget.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                          color: widget.isFavorite
                              ? AppColors.secondary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}