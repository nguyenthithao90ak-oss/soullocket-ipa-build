part of '../cinema_screen.dart';

extension _CinemaReelPlayerDialogsPart on _CinemaReelPlayerScreenState {
  Future<void> _editTitle() async {
    final controller = TextEditingController(text: _exportTitle);
    try {
      final nextTitle = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF111113),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (sheetContext) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.maybeOf(sheetContext)?.viewInsets.bottom ?? 0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  context.tr('util_tiuvideokn_0a7786'),
                  style: SLTheme.quicksand(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr('util_vdknimalbu_a9c42d'),
                  style: SLTheme.quicksand(
                    fontSize: 13.5,
                    color: Colors.white.withValues(alpha: 0.68),
                  ),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: controller,
                  autofocus: true,
                  maxLength: 72,
                  maxLines: 2,
                  style: SLTheme.quicksand(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  decoration: InputDecoration(
                    hintText: context.tr('util_nhptiumunh_f0b220'),
                    hintStyle: SLTheme.quicksand(
                      fontSize: 15,
                      color: Colors.white.withValues(alpha: 0.38),
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.06),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(
                        color: Color(0xFFFF8FB1),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      try {
                        Navigator.of(sheetContext).pop(controller.text.trim());
                      } catch (e) {
                        // Context may be invalid
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF8FB1),
                      foregroundColor: const Color(0xFF22070E),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    icon: const Icon(Icons.check_rounded),
                    label: Text(
                      context.tr('util_pdngtiu_defa0e'),
                      style: SLTheme.quicksand(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF22070E),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );

      if (!mounted || nextTitle == null) {
        return;
      }
      try {
        final normalizedTitle = nextTitle.trim().isEmpty
            ? _buildDefaultExportTitle(widget.reel)
            : nextTitle.trim();
        if (normalizedTitle == _titleController.text.trim()) {
          return;
        }
        _titleController.text = normalizedTitle;
        _exportedVideoPath = null;
        _exportedVideoSignature = null;
        if (mounted) {
          _commitState(() {
            _videoProgress = null;
            _videoStatus = context.tr('util_cpnhttiuhy_f6ca1a');
          });
        }
      } catch (e) {
        // Handle any error during state update
      }
    } finally {
      controller.dispose();
    }
  }

  void _showPlayerSnack(
    String message, {
    Color backgroundColor = const Color(0xFF1E1E21),
  }) {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: backgroundColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      // Context may not be valid
    }
  }
}
