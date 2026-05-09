import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_database/firebase_database.dart';
import '../../core/sl_theme.dart';
import '../../utils/app_error_mapper.dart';
import 'widgets/admin_shared_widgets.dart';

const List<String> _defaultBlockedTerms = <String>[
  '18+',
  'khieu dam',
  'sex',
  'clip nong',
  'nude',
  'au dam',
  'child porn',
  'csam',
  'hiep dam',
  'rape',
  'dit',
  'địt',
  'lon',
  'lồn',
  'cac',
  'cặc',
  'buoi',
  'buồi',
  'cc',
  'cl',
  'vcl',
  'dcm',
  'đcm',
  'vkl',
  'vl',
  'loz',
  'đm',
  'dm',
  'đĩ',
  'di',
  'cave',
  'phò',
  'pho',
  'chịch',
  'chich',
  'nứng',
  'nung',
  'dâm',
  'dam',
  'thu dam',
  'thủ dâm',
  'quay tay',
  'mbbg',
  'sgbb',
  'sgdd',
  'chửi',
  'chui thề',
  'chửi thề',
  'địt mẹ',
  'dit me',
  'con đĩ',
  'con di',
  'thằng chó',
  'thang cho',
  'cức',
  'cứt',
  'đụ',
  'đụ má',
  'đụ mẹ',
  'du ma',
  'du me',
  'củ lồn',
  'cu lon',
  'mặt lồn',
  'mat lon',
  'hãm lồn',
  'ham lon',
  'vãi lồn',
  'vai lon',
  'cái lồn',
  'cai lon',
  'cặc chó',
  'cac cho',
  'ngu như chó',
  'ngu nhu cho',
  'óc chó',
  'oc cho',
  'đầu bò',
  'dau bo',
  'bú cu',
  'bu cu',
  'sục cặc',
  'suc cac',
  'thẩm du',
  'tham du',
  'nứng lồn',
  'nung lon',
  'nứng cặc',
  'nung cac',
  'dâm đãng',
  'dam dang',
  'đĩ điếm',
  'di diem',
  'điếm thúi',
  'diem thui',
  'bà nội cha mày',
  'ba noi cha may',
  'tổ cha mày',
  'to cha may',
  'đụ má mày',
  'du ma may',
  'đụ đĩ mẹ mày',
  'du di me may',
  'đĩ ngựa',
  'di ngua',
  'đĩ điếm thúi',
  'di diem thui',
  'phò nát',
  'pho nat',
  'hàng dạt',
  'hang dat',
  've chai',
  'đồng nát',
  'dong nat',
  'rác rưởi xã hội',
  'rac ruoi xa hoi',
  'cặn bã xã hội',
  'can ba xa hoi',
  'ký sinh trùng',
  'ky sinh trung',
  'bám váy mẹ',
  'bam vay me',
  'ăn bám',
  'an bam',
  'vô tích sự',
  'vo tich su',
  'đồ bỏ đi',
  'do bo di',
  'phế vật',
  'phe vat',
  'vô dụng',
  'vo dung',
  'bất tài',
  'bat tai',
  'kém cỏi',
  'kem coi',
  'hèn hạ',
  'hen ha',
  'nhục nhã',
  'nhuc nha',
  'xấu hổ',
  'xau ho',
  'mất mặt',
  'mat mat',
  'mất dạy',
  'mat day',
  'hỗn láo',
  'hon lao',
  'hỗn xược',
  'hon xuoc',
  'vô học',
  'vo hoc',
  'thiếu giáo dục',
  'thieu giao duc'
];

class AdminAbuseScreen extends StatefulWidget {
  const AdminAbuseScreen({super.key, required this.user});

  final firebase_auth.User user;

  @override
  State<AdminAbuseScreen> createState() => _AdminAbuseScreenState();
}

