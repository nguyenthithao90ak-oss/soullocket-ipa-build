import 'package:soullocket_app/widgets/sl_feedback.dart';
import 'package:flutter/material.dart';
import 'package:soullocket_app/core/sl_page_physics.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
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
  "địt",
  'lon',
  "lồn",
  'cac',
  "cặc",
  'buoi',
  "buồi",
  'cc',
  'cl',
  'vcl',
  'dcm',
  "đcm",
  'vkl',
  'vl',
  'loz',
  "đm",
  'dm',
  "đĩ",
  'di',
  'cave',
  "phò",
  'pho',
  "chịch",
  'chich',
  "nứng",
  'nung',
  "dâm",
  'dam',
  'thu dam',
  "thủ dâm",
  'quay tay',
  'mbbg',
  'sgbb',
  'sgdd',
  "chửi",
  "chui thề",
  "chửi thề",
  "địt mẹ",
  'dit me',
  "con đĩ",
  'con di',
  "thằng chó",
  'thang cho',
  "cức",
  "cứt",
  "đụ",
  "đụ má",
  "đụ mẹ",
  'du ma',
  'du me',
  "củ lồn",
  'cu lon',
  "mặt lồn",
  'mat lon',
  "hãm lồn",
  'ham lon',
  "vãi lồn",
  'vai lon',
  "cái lồn",
  'cai lon',
  "cặc chó",
  'cac cho',
  "ngu như chó",
  'ngu nhu cho',
  "óc chó",
  'oc cho',
  "đầu bò",
  'dau bo',
  "bú cu",
  'bu cu',
  "sục cặc",
  'suc cac',
  "thẩm du",
  'tham du',
  "nứng lồn",
  'nung lon',
  "nứng cặc",
  'nung cac',
  "dâm đãng",
  'dam dang',
  "đĩ điếm",
  'di diem',
  "điếm thúi",
  'diem thui',
  "bà nội cha mày",
  'ba noi cha may',
  "tổ cha mày",
  'to cha may',
  "nội dung không phù hợp",
  'du ma may',
  "đụ đĩ mẹ mày",
  'du di me may',
  "đĩ ngựa",
  'di ngua',
  "đĩ điếm thúi",
  'di diem thui',
  "phò nát",
  'pho nat',
  "hàng dạt",
  'hang dat',
  've chai',
  "đồng nát",
  'dong nat',
  "rác rưởi xã hội",
  'rac ruoi xa hoi',
  "cặn bã xã hội",
  'can ba xa hoi',
  "ký sinh trùng",
  'ky sinh trung',
  "bám váy mẹ",
  'bam vay me',
  "ăn bám",
  'an bam',
  "vô tích sự",
  'vo tich su',
  "đồ bỏ đi",
  'do bo di',
  "phế vật",
  'phe vat',
  "vô dụng",
  'vo dung',
  "bất tài",
  'bat tai',
  "kém cỏi",
  'kem coi',
  "hèn hạ",
  'hen ha',
  "nhục nhã",
  'nhuc nha',
  "xấu hổ",
  'xau ho',
  "mất mặt",
  'mat mat',
  "mất dạy",
  'mat day',
  "hỗn láo",
  'hon lao',
  "hỗn xược",
  'hon xuoc',
  "vô học",
  'vo hoc',
  "không đủ thông tin",
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
      final snap = await _db
          .child('admin_system/banned_words')
          .get()
          .timeout(const Duration(seconds: 5));
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
        fallbackMessage: context.tr('ui_admin_the_list_of_banned_words_cannot_be_22122e'),
      ).message}');
    }
  }

  Future<void> _addBannedWord() async {
    final word = _bannedWordCtrl.text.trim().toLowerCase();
    if (word.isEmpty) return;

    if (_bannedWords.contains(word)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SLSnackBar(content: Text(context.tr('admin_tnyctrongd_ef7bb5'))),
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
        SLSnackBar(content: Text(context.tr('admin_thmtcm_c1fc50'))),
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
        SLSnackBar(content: Text(context.tr('admin_xatcm_7d27ee'))),
      );
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final snap = await _db
          .child('admin_system/abuse_logs')
          .get()
          .timeout(const Duration(seconds: 8));
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
        fallbackMessage: context.tr('admin_chathtinht_d042ea'),
      ).message}');
      if (!mounted) return;
      setState(() {
        _errorText = context.tr('admin_chathtinht_bd1243');
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
    final banReason = context.tr('admin_viphmchnhs_2dad53');
    final errorFallback = context.tr('admin_chathhontt_d19c7e');
    final successText = _abuseActionSuccessText(actionType);
    try {
      if (actionType == 'ban') {
        await _db.child('houses/$uid/isBanned').set(true);
        await _db.child('houses/$uid/banReason').set(banReason);
      }

      await _db.child('admin_system/audit_log').push().set({
        'action': 'abuse_action_$actionType',
        'adminId': widget.user.uid,
        'targetUid': uid,
        'timestamp': ServerValue.timestamp,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SLSnackBar(content: Text(successText)),
      );
    } catch (e) {
      debugPrint('Abuse action failed: ${AppErrorMapper.resolve(
        e,
        fallbackMessage: errorFallback,
      ).message}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SLSnackBar(
          content: Text(errorFallback),
        ),
      );
    }
  }

  String _abuseActionSuccessText(String actionType) {
    switch (actionType) {
      case 'ban':
        return context.tr('admin_khatikhonv_f7a9f8');
      default:
        return context.tr('admin_honttthaot_bde531');
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
                      context.tr('admin_chnglmdnga_60fa77'),
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
                  context.tr('admin_phthinspam_f8ae5c'),
                  style: SLTheme.quicksand(
                    color: SLColors.textMuted,
                    fontSize: 14,
                  ),
                ),
                SLSpacing.h16,
                TabBar(
                  controller: _tabController,
                  indicatorColor: SLColors.brandPink,
                  labelColor: SLColors.brandPink,
                  unselectedLabelColor: SLColors.textMuted,
                  labelStyle: SLTheme.quicksand(fontWeight: FontWeight.bold),
                  tabs: [
                    Tab(text: context.tr('admin_nhtklmdng_7a4f22')),
                    Tab(text: context.tr('admin_qunltcmais_fa21dc')),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              physics: const SLPagePhysics(),
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
                      hintText: context.tr('admin_nhptkhacnc_03102a'),
                      hintStyle:
                          SLTheme.quicksand(color: SLColors.textMuted),
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
                  label: Text(context.tr('admin_thm_d9cb42')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SLColors.brandPink,
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
                ? Center(
                    child: Text(
                      context.tr('admin_chactkhano_fa7f3b'),
                      style: const TextStyle(color: Colors.white70),
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
                            tooltip: context.tr('admin_xakhidanhs_1e7649'),
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
      return Center(
        child: Text(context.tr('admin_hthnganton_89405b'),
            style: const TextStyle(color: Colors.white)),
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
              title = context.tr('admin_phthinspam_73464f');
              break;
            case 'multi_device':
              icon = Icons.devices_rounded;
              color = Colors.blue;
              title = context.tr('admin_ngnhpnhiut_9d45e0');
              break;
            default:
              icon = Icons.error_outline_rounded;
              color = Colors.red;
              title = context.tr('admin_hnhvibtthn_cdd783');
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
                        L10nScope.of(context).format('ui_admin_user_value1_value2_605017', {'value1': log['uid'], 'value2': log['details'] ?? ''}),
                        style: SLTheme.quicksand(
                            color: SLColors.textMuted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onSelected: (val) => _takeAction(log['uid'], val),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'warn',
                      child: Text(context.tr('admin_gicnhco_0354f5')),
                    ),
                    PopupMenuItem(
                      value: 'ban',
                      child: Text(context.tr('admin_khatikhon_aee1b3'),
                          style: const TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ],
            ),
          );
        });
  }
}
