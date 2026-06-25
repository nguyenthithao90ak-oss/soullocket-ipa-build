import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../utils/services/friends_service.dart';
import '../../utils/services/house_service.dart';
import '../visitors/visitor_profile_screen.dart';
import '../../core/sl_theme.dart';

/// ============================================================
///  FriendSearchScreen — GRA (Phase 42)
///  Tìm kiếm bạn bè / nhà theo tên hoặc ID
///
///  Theo: core-friends.js  → renderFriendSearch(), handleFriendSearch()
///  Theo: core-visitor-profile.js → openFriendSearch()
/// ============================================================
class FriendSearchScreen extends StatefulWidget {
  const FriendSearchScreen({super.key});

  @override
  State<FriendSearchScreen> createState() => _FriendSearchScreenState();
}

class _FriendSearchScreenState extends State<FriendSearchScreen> {
  final _friendsService = FriendsService();
  final _houseService = HouseService();
  final _ctrl = TextEditingController();

  String? _myHouseId;
  String? _myHouseName;
  List<Map<String, dynamic>> _results = [];
  final Set<String> _sentTo = {};
  Set<String> _friends = {};
  bool _isSearching = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    _myHouseId = await _houseService.getCurrentHouseId();
    // Load tên
    if (_myHouseId != null) {
      final settings = await _houseService.getHouseSettings(_myHouseId!);
      final friends = await _friendsService.streamFriends(_myHouseId!).first;
      final houseName = (settings?['houseName'] ?? '').toString().trim();
      if (!mounted) return;
      setState(() {
        _myHouseName = houseName.isNotEmpty ? houseName : _myHouseId!;
        _friends = Set.from(friends);
      });
    }
  }

  void _search(String q) {
    if (q.trim().isEmpty) {
      _debounce?.cancel();
      setState(() => _results = []);
      return;
    }
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      setState(() => _isSearching = true);
      final results = await _friendsService.searchHouses(q.trim());
      if (!mounted) return;
      setState(() {
        _results = results;
        _isSearching = false;
      });
    });
  }

  Future<void> _addFriend(String toHouseId) async {
    if (_myHouseId == null) return;
    setState(() => _sentTo.add(toHouseId));
    final result = await _friendsService.sendFriendRequest(
      fromHouseId: _myHouseId!,
      fromHouseName: _myHouseName ?? _myHouseId!,
      toHouseId: toHouseId,
    );
    if (!result.success) {
      setState(() => _sentTo.remove(toHouseId));
    }
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Tìm bạn bè hoặc nhà...',
            hintStyle: SLTheme.quicksand(fontSize: 14, color: Colors.grey[400]),
            border: InputBorder.none,
            prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
          ),
          style: SLTheme.quicksand(fontSize: 14, fontWeight: FontWeight.w700),
          onChanged: (v) => _search(v),
        ),
      ),
      body: _ctrl.text.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🔍', style: TextStyle(fontSize: 52)),
                  SLSpacing.h12,
                  Text(
                    'Nhập tên hoặc ID để tìm kiếm bạn bè mới!',
                    textAlign: TextAlign.center,
                    style: SLTheme.quicksand(
                      fontSize: 14,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          : _isSearching
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFFD81B60)))
              : _results.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('😔', style: TextStyle(fontSize: 52)),
                          SLSpacing.h12,
                          Text(
                            'Không tìm thấy kết quả nào.',
                            style: SLTheme.quicksand(
                              fontSize: 14,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: _results.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 72),
                      itemBuilder: (_, i) => _buildItem(_results[i]),
                    ),
    );
  }

  Widget _buildItem(Map<String, dynamic> item) {
    final hid = item['id']?.toString() ?? '';
    final name = item['houseName']?.toString() ?? hid;
    final avatar = item['houseAvatar']?.toString();
    final isMe = hid == _myHouseId;
    final isFriend = _friends.contains(hid);
    final isSent = _sentTo.contains(hid);

    return ListTile(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => VisitorProfileScreen(targetHouseId: hid)),
      ),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: const Color(0xFFFFB3C6),
        backgroundImage:
            avatar != null ? CachedNetworkImageProvider(avatar) : null,
        child: avatar == null
            ? Text(
                name.isEmpty ? '?' : name[0].toUpperCase(),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              )
            : null,
      ),
      title: Text(
        name,
        style: SLTheme.quicksand(fontSize: 14, fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        'ID: ${hid.length > 10 ? "${hid.substring(0, 10)}..." : hid}',
        style: SLTheme.quicksand(fontSize: 11, color: Colors.grey[500]),
      ),
      trailing: isMe
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: SLRadius.mdAll,
              ),
              child: Text('Bạn',
                  style: SLTheme.quicksand(fontSize: 12, color: Colors.grey)),
            )
          : isFriend
              ? ElevatedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.check, size: 14),
                  label: Text('Bạn bè', style: SLTheme.quicksand(fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[100],
                    foregroundColor: Colors.green[700],
                    disabledBackgroundColor: Colors.green[100],
                    disabledForegroundColor: Colors.green[700],
                    shape: RoundedRectangleBorder(borderRadius: SLRadius.mdAll),
                  ),
                )
              : isSent
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: SLRadius.mdAll,
                      ),
                      child: Text('Đã gửi',
                          style: SLTheme.quicksand(
                              fontSize: 12, color: Colors.grey)),
                    )
                  : ElevatedButton.icon(
                      onPressed: () => _addFriend(hid),
                      icon: const Icon(Icons.person_add, size: 14),
                      label: Text('Kết bạn',
                          style: SLTheme.quicksand(fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD81B60),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: SLRadius.mdAll),
                      ),
                    ),
    );
  }
}
