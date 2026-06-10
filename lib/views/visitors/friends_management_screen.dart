import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../utils/services/friends_service.dart';
import '../../utils/services/house_service.dart';
import '../../utils/services/house_settings_service.dart';
import '../../models/house_settings.dart';
import '../visitors/visitor_profile_screen.dart';
import '../../core/sl_theme.dart';

class FriendsManagementScreen extends StatefulWidget {
  const FriendsManagementScreen({super.key});

  @override
  State<FriendsManagementScreen> createState() =>
      _FriendsManagementScreenState();
}

class _FriendsManagementScreenState extends State<FriendsManagementScreen>
    with SingleTickerProviderStateMixin {
  final _friendsService = FriendsService();
  final _houseService = HouseService();
  final _houseSettingsService = HouseSettingsService();
  final _searchCtrl = TextEditingController();
  late TabController _tabController;

  String? _myHouseId;
  String? _myHouseName;
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _suggestions = [];
  bool _isSearching = false;
  int _searchLimit = 50;
  int _suggestionLimit = 50;
  HouseSettings? _mySettings;

  late Stream<List<String>> _friendsStream;
  late Stream<FriendRequestsData> _requestsStream;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _init();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    _myHouseId = await _houseService.getCurrentHouseId();
    if (_myHouseId != null) {
      _mySettings = await _houseSettingsService.fetchSettings(_myHouseId!);
      _myHouseName = _mySettings?.houseName ?? 'Ngôi Nhà Ẩn Danh';
      _friendsStream = _friendsService.streamFriends(_myHouseId!);
      _requestsStream = _friendsService.streamFriendRequests(_myHouseId!);
      // Fetch some suggestions
      _suggestions = await _friendsService.searchHouses('');
    }
    if (mounted) setState(() {});
  }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _searchLimit = 50;
      });
      return;
    }
    setState(() {
      _isSearching = true;
      _searchLimit = 50;
    });
    final results = await _friendsService.searchHouses(q.trim());
    if (!mounted) return;
    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Bạn Bè & Lời Mời',
          style: SLTheme.quicksand(
            color: Colors.black87,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFD81B60),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFFD81B60),
          indicatorWeight: 3,
          labelStyle:
              SLTheme.quicksand(fontWeight: FontWeight.w800, fontSize: 14),
          tabs: const [
            Tab(text: 'Bạn bè'),
            Tab(text: 'Lời mời'),
            Tab(text: 'Tìm kiếm'),
          ],
        ),
      ),
      body: _myHouseId == null
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFD81B60)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildFriendsTab(),
                _buildRequestsTab(),
                _buildSearchTab(),
              ],
            ),
    );
  }

  Widget _buildFriendsTab() {
    return StreamBuilder<List<String>>(
      stream: _friendsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFFD81B60)));
        }
        final friendIds = snapshot.data ?? [];
        if (friendIds.isEmpty) {
          return _buildEmptyState(
              '👥', 'Bạn chưa có bạn bè nào.\nHãy tìm kiếm và kết bạn nhé!');
        }

        // Separate favorite friends
        // Favorite friends in HouseSettings might be a Map if implemented that way,
        // but looking at HouseSettings model, it doesn't have favoriteFriends field.
        // It's likely in the raw database data but not in the model.
        // Let's check how it's handled in FriendsService.
        // Based on core-friends.js, it's in settings/favoriteFriends.
        // If it's not in the model, we might need to fetch it separately or update the model.
        // For now, let's assume it might not be in the model and just skip the favorite section if model doesn't support it,
        // or just use a simple list.

        return ListView.builder(
          padding: SLSpacing.all16,
          itemCount: friendIds.length + 2,
          itemBuilder: (context, index) {
            if (index == 0) {
              return _buildSectionHeader('Tất cả bạn bè (${friendIds.length})');
            }
            if (index == 1) return SLSpacing.h12;

            final id = friendIds[index - 2];
            return _FriendItemTile(
              houseId: id,
              isFavorite: false,
              onTap: () => _openProfile(id),
              onToggleFav: () => _toggleFavorite(id),
              onWave: () => _sendWave(id),
            );
          },
        );
      },
    );
  }

  Widget _buildRequestsTab() {
    return StreamBuilder<FriendRequestsData>(
      stream: _requestsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFFD81B60)));
        }
        final data = snapshot.data;
        final received = data?.received ?? {};
        final sent = data?.sent ?? {};

        if (received.isEmpty && sent.isEmpty) {
          return _buildEmptyState('📨', 'Không có lời mời kết bạn nào.');
        }

        return ListView(
          padding: SLSpacing.all16,
          children: [
            if (received.isNotEmpty) ...[
              _buildSectionHeader('Chờ bạn chấp nhận (${received.length})'),
              SLSpacing.h12,
              ...received.entries.map((e) => _RequestItemTile(
                    houseId: e.key,
                    requestId: e.value,
                    isReceived: true,
                    onAccept: () => _friendsService.acceptFriendRequest(
                      requestId: e.value,
                      currentHouseId: _myHouseId!,
                      fromHouseId: e.key,
                    ),
                    onDecline: () => _friendsService.declineFriendRequest(
                        e.value, _myHouseId!),
                    onTap: () => _openProfile(e.key),
                  )),
              SLSpacing.h24,
            ],
            if (sent.isNotEmpty) ...[
              _buildSectionHeader('Lời mời đã gửi (${sent.length})'),
              SLSpacing.h12,
              ...sent.entries.map((e) => _RequestItemTile(
                    houseId: e.key,
                    requestId: e.value,
                    isReceived: false,
                    onCancel: () => _friendsService.cancelSentFriendRequest(
                        e.value, _myHouseId!),
                    onTap: () => _openProfile(e.key),
                  )),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSearchTab() {
    final showSuggestions = _searchCtrl.text.trim().isEmpty;
    final list = showSuggestions ? _suggestions : _searchResults;
    final currentLimit = showSuggestions ? _suggestionLimit : _searchLimit;
    final displayList = list.take(currentLimit).toList();
    final hasMore = list.length > currentLimit;

    return Column(
      children: [
        Padding(
          padding: SLSpacing.all16,
          child: TextField(
            controller: _searchCtrl,
            style: SLTheme.quicksand(fontWeight: FontWeight.w700, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Tìm bạn bè, mã nhà, hoặc liên kết...',
              hintStyle: SLTheme.quicksand(color: Colors.grey),
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onChanged: _search,
          ),
        ),
        Expanded(
          child: _isSearching
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFFD81B60)))
              : displayList.isEmpty
                  ? _buildEmptyState('🔍', 'Không tìm thấy kết quả nào.')
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      itemCount: displayList.length +
                          (showSuggestions ? 1 : 0) +
                          (hasMore ? 1 : 0),
                      separatorBuilder: (_, __) => SLSpacing.h8,
                      itemBuilder: (context, index) {
                        if (showSuggestions && index == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10, top: 5),
                            child: _buildSectionHeader('Gợi ý kết bạn 🌍'),
                          );
                        }

                        final itemIndex = showSuggestions ? index - 1 : index;

                        if (itemIndex == displayList.length) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: TextButton(
                                onPressed: () {
                                  setState(() {
                                    if (showSuggestions) {
                                      _suggestionLimit += 50;
                                    } else {
                                      _searchLimit += 50;
                                    }
                                  });
                                },
                                style: TextButton.styleFrom(
                                  backgroundColor:
                                      const Color(0xFFD81B60).withValues(alpha: 0.1),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 12),
                                ),
                                child: Text(
                                  'Xem thêm',
                                  style: SLTheme.quicksand(
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFFD81B60),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }

                        final item = displayList[itemIndex];
                        return _SearchItemTile(
                          item: item,
                          myHouseId: _myHouseId!,
                          onTap: () => _openProfile(item['id']),
                          onAdd: () => _addFriend(item['id']),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: const Color(0xFFD81B60),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          SLSpacing.w8,
          Text(
            title.toUpperCase(),
            style: SLTheme.quicksand(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF4A5568),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // Helper to build empty state
  Widget _buildEmptyState(String emoji, String text) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: SLSpacing.all24,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 48)),
          ),
          SLSpacing.h24,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                fontSize: 15,
                color: const Color(0xFF718096),
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openProfile(String houseId) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => VisitorProfileScreen(targetHouseId: houseId)),
    );
  }

  Future<void> _toggleFavorite(String friendId) async {
    await _friendsService.toggleFavoriteFriend(_myHouseId!, friendId);
    // Refresh settings
    _mySettings = await _houseSettingsService.fetchSettings(_myHouseId!);
    if (mounted) setState(() {});
  }

  Future<void> _sendWave(String friendId) async {
    await _friendsService.sendFriendWave(
      myHouseId: _myHouseId!,
      myHouseName: _myHouseName ?? 'Bạn bè',
      friendHouseId: friendId,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Đã gửi lời chào 👋'),
            duration: Duration(seconds: 1)),
      );
    }
  }

  Future<void> _addFriend(String toId) async {
    final res = await _friendsService.sendFriendRequest(
      fromHouseId: _myHouseId!,
      fromHouseName: _myHouseName ?? 'Bạn bè',
      toHouseId: toId,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message)),
      );
    }
  }
}

