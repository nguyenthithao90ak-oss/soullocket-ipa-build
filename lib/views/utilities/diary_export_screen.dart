import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

import '../../utils/services/export_service.dart';
import '../../core/sl_theme.dart';

class DiaryExportScreen extends StatefulWidget {
  final String houseId;

  const DiaryExportScreen({
    super.key,
    required this.houseId,
  });

  @override
  State<DiaryExportScreen> createState() => _DiaryExportScreenState();
}

class _DiaryExportScreenState extends State<DiaryExportScreen> {
  bool _isLoading = true;
  bool _isExportingHtml = false;
  String _houseName = L10nService().translate('util_nginhtnhyu_dbebce');

  @override
  void initState() {
    super.initState();
    _loadHouseName();
  }

  Future<void> _loadHouseName() async {
    try {
      _houseName = await ExportService().resolveDiaryHouseName(widget.houseId);
    } catch (_) {
      // Keep fallback label
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _exportHtml() async {
    if (_isExportingHtml) return;
    setState(() {
      _isExportingHtml = true;
    });

    try {
      await ExportService().exportDiary(
        houseId: widget.houseId,
        houseName: _houseName,
        format: DiaryExportFormat.html,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('util_tofilehtml_c9a8b2'),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('util_chathxutdl_223d08')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isExportingHtml = false;
        });
      }
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
                    Container(
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
                        ],
                      ),
                    ),
                    SLSpacing.h16,
                    _buildExportCard(
                      icon: Icons.language_rounded,
                      title: context.tr('util_xuthtml_c57dd1'),
                      description:
                          context.tr('util_tofilehtml_f2f8a2'),
                      colors: const [Color(0xFF5DA9FF), Color(0xFF7C4DFF)],
                      isBusy: _isExportingHtml,
                      onTap: _exportHtml,
                    ),
                  ],
                ),
              ),
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
