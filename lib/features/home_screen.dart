import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/widgets/app_chat_tile.dart';
import '../core/services/chat_storage.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';

enum ChatFilter {
  all,
  unread,
  groups,
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final PageController _pageController = PageController();

  ChatFilter _selectedFilter = ChatFilter.all;
  int _selectedTab = 0;

  void _onTabTapped(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  // Temporary conversation data
  final List<_Conversation> _conversations = const [
    _Conversation(
      name: 'Mika',
      message: 'BROOO I have news 😭',
      time: '16:40',
      unreadCount: 2,
      isOnline: true,
      avatarColor: Color(0xFF934C91),
    ),
    _Conversation(
      name: 'Noah',
      message: 'you still playing tonight?',
      time: '15:20',
      unreadCount: 1,
      isOnline: true,
      avatarColor: Color(0xFF405AA0),
    ),
    _Conversation(
      name: 'Aria',
      message: 'You: Good luck with your project!',
      time: 'Yesterday',
      avatarColor: Color(0xFF995D96),
    ),
    _Conversation(
      name: 'Ezra',
      message: 'sent a photo 📸',
      time: 'Yesterday',
      avatarColor: Color(0xFFA6794C),
    ),
    _Conversation(
      name: 'Jules',
      message: 'Thanks. I appreciate it.',
      time: 'Monday',
      avatarColor: Color(0xFF527286),
    ),
    _Conversation(
      name: 'Northside Crew',
      message: 'Mika: guys, friday night??',
      time: 'Monday',
      isGroup: true,
      avatarColor: Color(0xFF8445B3),
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // Search + filter logic
  List<_Conversation> get _filteredConversations {
    final store = ChatStore.instance;

    final query =
    _searchController.text.trim().toLowerCase();

    final result = _conversations.where((conversation) {
      final preview = store.previewFor(conversation.name);
      final unread = store.unreadCount(conversation.name);

      final matchesSearch =
          conversation.name.toLowerCase().contains(query) ||
              preview.toLowerCase().contains(query);

      final matchesFilter = switch (_selectedFilter) {
        ChatFilter.all => true,
        ChatFilter.unread => unread > 0,
        ChatFilter.groups => conversation.isGroup,
      };

      return matchesSearch && matchesFilter;
    }).toList();

    // Newest conversations first
    result.sort((a, b) {
      final aTime = store.lastAt(a.name);
      final bTime = store.lastAt(b.name);

      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;

      return bTime.compareTo(aTime);
    });
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: PageView(
        controller: _pageController,

        onPageChanged: (index) {
          setState(() {
            _selectedTab = index;
          });
        },

        children: [
          // Tab 0: Chats asli ORBIT
          _buildChatsPage(),

          // Tab 1: Discover
          const Center(
            child: Text('Discover'),
          ),

          // Tab 2: World
          const Center(
            child: Text('World'),
          ),

          // Tab 3: Profile
          const ProfileScreen(
            showEnterButton: false,
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  // MAIN CHAT PAGE
  Widget _buildChatsPage() {
    final conversations = _filteredConversations;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
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

          // Large central chat card
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xF0181424),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.border,
                ),
              ),

              clipBehavior: Clip.antiAlias,

              child: conversations.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                padding: const EdgeInsets.symmetric(
                  vertical: 6,
                ),

                itemCount: conversations.length,

                separatorBuilder: (context, index) {
                  return const Divider(
                    height: 1,
                    indent: 84,
                    endIndent: 16,
                    color: AppColors.border,
                  );
                },

                itemBuilder: (context, index) {
                  final chat = conversations[index];

                  return OrbitChatTile(
                    name: chat.name,
                    message: ChatStore.instance.previewFor(chat.name),
                    time: ChatStore.instance.timeFor(chat.name),
                    unreadCount:
                    ChatStore.instance.unreadCount(chat.name),
                    isOnline: chat.isOnline,
                    isGroup: chat.isGroup,
                    avatarColor: chat.avatarColor,
                    onTap: () => _openConversation(chat),
                  );

                },
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // HEADER
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
          onPressed: () {
            setState(() {
              _selectedTab = 1;
            });
          },
          icon: const Icon(
            Icons.edit_square,
            color: AppColors.softLilac,
          ),
        ),
      ],
    );
  }

  // SEARCH FIELD
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

        onChanged: (_) {
          setState(() {});
        },

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

  // FILTER CHIPS
  Widget _buildFilters() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildFilterChip('All', ChatFilter.all),
        _buildFilterChip('Unread', ChatFilter.unread),
        _buildFilterChip('Groups', ChatFilter.groups),
      ],
    );
  }

  Widget _buildFilterChip(
      String label,
      ChatFilter filter,
      ) {
    final isSelected = _selectedFilter == filter;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedFilter = filter;
        });
      },

      borderRadius: BorderRadius.circular(30),

      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 9,
        ),

        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryPurple
              : AppColors.cardSoft,

          borderRadius: BorderRadius.circular(30),

          border: Border.all(
            color: isSelected
                ? AppColors.primaryPurple
                : AppColors.border,
          ),
        ),

        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : AppColors.softLilac,

            fontSize: 12,

            fontWeight: isSelected
                ? FontWeight.w600
                : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  // EMPTY SEARCH RESULT
  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.mark_chat_unread_outlined,
            color: AppColors.softLilac,
            size: 48,
          ),
          SizedBox(height: 16),

          Text(
            'No conversations found',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),

          Text(
            'Try another search or filter.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // OPEN CHAT PLACEHOLDER
  void _openConversation(_Conversation chat) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ChatScreen(
          characterName: chat.name,
        ),
      ),
    );
  }

  // OTHER TABS PLACEHOLDER
  Widget _buildPlaceholderPage() {
    const names = [
      'Chats',
      'Discover',
      'World',
      'Profile',
    ];

    final name = names[_selectedTab];

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            color: AppColors.primaryPink,
            size: 54,
          ),

          const SizedBox(height: 20),

          Text(
            name,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Coming soon to your universe.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // BOTTOM NAVIGATION
  Widget _buildBottomNavigation() {
    return BottomNavigationBar(
      currentIndex: _selectedTab,
      onTap: _onTabTapped,

      type: BottomNavigationBarType.fixed,

      backgroundColor: AppColors.background,
      selectedItemColor: AppColors.primaryPink,
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

// TEMPORARY CONVERSATION MODEL
class _Conversation {
  final String name;
  final String message;
  final String time;
  final int unreadCount;
  final bool isOnline;
  final bool isGroup;
  final Color avatarColor;

  const _Conversation({
    required this.name,
    required this.message,
    required this.time,
    required this.avatarColor,
    this.unreadCount = 0,
    this.isOnline = false,
    this.isGroup = false,
  });
}

// TEMPORARY CHAT DETAIL
// Will be replaced by ChatScreen later
class _ChatPlaceholderScreen extends StatelessWidget {
  final String name;

  const _ChatPlaceholderScreen({
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        title: Text(name),
      ),

      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.chat_bubble_outline_rounded,
              size: 58,
              color: AppColors.primaryPink,
            ),

            const SizedBox(height: 20),

            Text(
              'Your conversation with $name',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 10),

            const Text(
              'Chat screen coming next!',
              style: TextStyle(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
