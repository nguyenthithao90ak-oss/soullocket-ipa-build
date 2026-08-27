import 'package:flutter/material.dart';
import 'package:soullocket_app/core/sl_page_physics.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_database/firebase_database.dart';
import '../../core/sl_theme.dart';
import '../../utils/app_error_mapper.dart';
import 'widgets/admin_shared_widgets.dart';

final List<String> _defaultBlockedTerms = <String>[
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
  L10nService().translate('admin_t_3171fd'),
  'lon',
  L10nService().translate('admin_ln_c66fa6'),
  'cac',
  L10nService().translate('admin_cc_0b235c'),
  'buoi',
  L10nService().translate('admin_bui_232277'),
  'cc',
  'cl',
  'vcl',
  'dcm',
  L10nService().translate('admin_cm_8d28f4'),
  'vkl',
  'vl',
  'loz',
  L10nService().translate('admin_m_cf1d87'),
  'dm',
  L10nService().translate('admin_txt_da27bc'),
  'di',
  'cave',
  L10nService().translate('admin_ph_5bea54'),
  'pho',
  L10nService().translate('admin_chch_9d9106'),
  'chich',
  L10nService().translate('admin_nng_0dc53f'),
  'nung',
  L10nService().translate('admin_dm_4f8dd4'),
  'dam',
  'thu dam',
  L10nService().translate('admin_thdm_92b0ca'),
  'quay tay',
  'mbbg',
  'sgbb',
  'sgdd',
  L10nService().translate('admin_chi_1d8a79'),
  L10nService().translate('admin_chuith_e23740'),
  L10nService().translate('admin_chith_f215b4'),
  L10nService().translate('admin_tm_3c034b'),
  'dit me',
  L10nService().translate('admin_con_655ea0'),
  'con di',
  L10nService().translate('admin_thngch_c392ee'),
  'thang cho',
  L10nService().translate('admin_cc_d9cdc2'),
  L10nService().translate('admin_ct_7733ff'),
  L10nService().translate('admin_txt_70b3fa'),
  L10nService().translate('admin_m_9ec17b'),
  L10nService().translate('admin_m_2e7399'),
  'du ma',
  'du me',
  L10nService().translate('admin_cln_ee86fa'),
  'cu lon',
  L10nService().translate('admin_mtln_2523d0'),
  'mat lon',
  L10nService().translate('admin_hmln_117a8b'),
  'ham lon',
  L10nService().translate('admin_viln_c54db8'),
  'vai lon',
  L10nService().translate('admin_ciln_9a7be8'),
  'cai lon',
  L10nService().translate('admin_ccch_4345ed'),
  'cac cho',
  L10nService().translate('admin_ngunhch_8b6470'),
  'ngu nhu cho',
  L10nService().translate('admin_cch_8a2417'),
  'oc cho',
  L10nService().translate('admin_ub_5bc9fb'),
  'dau bo',
  L10nService().translate('admin_bcu_2063bc'),
  'bu cu',
  L10nService().translate('admin_sccc_25571b'),
  'suc cac',
  L10nService().translate('admin_thmdu_da530c'),
  'tham du',
  L10nService().translate('admin_nngln_78d8fc'),
  'nung lon',
  L10nService().translate('admin_nngcc_321db9'),
  'nung cac',
  L10nService().translate('admin_dmng_0c9251'),
  'dam dang',
  L10nService().translate('admin_im_0d97ff'),
  'di diem',
  L10nService().translate('admin_imthi_5ca365'),
  'diem thui',
  L10nService().translate('admin_bnichamy_da01df'),
  'ba noi cha may',
  L10nService().translate('admin_tchamy_1c6058'),
  'to cha may',
  L10nService().translate('admin_mmy_31c9fa'),
  'du ma may',
  L10nService().translate('admin_mmy_9a36c2'),
  'du di me may',
  L10nService().translate('admin_nga_accf97'),
  'di ngua',
  L10nService().translate('admin_imthi_f792a9'),
  'di diem thui',
  L10nService().translate('admin_phnt_b92795'),
  'pho nat',
  L10nService().translate('admin_hngdt_59d61d'),
  'hang dat',
  've chai',
  L10nService().translate('admin_ngnt_889ea5'),
  'dong nat',
  L10nService().translate('admin_rcrixhi_d90423'),
  'rac ruoi xa hoi',
  L10nService().translate('admin_cnbxhi_8d7427'),
  'can ba xa hoi',
  L10nService().translate('admin_ksinhtrng_0b13a8'),
  'ky sinh trung',
  L10nService().translate('admin_bmvym_ec0ee5'),
  'bam vay me',
  L10nService().translate('admin_nbm_7fe8a7'),
  'an bam',
  L10nService().translate('admin_vtchs_c7e809'),
  'vo tich su',
  L10nService().translate('admin_bi_974e77'),
  'do bo di',
  L10nService().translate('admin_phvt_45e693'),
  'phe vat',
  L10nService().translate('admin_vdng_36d569'),
  'vo dung',
  L10nService().translate('admin_btti_41d748'),
  'bat tai',
  L10nService().translate('admin_kmci_5a7f5f'),
  'kem coi',
  L10nService().translate('admin_hnh_2860fe'),
  'hen ha',
  L10nService().translate('admin_nhcnh_e625b1'),
  'nhuc nha',
  L10nService().translate('admin_xuh_fff5ea'),
  'xau ho',
  L10nService().translate('admin_mtmt_037a16'),
  'mat mat',
  L10nService().translate('admin_mtdy_a6e71a'),
  'mat day',
  L10nService().translate('admin_hnlo_babc1e'),
  'hon lao',
  L10nService().translate('admin_hnxc_b0ac68'),
  'hon xuoc',
  L10nService().translate('admin_vhc_77d16a'),
  'vo hoc',
  L10nService().translate('admin_thiugiodc_4c2b4b'),
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
        fallbackMessage: 'Chưa thể tải danh sách từ cấm lúc này.',
      ).message}');
    }
  }

  Future<void> _addBannedWord() async {
    final word = _bannedWordCtrl.text.trim().toLowerCase();
    if (word.isEmpty) return;

    if (_bannedWords.contains(word)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('admin_tnyctrongd_ef7bb5'))),
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
        SnackBar(content: Text(context.tr('admin_thmtcm_c1fc50'))),
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
        SnackBar(content: Text(context.tr('admin_xatcm_7d27ee'))),
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
        SnackBar(content: Text(successText)),
      );
    } catch (e) {
      debugPrint('Abuse action failed: ${AppErrorMapper.resolve(
        e,
        fallbackMessage: errorFallback,
      ).message}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
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
                        'User: ${log['uid']} - ${log['details'] ?? ''}',
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
