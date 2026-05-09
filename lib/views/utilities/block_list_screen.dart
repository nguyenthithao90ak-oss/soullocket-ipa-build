import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/house_service.dart';
import '../../core/sl_theme.dart';
import '../../utils/app_error_mapper.dart';

/// ============================================================
///  BlockListScreen — GRA (Phase 42)
///  Quản lý danh sách người dùng bị chặn
///
///  Theo: core-block-list-manager.js
///  - Xem danh sách đang bị chặn
///  - Bỏ chặn từng người
///  - Chặn thêm bằng House ID
/// ============================================================
class BlockListScreen extends StatefulWidget {
  const BlockListScreen({super.key});

  @override
  State<BlockListScreen> createState() => _BlockListScreenState();
}

class _BlockListScreenState extends State<BlockListScreen> {
  final _db = FirebaseDatabase.instance;
  final _houseService = HouseService();

  String? _myHouseId;
  Map<String, Map<String, dynamic>> _blockedHouses = {};
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isUnblocking = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final hasExistingData = _blockedHouses.isNotEmpty;
    if (mounted) {
      setState(() {
        if (hasExistingData) {
          _isRefreshing = true;
        } else {
          _isLoading = true;
        }
      });
    }
    _myHouseId = await _houseService.getCurrentHouseId();
    if (_myHouseId == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
      });
      return;
    }

    final snap = await _db.ref('houses/$_myHouseId/blocked_users').get();
    if (!snap.exists || snap.value == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
      });
      return;
    }

    final rawValue = snap.value;
    if (rawValue is! Map) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
      });
      return;
    }

    final raw = Map<dynamic, dynamic>.from(rawValue);
    final Map<String, Map<String, dynamic>> result = {};

    for (final hid in raw.keys) {
      if (raw[hid] != true) continue;
      // Load tên + avatar của người bị chặn
      try {
        final hSnap = await _db.ref('houses/$hid/settings').get();
        final houseRaw = hSnap.value;
        if (hSnap.exists && houseRaw is Map) {
          result[hid.toString()] = Map<String, dynamic>.from(houseRaw);
        } else {
          result[hid.toString()] = {};
        }
      } catch (_) {
        result[hid.toString()] = {};
      }
    }

    setState(() {
      _blockedHouses = result;
      _isLoading = false;
      _isRefreshing = false;
    });
  }

  Future<void> _unblock(String houseId) async {
    if (_myHouseId == null || _isUnblocking) return;
    setState(() => _isUnblocking = true);
    try {
      await _db.ref('houses/$_myHouseId/blocked_users/$houseId').remove();
      if (!mounted) return;
      setState(() => _blockedHouses.remove(houseId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã bỏ chặn người dùng.')));
      }
    } catch (e) {
      debugPrint('Unblock user failed: ${AppErrorMapper.resolve(e).message}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Chưa thể bỏ chặn người dùng lúc này. Vui lòng thử lại.'),
          ),
        );
      }
    } finally {
      setState(() => _isUnblocking = false);
    }
  }

  Future<void> _blockByIdDialog() async {
    final ctrl = TextEditingController();
    final hid = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Chặn theo mã nhà',
            style: SLTheme.quicksand(fontWeight: FontWeight.w900)),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Nhập mã nhà cần chặn'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Hủy')),
          TextButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text('Chặn')),
        ],
      ),
    );
    if (hid == null || hid.isEmpty || _myHouseId == null) return;
    if (hid == _myHouseId) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không thể tự chặn mình!')));
      }
      return;
    }
    await _db.ref('houses/$_myHouseId/blocked_users/$hid').set(true);
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('✅ Đã chặn người dùng.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SLTheme.appBar(
        context,
        'Danh sách chặn',
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.person_add_disabled),
            tooltip: 'Chặn theo ID',
            onPressed: _blockByIdDialog,
          ),
        ],
      ),
      body: SLTheme.softCanvasBackdrop(
        baseColor: const Color(0xFFFFF7F5),
        accentColor: SLColors.danger,
        secondaryAccent: SLColors.primary,
        motif: SLCanvasBackdropMotif.safety,
        child: SafeArea(
          child: _isLoading && _blockedHouses.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(color: SLColors.primary),
                )
              : Stack(
                  children: <Widget>[
                    _blockedHouses.isEmpty
                        ? SLTheme.emptyStatePanel(
                            icon: Icons.shield_rounded,
                            title: 'Không gian đang an toàn',
                            subtitle:
                                'Hiện chưa có nhà nào bị chặn. Bạn có thể thêm mã nhà nếu cần giữ riêng tư.',
                            accentColor: SLColors.danger,
                          )
                        : _buildBlockedList(),
                    if (_isRefreshing)
                      const Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildBlockedList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _blockedHouses.length + 1,
      separatorBuilder: (_, __) => SLSpacing.h12,
      itemBuilder: (_, index) {
        if (index == 0) {
          return _buildSafetyHeader();
        }
        final hid = _blockedHouses.keys.elementAt(index - 1);
        final settings = _blockedHouses[hid]!;
        return _buildBlockedHouseCard(hid, settings);
      },
    );
  }

  Widget _buildSafetyHeader() {
    return SLTheme.softPanel(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      borderColor: SLColors.danger.withValues(alpha: 0.16),
      child: Row(
        children: <Widget>[
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: <Color>[
                  SLColors.danger.withValues(alpha: 0.16),
                  Colors.white.withValues(alpha: 0.92),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: SLColors.danger.withValues(alpha: 0.22)),
            ),
            child: const Icon(Icons.verified_user_rounded,
                color: SLColors.danger, size: 28),
          ),
          SLSpacing.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Không gian an toàn',
                  style: SLTheme.quicksand(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: SLColors.textPrimary,
                  ),
                ),
                SLSpacing.h4,
                Text(
                  'Những nhà trong danh sách này sẽ không thể tương tác với hai bạn.',
                  style: SLTheme.quicksand(
                    fontSize: 12.2,
                    fontWeight: FontWeight.w700,
                    color: SLColors.textSecond,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          SLSpacing.w12,
          SLTheme.chip('${_blockedHouses.length} chặn', SLColors.danger),
        ],
      ),
    );
  }

  Widget _buildBlockedHouseCard(String hid, Map<String, dynamic> settings) {
    final name = settings['houseName']?.toString() ?? hid;
    final avatar = settings['houseAvatar']?.toString();
    final shortId = hid.length > 12 ? '${hid.substring(0, 12)}…' : hid;

    return Container(
      padding: const EdgeInsets.fromLTRB(13, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: SLColors.danger.withValues(alpha: 0.10)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF4A1F2A).withValues(alpha: 0.07),
            blurRadius: 18,
            spreadRadius: -10,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: <Color>[
                  SLColors.danger.withValues(alpha: 0.72),
                  SLColors.primary.withValues(alpha: 0.46),
                ],
              ),
            ),
            child: CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFFFFE4EA),
              backgroundImage:
                  avatar != null ? CachedNetworkImageProvider(avatar) : null,
              child: avatar == null
                  ? Text(
                      name.isEmpty ? '?' : name[0].toUpperCase(),
                      style: SLTheme.quicksand(
                        fontSize: 18,
                        color: SLColors.danger,
                        fontWeight: FontWeight.w900,
                      ),
                    )
                  : null,
            ),
          ),
          SLSpacing.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SLTheme.quicksand(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                    color: SLColors.textPrimary,
                  ),
                ),
                SLSpacing.h6,
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: SLColors.dangerLight.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(999),
                    border:
                        Border.all(color: SLColors.danger.withValues(alpha: 0.12)),
                  ),
                  child: Text(
                    'ID $shortId',
                    style: SLTheme.quicksand(
                      fontSize: 10.5,
                      color: SLColors.danger,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SLSpacing.w10,
          TextButton.icon(
            onPressed: _isUnblocking ? null : () => _unblock(hid),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF15803D),
              backgroundColor: const Color(0xFFE8F8EE),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            icon: const Icon(Icons.lock_open_rounded, size: 15),
            label: Text(
              'Bỏ chặn',
              style: SLTheme.quicksand(
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