class _FriendItemTile extends StatefulWidget {
  final String houseId;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onToggleFav;
  final VoidCallback onWave;

  const _FriendItemTile({
    required this.houseId,
    required this.isFavorite,
    required this.onTap,
    required this.onToggleFav,
    required this.onWave,
  });

  @override
  State<_FriendItemTile> createState() => _FriendItemTileState();
}

class _FriendItemTileState extends State<_FriendItemTile> {
  late Future<HouseSettings?> _settingsFuture;

  @override
  void initState() {
    super.initState();
    _settingsFuture = HouseSettingsService().fetchSettings(widget.houseId);
  }

  @override
  void didUpdateWidget(covariant _FriendItemTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.houseId != widget.houseId) {
      _settingsFuture = HouseSettingsService().fetchSettings(widget.houseId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<HouseSettings?>(
      future: _settingsFuture,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final name = data?.houseName ?? widget.houseId;
        final avatar = data?.houseAvatar;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: SLRadius.lgAll,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2))
            ],
          ),
          child: ListTile(
            onTap: widget.onTap,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFFFFB3C6),
              backgroundImage: (avatar != null && avatar.isNotEmpty)
                  ? CachedNetworkImageProvider(avatar)
                  : null,
              child: (avatar == null || avatar.isEmpty)
                  ? Text(name[0].toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold))
                  : null,
            ),
            title: Text(name,
                style: SLTheme.quicksand(
                    fontWeight: FontWeight.w800, fontSize: 15)),
            subtitle: Text(
                'ID: ${widget.houseId.length > 8 ? "${widget.houseId.substring(0, 8)}..." : widget.houseId}',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(widget.isFavorite ? Icons.star : Icons.star_border,
                      color: widget.isFavorite ? Colors.amber : Colors.grey),
                  onPressed: widget.onToggleFav,
                  tooltip: widget.isFavorite ? 'Bỏ ghim' : 'Ghim bạn thân',
                ),
                IconButton(
                  icon: const Icon(Icons.back_hand_outlined,
                      color: Color(0xFFD81B60), size: 20),
                  onPressed: widget.onWave,
                  tooltip: 'Gửi lời chào',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RequestItemTile extends StatefulWidget {
  final String houseId;
  final String requestId;
  final bool isReceived;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final VoidCallback? onCancel;
  final VoidCallback onTap;

  const _RequestItemTile({
    required this.houseId,
    required this.requestId,
    required this.isReceived,
    this.onAccept,
    this.onDecline,
    this.onCancel,
    required this.onTap,
  });

  @override
  State<_RequestItemTile> createState() => _RequestItemTileState();
}

class _RequestItemTileState extends State<_RequestItemTile> {
  late Future<HouseSettings?> _settingsFuture;

  @override
  void initState() {
    super.initState();
    _settingsFuture = HouseSettingsService().fetchSettings(widget.houseId);
  }

  @override
  void didUpdateWidget(covariant _RequestItemTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.houseId != widget.houseId) {
      _settingsFuture = HouseSettingsService().fetchSettings(widget.houseId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<HouseSettings?>(
      future: _settingsFuture,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final name = data?.houseName ?? widget.houseId;
        final avatar = data?.houseAvatar;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: SLRadius.lgAll,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2))
            ],
          ),
          child: ListTile(
            onTap: widget.onTap,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFFE3F2FD),
              backgroundImage: (avatar != null && avatar.isNotEmpty)
                  ? CachedNetworkImageProvider(avatar)
                  : null,
              child: (avatar == null || avatar.isEmpty)
                  ? Text(name[0].toUpperCase(),
                      style: const TextStyle(
                          color: Colors.blue, fontWeight: FontWeight.bold))
                  : null,
            ),
            title: Text(name,
                style: SLTheme.quicksand(
                    fontWeight: FontWeight.w800, fontSize: 14)),
            subtitle: Text(
                widget.isReceived
                    ? 'Muốn kết bạn với bạn'
                    : 'Đang chờ chấp nhận',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
            trailing: widget.isReceived
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton(
                        onPressed: widget.onAccept,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD81B60),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: SLRadius.mdAll),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          minimumSize: const Size(0, 32),
                        ),
                        child: Text('Chấp nhận',
                            style: SLTheme.quicksand(
                                fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                      SLSpacing.w4,
                      IconButton(
                        icon: const Icon(Icons.close,
                            color: Colors.grey, size: 20),
                        onPressed: widget.onDecline,
                      ),
                    ],
                  )
                : TextButton(
                    onPressed: widget.onCancel,
                    child: Text('Huỷ',
                        style: SLTheme.quicksand(
                            color: Colors.grey,
                            fontWeight: FontWeight.w700,
                            fontSize: 12)),
                  ),
          ),
        );
      },
    );
  }
}

