import 'package:soullocket_app/utils/locale_date_format.dart';
import 'package:soullocket_app/widgets/sl_feedback.dart';
import 'package:soullocket_app/widgets/sl_dialog.dart';
import 'dart:async';
import 'dart:io' as io;

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

import '../../utils/services/export_service.dart';
import '../../utils/services/pro_feature_limits.dart';
import '../../widgets/pro_upsell_dialog.dart';
import '../../widgets/utility_vip_badge.dart';
import 'widgets/keepsake_design.dart';

class DiaryExportScreen extends StatefulWidget {
  final String houseId;
  final ExportService? exportService;

  const DiaryExportScreen({
    super.key,
    required this.houseId,
    this.exportService,
  });

  @override
  State<DiaryExportScreen> createState() => _DiaryExportScreenState();
}

class _DiaryExportScreenState extends State<DiaryExportScreen> {
  static const String _historyPrefsKey = 'il_export_history';

  bool _isLoading = true;
  bool _isExportingHtml = false;
  bool _isExportingAll = false;
  bool _isExportingPdf = false;
  bool? _isPro;
  bool get _isBusy =>
      _isExportingHtml || _isExportingAll || _isExportingPdf;
  double _exportProgress = 0;
  String _exportStatus = '';
  String? _exportError;
  VoidCallback? _retryExport;
  String _houseName = L10nService().translate('util_nginhtnhyu_dbebce');
  List<_ExportRecord> _history = [];

  ExportService get _exportService => widget.exportService ?? ExportService();

  @override
  void initState() {
    super.initState();
    _loadHouseName();
    unawaited(
      checkProAccess().then((isPro) {
        if (mounted) setState(() => _isPro = isPro);
      }),
    );
  }

