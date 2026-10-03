import 'package:soullocket_app/widgets/sl_feedback.dart';
import 'package:soullocket_app/widgets/sl_dialog.dart';
import 'dart:async';
import 'dart:io' as io;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

import '../../utils/services/export_service.dart';
import '../../core/sl_theme.dart';

class DiaryExportScreen extends StatefulWidget {
  final String houseId;

  const DiaryExportScreen({super.key, required this.houseId});

  @override
  State<DiaryExportScreen> createState() => _DiaryExportScreenState();
}

class _DiaryExportScreenState extends State<DiaryExportScreen> {
  static const String _historyPrefsKey = 'il_export_history';

  bool _isLoading = true;
  bool _isExportingHtml = false;
  bool _isExportingAll = false;
  double _exportProgress = 0;
  String _exportStatus = '';
  String _houseName = L10nService().translate('util_nginhtnhyu_dbebce');
  List<_ExportRecord> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHouseName();
  }

  Future<void> _loadHouseName() async {
    try {
      _houseName = await ExportService().resolveDiaryHouseName(widget.houseId);
      await _loadHistory();
    } catch (_) {
      // Keep fallback label
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_historyPrefsKey) ?? [];
    _history = raw
        .map((s) => _ExportRecord.fromJson(s))
        .where((r) => io.File(r.filePath).existsSync())
        .toList();
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = _history.map((r) => r.toJson()).toList();
    await prefs.setStringList(_historyPrefsKey, raw);
  }

  void _addToHistory(String filePath, String type) {
    _history.insert(
      0,
      _ExportRecord(
        filePath: filePath,
        type: type,
        exportedAt: DateTime.now(),
        houseName: _houseName,
      ),
    );
    if (_history.length > 20) _history = _history.sublist(0, 20);
    _saveHistory();
  }

  void _removeFromHistory(int index) {
    final record = _history[index];
    try {
      io.File(record.filePath).deleteSync();
    } catch (error) {
      debugPrint(
        '[SuppressedError] lib/views/utilities/diary_export_screen.dart: $error',
      );
    }
    _history.removeAt(index);
    _saveHistory();
    setState(() {});
  }

  Widget _buildInfoIcon(BuildContext context) {
    return IconButton(
      tooltip: context.tr('auth_guide_short'),
      icon: const Icon(
        Icons.info_outline_rounded,
        color: Color(0xFFD81B60),
        size: 22,
      ),
      onPressed: () => _showInfoDialog(context),
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => SLAlertDialog(
        title: Text(context.tr('export_diary')),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.tr('vault_features_label'), style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text(
                context.tr('diary_export_help_features'),
              ),
              SizedBox(height: 12),
              Text(
                context.tr('p3_help_how_to_label'),
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                context.tr('ui_utilities_click_start_exporting_data_the_system_will_03ed4e'),
              ),
            ],
          ),
        ),
        actions: [
          SLDialogAction(
            primary: true,

            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('Đã hiểu')),
          ),
        ],
      ),
    );
  }

  Future<void> _exportHtml() async {
    if (_isExportingHtml) return;
    setState(() => _isExportingHtml = true);

    try {
      final filePath = await ExportService().exportDiary(
        houseId: widget.houseId,
        houseName: _houseName,
        format: DiaryExportFormat.html,
      );

      if (!mounted) return;

      if (filePath != null) {
        _addToHistory(filePath, 'html');
        setState(() {});

        ScaffoldMessenger.of(context).showSnackBar(
          SLSnackBar(
            content: Text(L10nScope.of(context).format('ui_utilities_exported_html_value1_b8061a', {'value1': filePath.split('/').last})),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: context.tr('p8_notebook_open'),
              onPressed: () => _openFile(filePath),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SLSnackBar(
          content: Text(context.tr('util_chathxutdl_223d08')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isExportingHtml = false);
    }
  }

  Future<void> _exportAllMemories() async {
    if (_isExportingAll) return;
    setState(() {
      _isExportingAll = true;
      _exportProgress = 0;
      _exportStatus = L10nService().translate('ui_utilities_starting_302522');
    });

    try {
      final filePath = await ExportService().exportAllMemories(
        houseId: widget.houseId,
        houseName: _houseName,
        onProgress: (progress, status) {
          if (mounted) {
            setState(() {
              _exportProgress = progress;
              _exportStatus = status;
            });
          }
        },
      );

      if (!mounted) return;

      if (filePath.isNotEmpty) {
        _addToHistory(filePath, 'zip');
        setState(() {});

        ScaffoldMessenger.of(context).showSnackBar(
          SLSnackBar(
            content: Text(L10nScope.of(context).format('ui_utilities_exported_zip_value1_69e938', {'value1': filePath.split('/').last})),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: context.tr('p8_notebook_open'),
              onPressed: () => _openFile(filePath),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SLSnackBar(
          content: Text(L10nScope.of(context).format('ui_utilities_error_value1_01d14e', {'value1': e.toString()})),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isExportingAll = false;
          _exportProgress = 0;
          _exportStatus = '';
        });
      }
    }
  }

  Future<void> _openFile(String path) async {
    try {
      final result = await OpenFilex.open(path);
      if (result.type != ResultType.done) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SLSnackBar(
            content: Text(L10nScope.of(context).format('ui_utilities_cannot_open_file_value1_52bf4b', {'value1': result.message})),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SLSnackBar(
          content: Text(L10nScope.of(context).format('ui_utilities_cannot_open_file_value1_52bf4b', {'value1': e})),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _saveToDownloads(String path, String fileName) async {
    try {
      final sourceFile = io.File(path);
      if (!await sourceFile.exists()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SLSnackBar(
            content: Text(context.tr('ui_utilities_file_does_not_exist_e5652f')),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final downloadDir = await getApplicationDocumentsDirectory();
      final targetDir = io.Directory('${downloadDir.path}/SoulLocket_Exports');
      if (!await targetDir.exists()) await targetDir.create(recursive: true);
      final targetFile = io.File('${targetDir.path}/$fileName');
      await sourceFile.copy(targetFile.path);

      await OpenFilex.open(targetFile.path);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SLSnackBar(
          content: Text(L10nScope.of(context).format('ui_utilities_saved_value1_bfd7a4', {'value1': fileName})),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SLSnackBar(
          content: Text(L10nScope.of(context).format('ui_utilities_error_saving_file_value1_802da4', {'value1': e})),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _shareFile(String path) async {
    try {
      final fileName = path.split('/').last;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path)],
          text: L10nScope.of(context).format('ui_utilities_soullocket_value1_value2_s_love_diary_733d56', {'value1': fileName, 'value2': _houseName}),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SLSnackBar(
          content: Text(L10nScope.of(context).format('ui_utilities_unable_to_share_value1_f76018', {'value1': e})),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFFD81B60),
        title: Text(
          context.tr('util_xutnhtk_c6feb9'),
          style: SLTheme.quicksand(
            fontWeight: FontWeight.w900,
            color: const Color(0xFFD81B60),
          ),
        ),
        actions: [_buildInfoIcon(context)],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFD81B60)),
            )
          : Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFFFFBFD),
                    Color(0xFFFDFDFF),
                    Color(0xFFFFF1F6),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: SafeArea(
                child: ListView(
                  padding: SLSpacing.all16,
                  children: [
                    // House name card
                    _buildHouseCard(),
                    SLSpacing.h16,
                    _buildExportCard(
                      icon: Icons.language_rounded,
                      title: context.tr('util_xuthtml_c57dd1'),
                      description: context.tr('util_tofilehtml_f2f8a2'),
                      colors: const [Color(0xFF5DA9FF), Color(0xFF7C4DFF)],
                      isBusy: _isExportingHtml,
                      onTap: _exportHtml,
                    ),
                    SLSpacing.h12,
                    _buildExportCard(
                      icon: Icons.folder_zip_rounded,
                      title: context.tr('ui_utilities_export_all_memories_626026'),
                      description: context.tr('ui_utilities_diary_and_memory_photos_zip_file_27d8c5'),
                      colors: const [Color(0xFFD81B60), Color(0xFFFF5E92)],
                      isBusy: _isExportingAll,
                      onTap: _exportAllMemories,
                    ),
                    if (_isExportingAll) _buildProgressSection(),
                    if (_history.isNotEmpty) _buildHistorySection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHouseCard() {
    return Container(
      padding: SLSpacing.all20,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFFFEEF5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFF7D3E1)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD81B60).withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _houseName,
            style: SLTheme.quicksand(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: const Color(0xFFD81B60),
            ),
          ),
          SLSpacing.h8,
          Text(
            context.tr('util_xutnhtklul_13b3fb'),
            style: SLTheme.quicksand(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF7A5C69),
              height: 1.5,
            ),
          ),
          SLSpacing.h16,
          _buildFeatureLine(
            Icons.language_rounded,
            'HTML',
            context.tr('util_bnwebnhmli_d0d399'),
          ),
          SLSpacing.h8,
          _buildFeatureLine(
            Icons.folder_zip_rounded,
            'ZIP',
            context.tr('ui_utilities_package_all_diary_commemorative_photos_into_zip_bbc54d'),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          SLSpacing.h16,
          LinearProgressIndicator(
            value: _exportProgress,
            backgroundColor: const Color(0xFFF1D4E1),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFD81B60)),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
          SLSpacing.h8,
          Text(
            _exportStatus,
            style: SLTheme.quicksand(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF7A5C69),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SLSpacing.h24,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Icon(
                Icons.history_rounded,
                size: 18,
                color: const Color(0xFF7A5C69).withValues(alpha: 0.7),
              ),
              SLSpacing.w8,
              Text(
                context.tr('ui_utilities_recent_exports_f7b5d2'),
                style: SLTheme.quicksand(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF47303B),
                ),
              ),
              SLSpacing.w8,
              Text(
                L10nScope.of(context).format('ui_utilities_value1_files_4bbfd0', {'value1': _history.length}),
                style: SLTheme.quicksand(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF7A5C69),
                ),
              ),
            ],
          ),
        ),
        SLSpacing.h12,
        ...List.generate(_history.length, (i) => _buildHistoryTile(i)),
      ],
    );
  }

  Widget _buildHistoryTile(int index) {
    final record = _history[index];
    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(record.exportedAt);
    final isHtml = record.type == 'html';
    final icon = isHtml ? Icons.language_rounded : Icons.folder_zip_rounded;
    final color = isHtml ? const Color(0xFF5DA9FF) : const Color(0xFFD81B60);
    final fileName = record.filePath.split('/').last;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFF7D3E1).withValues(alpha: 0.6),
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 4,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          title: Text(
            fileName,
            style: SLTheme.quicksand(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF47303B),
            ),
          ),
          subtitle: Text(
            dateStr,
            style: SLTheme.quicksand(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF7A5C69),
            ),
          ),
          trailing: SizedBox(
            width: 140,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _actionIcon(
                  Icons.file_download_rounded,
                  const Color(0xFF15803D),
                  L10nService().translate('ui_utilities_save_to_device_2562f6'),
                  () => _saveToDownloads(record.filePath, fileName),
                ),
                _actionIcon(
                  Icons.open_in_new_rounded,
                  const Color(0xFF7C4DFF),
                  L10nService().translate('ui_utilities_open_the_file_5cbe70'),
                  () => _openFile(record.filePath),
                ),
                _actionIcon(
                  Icons.share_rounded,
                  const Color(0xFF5DA9FF),
                  L10nService().translate('share'),
                  () => _shareFile(record.filePath),
                ),
                _actionIcon(
                  Icons.delete_outline_rounded,
                  Colors.red[300]!,
                  'Xoá file',
                  () {
                    showDialog(
                      context: context,
                      builder: (ctx) => SLAlertDialog(
                        title: Text(context.tr('ui_utilities_delete_export_file_eb5347')),
                        content: Text(L10nScope.of(context).format('ui_utilities_remove_value1_from_device_bb47eb', {'value1': fileName})),
                        actions: [
                          SLDialogAction(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(context.tr('Huỷ')),
                          ),
                          SLDialogAction(
                            primary: true,
                            destructive: true,

                            onPressed: () {
                              Navigator.pop(ctx);
                              _removeFromHistory(index);
                            },

                            child: Text(context.tr('ui_utilities_delete_82339c')),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionIcon(
    IconData icon,
    Color color,
    String tooltip,
    VoidCallback onPressed,
  ) {
    return SizedBox(
      width: 32,
      height: 32,
      child: IconButton(
        icon: Icon(icon, size: 18),
        color: color,
        onPressed: onPressed,
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        splashRadius: 18,
      ),
    );
  }

  Widget _buildFeatureLine(IconData icon, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF4F8),
            borderRadius: SLRadius.mdAll,
          ),
          child: Icon(icon, color: const Color(0xFFD81B60)),
        ),
        SLSpacing.w12,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: SLTheme.quicksand(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF47303B),
                ),
              ),
              SLSpacing.gapH(2),
              Text(
                desc,
                style: SLTheme.quicksand(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF7A5C69),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExportCard({
    required IconData icon,
    required String title,
    required String description,
    required List<Color> colors,
    required bool isBusy,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isBusy ? null : onTap,
        borderRadius: SLRadius.xlAll,
        child: Ink(
          padding: SLSpacing.all16,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colors.first.withValues(alpha: 0.10),
                colors.last.withValues(alpha: 0.18),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: SLRadius.xlAll,
            border: Border.all(color: colors.last.withValues(alpha: 0.20)),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors),
                  borderRadius: SLRadius.lgAll,
                ),
                child: isBusy
                    ? const Padding(
                        padding: SLSpacing.all12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(icon, color: Colors.white),
              ),
              SLSpacing.w12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: SLTheme.quicksand(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF47303B),
                      ),
                    ),
                    SLSpacing.h4,
                    Text(
                      description,
                      style: SLTheme.quicksand(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF7A5C69),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              SLSpacing.w12,
              const Icon(Icons.chevron_right_rounded, color: Color(0xFFD81B60)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExportRecord {
  final String filePath;
  final String type;
  final DateTime exportedAt;
  final String houseName;

  _ExportRecord({
    required this.filePath,
    required this.type,
    required this.exportedAt,
    required this.houseName,
  });

  String toJson() {
    return '${Uri.encodeComponent(filePath)}|$type|${exportedAt.millisecondsSinceEpoch}|${Uri.encodeComponent(houseName)}';
  }

  factory _ExportRecord.fromJson(String s) {
    final parts = s.split('|');
    return _ExportRecord(
      filePath: Uri.decodeComponent(parts[0]),
      type: parts.length > 1 ? parts[1] : 'html',
      exportedAt: parts.length > 2
          ? DateTime.fromMillisecondsSinceEpoch(int.tryParse(parts[2]) ?? 0)
          : DateTime.now(),
      houseName: parts.length > 3 ? Uri.decodeComponent(parts[3]) : '',
    );
  }
}