class _SearchItemTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final String myHouseId;
  final VoidCallback onTap;
  final VoidCallback onAdd;

  const _SearchItemTile({
    required this.item,
    required this.myHouseId,
    required this.onTap,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final hid = item['id'];
    final name = item['houseName'] ?? hid;
    final username = item['username'] ?? '';
    final avatar = item['houseAvatar'];
    final isMe = hid == myHouseId;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF3D9E6).withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD81B60).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: SLSpacing.all12,
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFB3C6), Color(0xFFFFD1DC)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD81B60).withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.transparent,
                        backgroundImage:
                            avatar != null && avatar.toString().isNotEmpty
                                ? CachedNetworkImageProvider(avatar)
                                : null,
                        child: (avatar == null || avatar.toString().isEmpty)
                            ? Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: SLTheme.quicksand(
                                  color: const Color(0xFFD81B60),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 20,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
                SLSpacing.w12,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SLTheme.quicksand(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: const Color(0xFF2D3748),
                        ),
                      ),
                      SLSpacing.gapH(2),
                      if (username.isNotEmpty)
                        Text(
                          '@$username',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SLTheme.quicksand(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFD81B60),
                          ),
                        ),
                      Text(
                        'ID: ${hid.length > 10 ? "${hid.substring(0, 10)}..." : hid}',
                        style: SLTheme.quicksand(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFA0AEC0),
                        ),
                      ),
                    ],
                  ),
                ),
                SLSpacing.w8,
                isMe
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: SLRadius.mdAll,
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          'Bạn',
                          style: SLTheme.quicksand(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF718096),
                          ),
                        ),
                      )
                    : IconButton(
                        icon: Container(
                          padding: SLSpacing.all8,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD81B60).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person_add_rounded,
                            color: Color(0xFFD81B60),
                            size: 20,
                          ),
                        ),
                        onPressed: onAdd,
                        tooltip: 'Kết bạn',
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