  Future<void> _loadHouseName() async {
    try {
      _houseName = await _exportService
          .resolveDiaryHouseName(widget.houseId)
          .timeout(const Duration(seconds: 12));
      await _loadHistory().timeout(const Duration(seconds: 5));
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
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      icon: const Icon(Icons.help_outline_rounded, size: 22),
      onPressed: () => _showInfoDialog(context),
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => SLAlertDialog(
        title: Text(context.tr('auth_guide_short')),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildGuideSteps(),
              const SizedBox(height: 20),
              Text(context.tr('diary_export_html_body')),
              const SizedBox(height: 12),
              Text(context.tr('diary_export_zip_body')),
              const SizedBox(height: 12),
              Text(context.tr('diary_export_save_hint')),
              const SizedBox(height: 12),
              Text(context.tr('diary_export_check_note')),
              const SizedBox(height: 12),
              Text(context.tr('diary_export_safety_note')),
            ],
          ),
        ),
        actions: [
          SLDialogAction(
            primary: true,

            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('p3_understood')),
          ),
        ],
      ),
    );
  }

  Future<void> _exportHtml() => _exportDiaryFile(DiaryExportFormat.html);

  Future<void> _exportPdf() => _exportDiaryFile(DiaryExportFormat.pdf);

  // Tài khoản thường: bản web 30 ngày gần nhất. PRO: toàn bộ và có bản PDF đẹp.
  Future<void> _exportDiaryFile(DiaryExportFormat format) async {
    if (_isBusy) return;
    final isPdf = format == DiaryExportFormat.pdf;
    // Khóa nút ngay khi bấm: kiểm tra PRO có thể chờ mạng vài giây.
    setState(() {
      if (isPdf) {
        _isExportingPdf = true;
      } else {
        _isExportingHtml = true;
      }
      _exportError = null;
      _retryExport = null;
    });

    try {
      final isPro = await checkProAccess();
      if (!mounted) return;
      setState(() => _isPro = isPro);
      if (isPdf && !isPro) {
        setState(() => _isExportingPdf = false);
        await showProUpsell(
          context,
          houseId: widget.houseId,
          message: L10nService().format('pro_limit_diary_export', {
            'days': ProFeatureLimits.freeDiaryExportDays,
          }),
        );
        return;
      }
      final sinceMs = isPro
          ? null
          : DateTime.now()
                .subtract(
                  const Duration(days: ProFeatureLimits.freeDiaryExportDays),
                )
                .millisecondsSinceEpoch;
      final filePath = await _exportService.exportDiary(
        houseId: widget.houseId,
        houseName: _houseName,
        format: format,
        sinceMs: sinceMs,
      );

      if (!mounted) return;

      if (filePath != null) {
        _addToHistory(filePath, isPdf ? 'pdf' : 'html');
        setState(() {});

        ScaffoldMessenger.of(context).showSnackBar(
          SLSnackBar(
            content: Text(
              L10nScope.of(context).format(
                isPdf
                    ? 'diary_export_pdf_done'
                    : 'ui_utilities_exported_html_value1_b8061a',
                {'value1': filePath.split('/').last},
              ),
            ),
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
      final message = ExportService.errorMessage(e);
      setState(() {
        _exportError = message;
        _retryExport = isPdf ? _exportPdf : _exportHtml;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SLSnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isExportingHtml = false;
          _isExportingPdf = false;
        });
      }
    }
  }

  Future<void> _exportAllMemories() async {
    if (_isBusy) return;
    setState(() {
      _isExportingAll = true;
      _exportError = null;
      _retryExport = null;
      _exportProgress = 0;
      _exportStatus = L10nService().translate('ui_utilities_starting_302522');
    });

    try {
      final filePath = await _exportService.exportAllMemories(
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
            content: Text(
              L10nScope.of(context).format(
                'ui_utilities_exported_zip_value1_69e938',
                {'value1': filePath.split('/').last},
              ),
            ),
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
      final message = ExportService.errorMessage(e);
      setState(() {
        _exportError = message;
        _retryExport = _exportAllMemories;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SLSnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
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
            content: Text(
              L10nScope.of(context).format(
                'ui_utilities_cannot_open_file_value1_52bf4b',
                {'value1': result.message},
              ),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SLSnackBar(
          content: Text(
            L10nScope.of(context).format(
              'ui_utilities_cannot_open_file_value1_52bf4b',
              {'value1': e},
            ),
          ),
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
            content: Text(
              context.tr('ui_utilities_file_does_not_exist_e5652f'),
            ),
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
          content: Text(
            L10nScope.of(
              context,
            ).format('ui_utilities_saved_value1_bfd7a4', {'value1': fileName}),
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SLSnackBar(
          content: Text(
            L10nScope.of(context).format(
              'ui_utilities_error_saving_file_value1_802da4',
              {'value1': e},
            ),
          ),
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
          text: L10nScope.of(context).format(
            'ui_utilities_soullocket_value1_value2_s_love_diary_733d56',
            {'value1': fileName, 'value2': _houseName},
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SLSnackBar(
          content: Text(
            L10nScope.of(context).format(
              'ui_utilities_unable_to_share_value1_f76018',
              {'value1': e},
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KeepsakeStyle.canvas(context),
      appBar: KeepsakeStyle.appBar(
        context,
        title: Text(
          context.tr('utility_title_diary_export'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [_buildInfoIcon(context)],
      ),
      body: _isLoading
          ? SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Semantics(
                    liveRegion: true,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          color: KeepsakeStyle.accent(context),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          context.tr('loading'),
                          textAlign: TextAlign.center,
                          style: KeepsakeStyle.text(
                            context,
                            color: KeepsakeStyle.muted(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : SafeArea(
              top: false,
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: ListView(
                    key: const Key('diary-export-scroll'),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      _buildHouseCard(),
                      const SizedBox(height: 20),
                      _buildPanel(
                        key: const Key('diary-export-guide'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionTitle(
                              Icons.auto_stories_outlined,
                              context.tr('auth_guide_short'),
                            ),
                            const SizedBox(height: 14),
                            _buildGuideSteps(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        context.tr('diary_export_choose'),
                        style: KeepsakeStyle.text(
                          context,
                          size: 17,
                          weight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildExportCard(
                        id: 'html',
                        icon: Icons.menu_book_rounded,
                        title: context.tr('diary_export_html_title'),
                        description: context.tr('diary_export_html_body'),
                        action: context.tr('diary_export_html_action'),
                        color: KeepsakeStyle.sage,
                        isBusy: _isExportingHtml,
                        onTap: _exportHtml,
                      ),
                      if (_isPro == false) ...[
                        const SizedBox(height: 8),
                        _buildNote(
                          Icons.workspace_premium_outlined,
                          L10nService().format('pro_note_diary_export_range', {
                            'days': ProFeatureLimits.freeDiaryExportDays,
                          }),
                        ),
                      ],
                      const SizedBox(height: 12),
                      _buildExportCard(
                        id: 'pdf',
                        icon: Icons.picture_as_pdf_outlined,
                        title: context.tr('export_pdf'),
                        description: context.tr('diary_export_pdf_body'),
                        action: context.tr('export_pdf'),
                        color: KeepsakeStyle.rosewood,
                        isBusy: _isExportingPdf,
                        onTap: _exportPdf,
                        proBadge: true,
                      ),
                      const SizedBox(height: 12),
                      _buildExportCard(
                        id: 'zip',
                        icon: Icons.folder_zip_outlined,
                        title: context.tr('diary_export_zip_title'),
                        description: context.tr('diary_export_zip_body'),
                        action: context.tr('diary_export_zip_action'),
                        color: KeepsakeStyle.rosewood,
                        isBusy: _isExportingAll,
                        onTap: _exportAllMemories,
                      ),
                      if (_isExportingAll) _buildProgressSection(),
                      if (_exportError != null) ...[
                        const SizedBox(height: 12),
                        _buildPanel(
                          key: const Key('diary-export-error'),
                          child: Semantics(
                            liveRegion: true,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildNote(
                                  Icons.error_outline_rounded,
                                  _exportError!,
                                ),
                                const SizedBox(height: 8),
                                OutlinedButton(
                                  key: const Key('diary-export-retry'),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(48, 48),
                                    foregroundColor: KeepsakeStyle.ink(context),
                                  ),
                                  onPressed: _isBusy
                                      ? null
                                      : _retryExport,
                                  child: Text(context.tr('util_thli_4dffdf')),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      _buildNote(
                        Icons.fact_check_outlined,
                        context.tr('diary_export_check_note'),
                      ),
                      const SizedBox(height: 24),
                      _buildHistorySection(),
                      const SizedBox(height: 20),
                      _buildNote(
                        Icons.lock_outline_rounded,
                        context.tr('diary_export_safety_note'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildHouseCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: KeepsakeStyle.accentSurface(context),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.bookmark_added_outlined,
                color: KeepsakeStyle.accent(context),
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('diary_export_intro_title'),
                    style: KeepsakeStyle.text(
                      context,
                      size: 23,
                      weight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _houseName,
                    style: KeepsakeStyle.text(
                      context,
                      size: 13,
                      color: KeepsakeStyle.muted(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          context.tr('util_xutnhtklul_13b3fb'),
          style: KeepsakeStyle.text(
            context,
            size: 13,
            color: KeepsakeStyle.muted(context),
          ),
        ),
      ],
    );
  }

  Widget _buildPanel({Key? key, required Widget child}) {
    return Container(
      key: key,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KeepsakeStyle.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: KeepsakeStyle.line(context)),
      ),
      child: child,
    );
  }

  Widget _buildSectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 20, color: KeepsakeStyle.accent(context)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: KeepsakeStyle.text(
              context,
              size: 15,
              weight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGuideSteps() {
    const keys = [
      'diary_export_guide_choose',
      'diary_export_guide_wait',
      'diary_export_guide_save',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < keys.length; index++)
          Padding(
            padding: EdgeInsets.only(bottom: index == keys.length - 1 ? 0 : 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: const BoxConstraints(
                    minWidth: 26,
                    minHeight: 26,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: KeepsakeStyle.accentSurface(context),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${index + 1}',
                    textAlign: TextAlign.center,
                    style: KeepsakeStyle.text(
                      context,
                      size: 12,
                      weight: FontWeight.w600,
                      color: KeepsakeStyle.accent(context),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.tr(keys[index]),
                    style: KeepsakeStyle.text(context, size: 13),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildNote(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: KeepsakeStyle.muted(context)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: KeepsakeStyle.text(
              context,
              size: 12,
              color: KeepsakeStyle.muted(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressSection() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Semantics(
        liveRegion: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(
              value: _exportProgress.clamp(0, 1),
              backgroundColor: KeepsakeStyle.accentSurface(context),
              color: KeepsakeStyle.accent(context),
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
            const SizedBox(height: 8),
            Text(_exportStatus, style: KeepsakeStyle.text(context, size: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySection() {
    return Column(
      key: const Key('diary-export-history'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          Icons.history_rounded,
          context.tr('ui_utilities_recent_exports_f7b5d2'),
        ),
        const SizedBox(height: 6),
        Text(
          context.tr('diary_export_save_hint'),
          style: KeepsakeStyle.text(
            context,
            size: 12,
            color: KeepsakeStyle.muted(context),
          ),
        ),
        const SizedBox(height: 12),
        if (_history.isEmpty)
          _buildPanel(
            child: _buildNote(
              Icons.insert_drive_file_outlined,
              context.tr('diary_export_empty'),
            ),
          )
        else ...[
          Text(
            L10nScope.of(context).format('ui_utilities_value1_files_4bbfd0', {
              'value1': _history.length,
            }),
            style: KeepsakeStyle.text(
              context,
              size: 12,
              color: KeepsakeStyle.muted(context),
            ),
          ),
          const SizedBox(height: 8),
          ...List.generate(_history.length, _buildHistoryTile),
        ],
      ],
    );
  }

  Widget _buildHistoryTile(int index) {
    final record = _history[index];
    final fileName = record.filePath.split(RegExp(r'[/\\]')).last;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _buildPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  record.type == 'pdf'
                      ? Icons.picture_as_pdf_outlined
                      : record.type == 'html'
                      ? Icons.description_outlined
                      : Icons.folder_zip_outlined,
                  color: KeepsakeStyle.accent(context),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Tooltip(
                        message: fileName,
                        child: Text(
                          fileName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: KeepsakeStyle.text(
                            context,
                            size: 13,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        LocaleDateFormat.dateTime(record.exportedAt),
                        style: KeepsakeStyle.text(
                          context,
                          size: 12,
                          color: KeepsakeStyle.muted(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final twoColumns =
                    constraints.maxWidth >= 260 &&
                    MediaQuery.textScalerOf(context).scale(14) <= 18;
                final width = twoColumns
                    ? (constraints.maxWidth - 8) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _historyAction(
                      width,
                      'open-$index',
                      Icons.open_in_new_rounded,
                      context.tr('p8_notebook_open'),
                      () => _openFile(record.filePath),
                    ),
                    _historyAction(
                      width,
                      'share-$index',
                      Icons.ios_share_rounded,
                      context.tr('share'),
                      () => _shareFile(record.filePath),
                    ),
                    _historyAction(
                      width,
                      'save-$index',
                      Icons.file_download_outlined,
                      context.tr('ui_utilities_save_to_device_2562f6'),
                      () => _saveToDownloads(record.filePath, fileName),
                    ),
                    _historyAction(
                      width,
                      'delete-$index',
                      Icons.delete_outline_rounded,
                      context.tr('ui_utilities_delete_82339c'),
                      () => _confirmDelete(index, fileName),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _historyAction(
    double width,
    String id,
    IconData icon,
    String label,
    VoidCallback onPressed,
  ) {
    return SizedBox(
      width: width,
      child: OutlinedButton(
        key: Key('diary-export-$id'),
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          foregroundColor: KeepsakeStyle.ink(context),
          side: BorderSide(color: KeepsakeStyle.line(context)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label, style: KeepsakeStyle.text(context, size: 12)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(int index, String fileName) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => SLAlertDialog(
        title: Text(context.tr('ui_utilities_delete_export_file_eb5347')),
        content: Text(
          L10nScope.of(context).format(
            'ui_utilities_remove_value1_from_device_bb47eb',
            {'value1': fileName},
          ),
        ),
        actions: [
          SLDialogAction(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.tr('cancel')),
          ),
          SLDialogAction(
            primary: true,
            destructive: true,
            onPressed: () {
              Navigator.pop(dialogContext);
              _removeFromHistory(index);
            },
            child: Text(context.tr('ui_utilities_delete_82339c')),
          ),
        ],
      ),
    );
  }

  Widget _buildExportCard({
    required String id,
    required IconData icon,
    required String title,
    required String description,
    required String action,
    required Color color,
    required bool isBusy,
    required VoidCallback onTap,
    bool proBadge = false,
  }) {
    return _buildPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: KeepsakeStyle.dark(context)
                      ? KeepsakeStyle.accent(context)
                      : color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: KeepsakeStyle.text(
                              context,
                              size: 16,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (proBadge) ...[
                          const SizedBox(width: 6),
                          const UtilityVipBadge(compact: true),
                        ],
                      ],
                    ),
                    Text(
                      id.toUpperCase(),
                      style: KeepsakeStyle.text(
                        context,
                        size: 11,
                        color: KeepsakeStyle.muted(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: KeepsakeStyle.text(
              context,
              size: 13,
              color: KeepsakeStyle.muted(context),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            key: Key('diary-export-$id'),
            onPressed: _isBusy ? null : onTap,
            style: KeepsakeStyle.primary(context).copyWith(
              minimumSize: const WidgetStatePropertyAll(Size.fromHeight(48)),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            child: Row(
              children: [
                if (isBusy)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: KeepsakeStyle.muted(context),
                    ),
                  )
                else
                  const Icon(Icons.file_download_outlined, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isBusy ? context.tr('diary_export_working') : action,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
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