class _AdminAbuseScreenState extends State<AdminAbuseScreen>
    with SingleTickerProviderStateMixin {
  final _db = FirebaseDatabase.instance.ref();
  bool _isLoading = true;
  String? _errorText;
  List<Map<String, dynamic>> _abuseLogs = [];

  List<String> _bannedWords = [];
  final TextEditingController _bannedWordCtrl = TextEditingController();

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
    _loadBannedWords();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _bannedWordCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBannedWords() async {
    try {
      final snap = await _db.child('admin_system/banned_words').get();
      if (snap.exists && snap.value is List) {
        final List<dynamic> list = snap.value as List<dynamic>;
        setState(() {
          _bannedWords = list.map((e) => e.toString()).toList();
        });
      } else {
        setState(() {
          _bannedWords = List.from(_defaultBlockedTerms);
        });
        // Tự động lưu danh sách mặc định lên Firebase nếu chưa có
        await _db.child('admin_system/banned_words').set(_bannedWords);
      }
    } catch (e) {
      debugPrint('Lỗi tải danh sách từ cấm: ${AppErrorMapper.resolve(
        e,
        fallbackMessage: 'Chưa thể tải danh sách từ cấm lúc này.',
      ).message}');
    }
  }

  Future<void> _addBannedWord() async {
    final word = _bannedWordCtrl.text.trim().toLowerCase();
    if (word.isEmpty) return;

    if (_bannedWords.contains(word)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Từ này đã có trong danh sách!')),
      );
      return;
    }

    setState(() {
      _bannedWords.add(word);
    });

    await _db.child('admin_system/banned_words').set(_bannedWords);
    _bannedWordCtrl.clear();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã thêm từ cấm')),
      );
    }
  }

  Future<void> _removeBannedWord(String word) async {
    setState(() {
      _bannedWords.remove(word);
    });

    await _db.child('admin_system/banned_words').set(_bannedWords);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xóa từ cấm')),
      );
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final snap = await _db.child('admin_system/abuse_logs').get();
      final logs = <Map<String, dynamic>>[];

      if (snap.exists) {
        final data = snap.value as Map;
        data.forEach((key, value) {
          if (value is Map) {
            logs.add({
              'id': key,
              ...value.map((k, v) => MapEntry(k.toString(), v)),
            });
          }
        });
      }

      logs.sort((a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));

      if (!mounted) return;
      setState(() {
        _abuseLogs = logs;
        _errorText = null;
      });
    } catch (error) {
      debugPrint('Load abuse logs failed: ${AppErrorMapper.resolve(
        error,
        fallbackMessage: 'Chưa thể tải nhật ký lạm dụng lúc này.',
      ).message}');
      if (!mounted) return;
      setState(() {
        _errorText = 'Chưa thể tải nhật ký lạm dụng lúc này. Vui lòng thử lại.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _takeAction(String uid, String actionType) async {
    try {
      if (actionType == 'ban') {
        await _db.child('houses/$uid/isBanned').set(true);
        await _db
            .child('houses/$uid/banReason')
            .set('Vi phạm chính sách chống lạm dụng');
      }

      await _db.child('admin_system/audit_log').push().set({
        'action': 'abuse_action_$actionType',
        'adminId': widget.user.uid,
        'targetUid': uid,
        'timestamp': ServerValue.timestamp,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_abuseActionSuccessText(actionType))),
      );
    } catch (e) {
      debugPrint('Abuse action failed: ${AppErrorMapper.resolve(
        e,
        fallbackMessage: 'Chưa thể hoàn tất thao tác chống lạm dụng lúc này.',
      ).message}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chưa thể hoàn tất thao tác chống lạm dụng lúc này.'),
        ),
      );
    }
  }

  String _abuseActionSuccessText(String actionType) {
    switch (actionType) {
      case 'ban':
        return 'Đã khóa tài khoản vi phạm.';
      default:
        return 'Đã hoàn tất thao tác chống lạm dụng.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Chống lạm dụng (Anti-abuse)',
                      style: SLTheme.quicksand(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        _loadData();
                        _loadBannedWords();
                      },
                      icon: const Icon(Icons.refresh_rounded,
                          color: Colors.white),
                    ),
                  ],
                ),
                SLSpacing.h8,
                Text(
                  'Phát hiện spam, đăng nhập nhiều thiết bị, và quản lý từ khóa cấm.',
                  style: SLTheme.quicksand(
                    color: const Color(0xFF9AA8C4),
                    fontSize: 14,
                  ),
                ),
                SLSpacing.h16,
                TabBar(
                  controller: _tabController,
                  indicatorColor: const Color(0xFFFF4B91),
                  labelColor: const Color(0xFFFF4B91),
                  unselectedLabelColor: const Color(0xFF9AA8C4),
                  labelStyle: SLTheme.quicksand(fontWeight: FontWeight.bold),
                  tabs: const [
                    Tab(text: 'Nhật ký lạm dụng'),
                    Tab(text: 'Quản lý Từ cấm (AI/Spam)'),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildLogsTab(),
                _buildBannedWordsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogsTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorText != null
              ? Center(
                  child: Text(
                    _errorText!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                )
              : _buildAbuseLogs(),
    );
  }

  Widget _buildBannedWordsTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminGlassCard(
            padding: SLSpacing.all20,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _bannedWordCtrl,
                    style: SLTheme.quicksand(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Nhập từ khóa cần cấm...',
                      hintStyle:
                          SLTheme.quicksand(color: const Color(0xFF9AA8C4)),
                      filled: true,
                      fillColor: const Color(0xFF0E1322),
                      border: OutlineInputBorder(
                        borderRadius: SLRadius.mdAll,
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                    onSubmitted: (_) => _addBannedWord(),
                  ),
                ),
                SLSpacing.w12,
                ElevatedButton.icon(
                  onPressed: _addBannedWord,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Thêm'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF4B91),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: SLRadius.mdAll,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SLSpacing.h24,
          Expanded(
            child: _bannedWords.isEmpty
                ? const Center(
                    child: Text(
                      'Chưa có từ khóa nào bị cấm.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  )
                : ListView.builder(
                    itemCount: _bannedWords.length,
                    itemBuilder: (context, index) {
                      final word = _bannedWords[index];
                      return Card(
                        color: const Color(0xFF141C30),
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: SLRadius.mdAll,
                          side: const BorderSide(color: Color(0xFF26304A)),
                        ),
                        child: ListTile(
                          title: Text(
                            word,
                            style: SLTheme.quicksand(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline_rounded,
                                color: Colors.red),
                            onPressed: () => _removeBannedWord(word),
                            tooltip: 'Xóa khỏi danh sách cấm',
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAbuseLogs() {
    if (_abuseLogs.isEmpty) {
      return const Center(
        child: Text('Hệ thống an toàn, chưa phát hiện hành vi lạm dụng.',
            style: TextStyle(color: Colors.white)),
      );
    }

    return ListView.separated(
        itemCount: _abuseLogs.length,
        separatorBuilder: (context, index) => SLSpacing.h12,
        itemBuilder: (context, index) {
          final log = _abuseLogs[index];
          final type = log['type'] ?? 'unknown'; // spam, multi_device, abnormal

          IconData icon;
          Color color;
          String title;

          switch (type) {
            case 'spam':
              icon = Icons.warning_amber_rounded;
              color = Colors.orange;
              title = 'Phát hiện Spam';
              break;
            case 'multi_device':
              icon = Icons.devices_rounded;
              color = Colors.blue;
              title = 'Đăng nhập nhiều thiết bị';
              break;
            default:
              icon = Icons.error_outline_rounded;
              color = Colors.red;
              title = 'Hành vi bất thường';
          }

          return Container(
            padding: SLSpacing.all16,
            decoration: BoxDecoration(
              color: const Color(0xFF141C30),
              borderRadius: SLRadius.lgAll,
              border: Border.all(color: const Color(0xFF26304A)),
            ),
            child: Row(
              children: [
                Container(
                  padding: SLSpacing.all12,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color),
                ),
                SLSpacing.w16,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: SLTheme.quicksand(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      SLSpacing.h4,
                      Text(
                        'User: ${log['uid']} - ${log['details'] ?? ''}',
                        style: SLTheme.quicksand(
                            color: const Color(0xFF9AA8C4), fontSize: 13),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onSelected: (val) => _takeAction(log['uid'], val),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'warn',
                      child: Text('Gửi cảnh cáo'),
                    ),
                    const PopupMenuItem(
                      value: 'ban',
                      child: Text('Khóa tài khoản',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ],
            ),
          );
        });
  }
}
