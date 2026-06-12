// ignore_for_file: unused_element, unused_field, unused_local_variable, dead_code, deprecated_member_use, use_super_parameters, prefer_const_constructors, use_build_context_synchronously, duplicate_ignore, avoid_web_libraries_in_flutter, avoid_unnecessary_containers
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_database/firebase_database.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io' as io;
import '../../services/auth_service.dart';
import '../../utils/app_error_mapper.dart';
import '../../utils/web_helpers.dart';
import 'widgets/admin_shared_widgets.dart';
import '../../core/sl_theme.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key, required this.user});

  final firebase_auth.User user;

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _db = FirebaseDatabase.instance.ref();
  final _authService = AuthService();
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorText;
  DateTime? _lastUpdatedAt;

  List<Map<String, dynamic>> _houses = [];
  String _searchQuery = '';
  String _filterStatus = 'all';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool refresh = false}) async {
    if (refresh) {
      setState(() => _isRefreshing = true);
    } else {
      setState(() => _isLoading = true);
    }

    try {
      final snapshot = await _db.child('houses').get();
      final List<Map<String, dynamic>> loaded = [];

      if (snapshot.exists) {
        final data = snapshot.value;
        if (data is Map) {
          data.forEach((key, value) {
            if (value is Map) {
              final houseData = Map<String, dynamic>.from(value);
              houseData['id'] = key.toString();
              loaded.add(houseData);
            }
          });
        }
      }

      loaded.sort((a, b) =>
          (b['createdAt'] as num? ?? 0).compareTo(a['createdAt'] as num? ?? 0));

      if (!mounted) return;
      setState(() {
        _houses = loaded;
        _lastUpdatedAt = DateTime.now();
        _errorText = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = AppErrorMapper.resolve(
          error,
          fallbackMessage:
              context.tr('admin_chathtidan_64c8c0'),
        ).message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _handleSignOut() async {
    await _authService.signOut();
  }

  Future<void> _exportCSV() async {
    try {
      final filtered = _filteredHouses;
      if (filtered.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('admin_khngcdliux_0c15a9'))),
        );
        return;
      }

      List<List<dynamic>> rows = [];
      // Header
      rows.add([
        'ID',
        'User1',
        'User2',
        'Role',
        'PRO',
        context.tr('admin_bkha_fce0d8'),
        context.tr('admin_ldokha_495968'),
        'Created At'
      ]);

      for (var h in filtered) {
        final isBanned = h['isBanned'] == true;
        final proUntil = int.tryParse(h['proUntil']?.toString() ?? '0') ?? 0;
        final isPro = proUntil > DateTime.now().millisecondsSinceEpoch;
        final createdAt = int.tryParse(h['createdAt']?.toString() ?? '0') ?? 0;
        final dateStr = createdAt > 0
            ? DateTime.fromMillisecondsSinceEpoch(createdAt).toString()
            : '';

        rows.add([
          h['id'] ?? '',
          h['user1_name'] ?? '',
          h['user2_name'] ?? '',
          h['role'] ?? 'user',
          isPro ? 'Yes' : 'No',
          isBanned ? 'Yes' : 'No',
          h['banReason'] ?? '',
          dateStr,
        ]);
      }

      String csvData = Csv().encode(rows);
      final bytes = utf8.encode(csvData);

      if (kIsWeb) {
        downloadWebFile('users_export.csv', bytes, 'text/csv');
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final path = '${dir.path}/users_export.csv';
        final file = io.File(path);
        await file.writeAsBytes(bytes);
        await Share.shareXFiles([XFile(path)], text: 'Export Users');
      }
    } catch (e) {
      final errorInfo = AppErrorMapper.resolve(
        e,
        fallbackMessage: context.tr('admin_chathxutda_dc5b37'),
      );
      debugPrint('Export users failed: ${errorInfo.message}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('admin_chathxutda_dc5b37')),
        ),
      );
    }
  }

  void _showActionDialog(Map<String, dynamic> house, String actionType) {
    final reasonCtrl = TextEditingController();
    String title = '';

    if (actionType == 'ban') title = context.tr('admin_khatikhon_aee1b3');
    if (actionType == 'vip') title = context.tr('admin_cppro30ngy_ee8730');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('ID: ${house['id']}',
                style: const TextStyle(color: Colors.grey)),
            SLSpacing.h16,
            if (actionType == 'ban')
              TextField(
                controller: reasonCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: context.tr('admin_ldo_bb946f'),
                  labelStyle: TextStyle(color: Colors.grey),
                  enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey)),
                  focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFFF4B91))),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('admin_hy_1e4050'), style: TextStyle(color: Colors.grey)),
          ),
          if (actionType == 'ban') ...[
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                _executeAction('ban_perm', house['id'], reasonCtrl.text.trim());
                Navigator.pop(ctx);
              },
              child: Text(context.tr('admin_khavnhvin_1f9874'),
                  style: TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () {
                _executeAction('unban', house['id'], '');
                Navigator.pop(ctx);
              },
              child:
                  Text(context.tr('admin_mkha_b8cf89'), style: TextStyle(color: Colors.white)),
            ),
          ],
          if (actionType == 'vip')
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
              onPressed: () {
                _executeAction('add_vip', house['id'], '');
                Navigator.pop(ctx);
              },
              child:
                  Text(context.tr('admin_cppro_ece366'), style: TextStyle(color: Colors.black)),
            ),
        ],
      ),
    );
  }

  Future<void> _executeAction(
      String action, String targetId, String reason) async {
    try {
      Map<String, dynamic> updates = {};
      if (action == 'add_vip') {
        final p = await _db.child('houses/$targetId/proUntil').get();
        final current = int.tryParse(p.value?.toString() ?? '0') ?? 0;
        final nowTs = DateTime.now().millisecondsSinceEpoch;
        updates['houses/$targetId/proUntil'] =
            (current > nowTs ? current : nowTs) + (30 * 24 * 60 * 60 * 1000);
      } else if (action == 'ban_perm') {
        updates['houses/$targetId/isBanned'] = true;
        updates['houses/$targetId/banReason'] =
            reason.isEmpty ? context.tr('admin_viphmnghim_40f8de') : reason;
      } else if (action == 'unban') {
        updates['houses/$targetId/isBanned'] = null;
        updates['houses/$targetId/banReason'] = null;
        updates['houses/$targetId/banUntil'] = null;
      }

      if (updates.isNotEmpty) {
        await _db.update(updates);
      }

      await _db.child('admin_system/audit_log').push().set({
        'ts': ServerValue.timestamp,
        'action': action,
        'targetId': targetId,
        'actorRole': 'web_admin',
        'reason': reason,
      });

      if (action == 'ban_perm' || action == 'unban') {}

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.tr('admin_thaotcthnh_1f60b3'))));
      _loadData(refresh: true);
    } catch (e) {
      final errorInfo = AppErrorMapper.resolve(
        e,
        fallbackMessage: context.tr('admin_chathhontt_8d99bd'),
      );
      debugPrint('Admin user action failed: ${errorInfo.message}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('admin_chathhontt_8d99bd')),
        ),
      );
    }
  }

  List<Map<String, dynamic>> get _filteredHouses {
    return _houses.where((h) {
      // 1. Search
      final id = (h['id'] ?? '').toString().toLowerCase();
      final user1 = (h['user1_name'] ?? '').toString().toLowerCase();
      final user2 = (h['user2_name'] ?? '').toString().toLowerCase();
      final searchLower = _searchQuery.toLowerCase();
      final matchSearch = id.contains(searchLower) ||
          user1.contains(searchLower) ||
          user2.contains(searchLower);

      if (!matchSearch) return false;

      // 2. Filter
      final isBanned = h['isBanned'] == true;
      final proUntil = int.tryParse(h['proUntil']?.toString() ?? '0') ?? 0;
      final isPro = proUntil > DateTime.now().millisecondsSinceEpoch;

      if (_filterStatus == 'vip' && !isPro) return false;
      if (_filterStatus == 'banned' && !isBanned) return false;

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredData = _filteredHouses;

    return AdminScaffold(
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: Padding(
              padding: SLSpacing.all24,
              child: Column(
                children: [
                  AdminTopBar(
                    title: context.tr('admin_qunlnhuser_fa6518'),
                    user: widget.user,
                    isRefreshing: _isRefreshing,
                    lastUpdatedAt: _lastUpdatedAt,
                    onRefresh: () => _loadData(refresh: true),
                    onSignOut: _handleSignOut,
                  ),
                  SLSpacing.h24,
                  if (_errorText != null)
                    Text(_errorText!,
                        style: const TextStyle(color: Colors.red)),

                  // Thanh tìm kiếm và lọc
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: context.tr('admin_tmtheoidho_74d8f1'),
                            hintStyle: const TextStyle(color: Colors.grey),
                            prefixIcon:
                                const Icon(Icons.search, color: Colors.grey),
                            filled: true,
                            fillColor: const Color(0xFF10182A),
                            border: OutlineInputBorder(
                              borderRadius: SLRadius.mdAll,
                              borderSide:
                                  const BorderSide(color: Color(0xFF2A364E)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: SLRadius.mdAll,
                              borderSide:
                                  const BorderSide(color: Color(0xFF2A364E)),
                            ),
                          ),
                          onChanged: (val) =>
                              setState(() => _searchQuery = val),
                        ),
                      ),
                      SLSpacing.w16,
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10182A),
                          borderRadius: SLRadius.mdAll,
                          border: Border.all(color: const Color(0xFF2A364E)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            dropdownColor: Color(0xFF10182A),
                            value: _filterStatus,
                            style: TextStyle(color: Colors.white),
                            items: [
                              DropdownMenuItem(
                                  value: 'all', child: Text(context.tr('admin_ttc_d8586d'))),
                              DropdownMenuItem(
                                  value: 'vip', child: Text(context.tr('admin_chpro_b8ad3b'))),
                              DropdownMenuItem(
                                  value: 'banned', child: Text(context.tr('admin_kha_f4517f'))),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _filterStatus = val);
                              }
                            },
                          ),
                        ),
                      ),
                      SLSpacing.w16,
                      ElevatedButton.icon(
                        onPressed: _exportCSV,
                        icon: const Icon(Icons.download_rounded,
                            color: Colors.white, size: 20),
                        label: Text(context.tr('admin_xutcsv_47bfce'),
                            style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E88E5),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: SLRadius.mdAll),
                        ),
                      ),
                    ],
                  ),
                  SLSpacing.h16,

                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : AdminGlassCard(
                            padding: const EdgeInsets.all(0),
                            child: ListView.separated(
                              itemCount: filteredData.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(
                                      color: Color(0xFF2A364E), height: 1),
                              itemBuilder: (context, index) {
                                final h = filteredData[index];
                                final isBanned = h['isBanned'] == true;
                                final proUntil = int.tryParse(
                                        h['proUntil']?.toString() ?? '0') ??
                                    0;
                                final isPro = proUntil >
                                    DateTime.now().millisecondsSinceEpoch;

                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 8),
                                  title: Row(
                                    children: [
                                      Text(h['id'] ?? '',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold)),
                                      if (isBanned) ...[
                                        SLSpacing.w8,
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                              color: Colors.red,
                                              borderRadius:
                                                  BorderRadius.circular(4)),
                                          child: const Text('BANNED',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10)),
                                        )
                                      ],
                                      if (isPro) ...[
                                        SLSpacing.w8,
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                              color: Colors.amber,
                                              borderRadius:
                                                  BorderRadius.circular(4)),
                                          child: const Text('PRO',
                                              style: TextStyle(
                                                  color: Colors.black,
                                                  fontSize: 10)),
                                        )
                                      ]
                                    ],
                                  ),
                                  subtitle: Text(
                                    'Role: ${h['role'] ?? 'user'} | ${h['user1_name'] ?? ''} & ${h['user2_name'] ?? ''}',
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.stars_rounded,
                                            color: Colors.amber),
                                        onPressed: () =>
                                            _showActionDialog(h, 'vip'),
                                        tooltip: context.tr('admin_cppro_ece366'),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.block_rounded,
                                            color: Colors.red),
                                        onPressed: () =>
                                            _showActionDialog(h, 'ban'),
                                        tooltip: context.tr('admin_khamkha_6a6a2d'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}