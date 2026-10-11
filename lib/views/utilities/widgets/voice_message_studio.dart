import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/screen_activity_mixin.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

/// Chỉ trình bày dữ liệu và gọi callback; ghi âm và Firebase thuộc VoiceScreen.
class VoiceMessagePresentation {
  const VoiceMessagePresentation({
    required this.id,
    required this.title,
    required this.dateLabel,
    required this.durationLabel,
    this.fileName = '',
    this.playable = true,
  });

  final String id, title, dateLabel, durationLabel, fileName;
  final bool playable;
}

enum VoiceLibraryState { ready, loading, empty, error, invalid }

abstract final class VoiceStudioStyle {
  static bool dark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;
  static Color canvas(BuildContext context) =>
      dark(context) ? SLColors.darkBgMain : const Color(0xFFFBF7F3);
  static Color surface(BuildContext context) =>
      dark(context) ? SLColors.darkBgCard : Colors.white;
  static Color ink(BuildContext context) =>
      dark(context) ? SLColors.darkTextPrimary : const Color(0xFF332C3B);
  static Color muted(BuildContext context) =>
      dark(context) ? SLColors.darkTextSecond : const Color(0xFF847885);
  static Color accent(BuildContext context) =>
      dark(context) ? const Color(0xFFF0A6BC) : const Color(0xFFA54D69);
  static Color line(BuildContext context) =>
      dark(context) ? SLColors.darkBorder : const Color(0xFFEDDFE3);
  static Color tint(BuildContext context) =>
      dark(context) ? const Color(0xFF3B2A35) : const Color(0xFFFAEBF0);

  static TextStyle text(
    BuildContext context, {
    double size = 14,
    FontWeight weight = FontWeight.w600,
    Color? color,
    double height = 1.4,
  }) => Theme.of(context).textTheme.bodyMedium!.copyWith(
    fontSize: size,
    fontWeight: weight,
    color: color ?? ink(context),
    height: height,
  );
}

class VoiceStudioView extends StatelessWidget {
  const VoiceStudioView({
    super.key,
    required this.messages,
    required this.libraryState,
    required this.elapsedLabel,
    required this.storedLabel,
    required this.capacityLabel,
    required this.capacityFraction,
    required this.recordingAnimation,
    required this.onRecord,
    required this.onUpload,
    required this.onPlay,
    required this.onDelete,
    required this.onBack,
    required this.onInfo,
    required this.onRetryUpload,
    this.recording = false,
    this.uploading = false,
    this.restoringUpload = false,
    this.pendingUpload = false,
    this.refreshing = false,
    this.playingId,
    this.loadingId,
  });

  final List<VoiceMessagePresentation> messages;
  final VoiceLibraryState libraryState;
  final String elapsedLabel, storedLabel, capacityLabel;
  final double capacityFraction;
  final Animation<double> recordingAnimation;
  final bool recording, uploading, restoringUpload, pendingUpload, refreshing;
  final String? playingId, loadingId;
  final VoidCallback onRecord, onUpload, onBack, onInfo, onRetryUpload;
  final ValueChanged<String> onPlay, onDelete;

  @override
  Widget build(BuildContext context) {
    final knownCapacity =
        libraryState == VoiceLibraryState.ready ||
        libraryState == VoiceLibraryState.empty;
    return Scaffold(
      backgroundColor: VoiceStudioStyle.canvas(context),
      appBar: AppBar(
        backgroundColor: VoiceStudioStyle.canvas(context),
        foregroundColor: VoiceStudioStyle.ink(context),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        toolbarHeight: MediaQuery.textScalerOf(context).scale(19) > 28
            ? 80
            : 64,
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsetsDirectional.only(start: 12),
          child: IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: onBack,
            icon: const BackButtonIcon(),
          ),
        ),
        titleSpacing: 0,
        title: Text(
          context.tr('voice_screen_title'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: VoiceStudioStyle.text(
            context,
            size: 19,
            weight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: context.tr('auth_guide_short'),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: onInfo,
            icon: Icon(
              Icons.info_outline_rounded,
              color: VoiceStudioStyle.muted(context),
              size: 22,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: CustomScrollView(
              key: const PageStorageKey('voice-studio-scroll'),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _VoiceRecordCard(
                          recording: recording,
                          uploading: uploading,
                          elapsedLabel: elapsedLabel,
                          animation: recordingAnimation,
                          onRecord: onRecord,
                        ),
                        const SizedBox(height: 14),
                        _VoiceUploadTile(
                          enabled: !recording && !uploading,
                          onUpload: onUpload,
                        ),
                        if (uploading) ...[
                          const SizedBox(height: 12),
                          _VoiceNotice(
                            loading: true,
                            label: context.tr(
                              restoringUpload
                                  ? 'util_angkhiphcu_076cd4'
                                  : 'util_angupload_7ded4c',
                            ),
                          ),
                        ],
                        if (pendingUpload && !uploading) ...[
                          const SizedBox(height: 12),
                          _VoiceNotice(
                            label: context.tr('util_lnuploadgh_c94950'),
                            onRetry: onRetryUpload,
                          ),
                        ],
                        const SizedBox(height: 28),
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            Text(
                              context.tr('voice_library_title'),
                              style: VoiceStudioStyle.text(
                                context,
                                size: 19,
                                weight: FontWeight.w800,
                              ),
                            ),
                            if (knownCapacity)
                              _VoiceBadge(
                                label: L10nService().translateRecordsCount(
                                  messages.length,
                                ),
                              ),
                          ],
                        ),
                        if (knownCapacity) ...[
                          const SizedBox(height: 16),
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            spacing: 12,
                            runSpacing: 4,
                            children: [
                              Text(
                                context.tr('voice_storage_label'),
                                style: VoiceStudioStyle.text(
                                  context,
                                  size: 12,
                                  color: VoiceStudioStyle.muted(context),
                                ),
                              ),
                              Text(
                                '$storedLabel / $capacityLabel',
                                textDirection: TextDirection.ltr,
                                style:
                                    VoiceStudioStyle.text(
                                      context,
                                      size: 12,
                                      weight: FontWeight.w700,
                                      color: VoiceStudioStyle.muted(context),
                                    ).copyWith(
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              minHeight: 4,
                              value: capacityFraction.clamp(0, 1),
                              color: VoiceStudioStyle.accent(context),
                              backgroundColor: VoiceStudioStyle.line(context),
                            ),
                          ),
                        ],
                        if (refreshing) ...[
                          const SizedBox(height: 10),
                          const LinearProgressIndicator(minHeight: 2),
                        ],
                      ],
                    ),
                  ),
                ),
                if (libraryState == VoiceLibraryState.ready)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    sliver: SliverList.builder(
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: VoiceMessageCard(
                            key: ValueKey('voice-message-${message.id}'),
                            message: message,
                            playing: playingId == message.id,
                            loading: loadingId == message.id,
                            onPlay: () => onPlay(message.id),
                            onDelete: () => onDelete(message.id),
                          ),
                        );
                      },
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    sliver: SliverToBoxAdapter(
                      child: _VoiceLibraryPlaceholder(state: libraryState),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VoiceRecordCard extends StatelessWidget {
  const _VoiceRecordCard({
    required this.recording,
    required this.uploading,
    required this.elapsedLabel,
    required this.animation,
    required this.onRecord,
  });

  final bool recording, uploading;
  final String elapsedLabel;
  final Animation<double> animation;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) {
    final dark = VoiceStudioStyle.dark(context);
    final accent = VoiceStudioStyle.accent(context);
    final action = context.tr(
      recording ? 'voice_stop_action' : 'voice_record_action',
    );
    final motion =
        recording &&
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context) &&
        !MediaQuery.accessibleNavigationOf(context);
    return DecoratedBox(
      key: const Key('voice-record-card'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xFF382832), Color(0xFF282430)]
              : const [Color(0xFFF9E7EC), Color(0xFFFFF3E9)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: VoiceStudioStyle.line(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
        child: Column(
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(Icons.favorite_outline_rounded, size: 17, color: accent),
                Text(
                  context.tr('voice_studio_title'),
                  textAlign: TextAlign.center,
                  style: VoiceStudioStyle.text(
                    context,
                    size: 23,
                    weight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('voice_studio_hint'),
              textAlign: TextAlign.center,
              style: VoiceStudioStyle.text(
                context,
                size: 12,
                color: VoiceStudioStyle.muted(context),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: VoiceWaveform(color: accent, bars: 11)),
                const SizedBox(width: 8),
                AnimatedBuilder(
                  animation: motion
                      ? animation
                      : const AlwaysStoppedAnimation(0.0),
                  builder: (context, child) => Container(
                    width: 134,
                    height: 134,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: accent.withValues(alpha: .12)),
                    ),
                    alignment: Alignment.center,
                    child: Container(
                      width: 112 + (motion ? animation.value * 5 : 0),
                      height: 112 + (motion ? animation.value * 5 : 0),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent.withValues(alpha: .07),
                      ),
                      alignment: Alignment.center,
                      child: child,
                    ),
                  ),
                  child: Semantics(
                    button: true,
                    enabled: !uploading,
                    label: action,
                    child: Tooltip(
                      message: action,
                      child: Material(
                        shape: const CircleBorder(),
                        color: Colors.transparent,
                        child: Ink(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: recording
                                  ? const [Color(0xFFD8667E), Color(0xFFB93D5E)]
                                  : const [
                                      Color(0xFFC98299),
                                      Color(0xFFA45271),
                                    ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF9C3B60,
                                ).withValues(alpha: .2),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: InkWell(
                            key: const Key('voice-record-action'),
                            customBorder: const CircleBorder(),
                            onTap: uploading ? null : onRecord,
                            excludeFromSemantics: true,
                            child: SizedBox(
                              width: 92,
                              height: 92,
                              child: Icon(
                                recording
                                    ? Icons.stop_rounded
                                    : Icons.mic_rounded,
                                size: recording ? 40 : 38,
                                color: Colors.white.withValues(
                                  alpha: uploading ? .5 : 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: VoiceWaveform(color: accent, bars: 11)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              elapsedLabel,
              textDirection: TextDirection.ltr,
              style: VoiceStudioStyle.text(
                context,
                size: 38,
                weight: FontWeight.w700,
                height: 1.15,
              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
            const SizedBox(height: 10),
            _VoiceBadge(
              label: context.tr(
                recording ? 'voice_recording_status' : 'voice_ready_status',
              ),
              recording: recording,
            ),
            const SizedBox(height: 9),
            Text(
              action,
              textAlign: TextAlign.center,
              style: VoiceStudioStyle.text(
                context,
                size: 12,
                color: VoiceStudioStyle.muted(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoiceUploadTile extends StatelessWidget {
  const _VoiceUploadTile({required this.enabled, required this.onUpload});
  final bool enabled;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) => Material(
    color: VoiceStudioStyle.surface(context),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(color: VoiceStudioStyle.line(context)),
    ),
    child: InkWell(
      key: const Key('voice-upload-action'),
      borderRadius: BorderRadius.circular(20),
      onTap: enabled ? onUpload : null,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: VoiceStudioStyle.tint(context),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                Icons.file_upload_outlined,
                color: VoiceStudioStyle.accent(
                  context,
                ).withValues(alpha: enabled ? 1 : .4),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('ui_utilities_upload_an_audio_file_4bc04e'),
                    style: VoiceStudioStyle.text(
                      context,
                      size: 13,
                      weight: FontWeight.w800,
                      color: enabled
                          ? VoiceStudioStyle.ink(context)
                          : VoiceStudioStyle.muted(context),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    context.tr('voice_upload_hint'),
                    style: VoiceStudioStyle.text(
                      context,
                      size: 10,
                      color: VoiceStudioStyle.muted(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              textDirection: Directionality.of(context),
              color: VoiceStudioStyle.muted(context),
              size: 20,
            ),
          ],
        ),
      ),
    ),
  );
}

class VoiceMessageCard extends StatelessWidget {
  const VoiceMessageCard({
    super.key,
    required this.message,
    required this.onPlay,
    required this.onDelete,
    this.playing = false,
    this.loading = false,
  });

  final VoiceMessagePresentation message;
  final VoidCallback onPlay, onDelete;
  final bool playing, loading;

  @override
  Widget build(BuildContext context) {
    final accent = VoiceStudioStyle.accent(context);
    return AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 180),
      padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 12, 16),
      decoration: BoxDecoration(
        color: VoiceStudioStyle.surface(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: playing
              ? accent.withValues(alpha: .55)
              : VoiceStudioStyle.line(context),
        ),
        boxShadow: VoiceStudioStyle.dark(context)
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF73435D).withValues(alpha: .035),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                ),
              ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.title,
                      style: VoiceStudioStyle.text(
                        context,
                        size: 14,
                        weight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      playing
                          ? context.tr('voice_playing_status')
                          : message.dateLabel,
                      style: VoiceStudioStyle.text(
                        context,
                        size: 11,
                        color: playing
                            ? accent
                            : VoiceStudioStyle.muted(context),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: ValueKey('voice-delete-${message.id}'),
                tooltip: context.tr('p3_delete'),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                onPressed: onDelete,
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 20,
                  color: VoiceStudioStyle.muted(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton.filled(
                key: ValueKey('voice-play-${message.id}'),
                tooltip: context.tr(
                  playing ? 'voice_stop_playback_action' : 'voice_play_action',
                ),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                style: IconButton.styleFrom(
                  backgroundColor: playing
                      ? accent
                      : VoiceStudioStyle.tint(context),
                  foregroundColor: playing
                      ? VoiceStudioStyle.canvas(context)
                      : accent,
                  disabledBackgroundColor: VoiceStudioStyle.line(context),
                ),
                onPressed: message.playable && !loading ? onPlay : null,
                icon: loading
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: accent,
                        ),
                      )
                    : Icon(
                        playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                        size: 28,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: VoiceWaveform(
                  color: accent,
                  active: playing,
                  seed: message.id.hashCode,
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  message.durationLabel,
                  textDirection: TextDirection.ltr,
                  style:
                      VoiceStudioStyle.text(
                        context,
                        size: 12,
                        weight: FontWeight.w700,
                      ).copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
          if (message.fileName.isNotEmpty) ...[
            const SizedBox(height: 9),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                message.fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: VoiceStudioStyle.text(
                  context,
                  size: 10,
                  weight: FontWeight.w500,
                  color: VoiceStudioStyle.muted(context),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _VoiceBadge extends StatelessWidget {
  const _VoiceBadge({required this.label, this.recording = false});
  final String label;
  final bool recording;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
    decoration: BoxDecoration(
      color: VoiceStudioStyle.surface(context).withValues(alpha: .75),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      label,
      textAlign: TextAlign.center,
      style: VoiceStudioStyle.text(
        context,
        size: 11,
        weight: FontWeight.w700,
        color: VoiceStudioStyle.accent(context),
      ),
    ),
  );
}

class _VoiceNotice extends StatelessWidget {
  const _VoiceNotice({required this.label, this.loading = false, this.onRetry});
  final String label;
  final bool loading;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: VoiceStudioStyle.tint(context),
      borderRadius: BorderRadius.circular(16),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final status = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (loading)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: VoiceStudioStyle.accent(context),
                ),
              )
            else
              Icon(
                Icons.cloud_off_rounded,
                size: 20,
                color: VoiceStudioStyle.accent(context),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: VoiceStudioStyle.text(
                  context,
                  size: 12,
                  color: VoiceStudioStyle.accent(context),
                ),
              ),
            ),
          ],
        );
        final retry = onRetry == null
            ? null
            : TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: onRetry,
                child: Text(
                  context.tr('util_thli_4dffdf'),
                  style: VoiceStudioStyle.text(
                    context,
                    size: 12,
                    color: VoiceStudioStyle.accent(context),
                  ),
                ),
              );
        if (retry == null) return status;
        if (constraints.maxWidth < 300 ||
            MediaQuery.textScalerOf(context).scale(12) > 18) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [status, const SizedBox(height: 8), retry],
          );
        }
        return Row(
          children: [
            Expanded(child: status),
            const SizedBox(width: 8),
            retry,
          ],
        );
      },
    ),
  );
}

class _VoiceLibraryPlaceholder extends StatelessWidget {
  const _VoiceLibraryPlaceholder({required this.state});
  final VoiceLibraryState state;

  @override
  Widget build(BuildContext context) {
    if (state == VoiceLibraryState.loading) {
      return Padding(
        padding: const EdgeInsets.all(28),
        child: Semantics(
          liveRegion: true,
          child: _VoiceNotice(loading: true, label: context.tr('loading')),
        ),
      );
    }
    final empty = state == VoiceLibraryState.empty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: VoiceStudioStyle.surface(context),
        border: Border.all(color: VoiceStudioStyle.line(context)),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Icon(
            empty ? Icons.graphic_eq_rounded : Icons.cloud_off_rounded,
            size: 36,
            color: VoiceStudioStyle.accent(context),
          ),
          const SizedBox(height: 12),
          Text(
            context.tr(
              empty
                  ? 'voice_empty_title'
                  : state == VoiceLibraryState.invalid
                  ? 'util_dliulinhnt_f7fe04'
                  : 'util_khngticlin_a510e1',
            ),
            textAlign: TextAlign.center,
            style: VoiceStudioStyle.text(
              context,
              size: 14,
              weight: FontWeight.w700,
            ),
          ),
          if (empty) ...[
            const SizedBox(height: 6),
            Text(
              context.tr('util_chaclinhnt_9864b0'),
              textAlign: TextAlign.center,
              style: VoiceStudioStyle.text(
                context,
                size: 12,
                color: VoiceStudioStyle.muted(context),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Sóng trang trí; không biểu diễn biên độ thực hoặc vị trí tua của tệp.
class VoiceWaveform extends StatefulWidget {
  const VoiceWaveform({
    super.key,
    required this.color,
    this.active = false,
    this.bars = 32,
    this.seed = 0,
  });
  final Color color;
  final bool active;
  final int bars, seed;

  @override
  State<VoiceWaveform> createState() => _VoiceWaveformState();
}

class _VoiceWaveformState extends State<VoiceWaveform>
    with SingleTickerProviderStateMixin, ScreenActivityMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didUpdateWidget(covariant VoiceWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncMotion();
  }

  @override
  void onScreenActivityChanged(bool active) => _syncMotion();

  void _syncMotion() {
    if (widget.active &&
        isScreenActive &&
        !MediaQuery.disableAnimationsOf(context) &&
        !MediaQuery.accessibleNavigationOf(context)) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: RepaintBoundary(
      child: SizedBox(
        height: 32,
        child: CustomPaint(
          painter: _VoiceWaveformPainter(
            color: widget.color,
            bars: widget.bars,
            seed: widget.seed,
            animation: _controller,
            active: widget.active,
          ),
          size: Size.infinite,
        ),
      ),
    ),
  );
}

class _VoiceWaveformPainter extends CustomPainter {
  _VoiceWaveformPainter({
    required this.color,
    required this.bars,
    required this.seed,
    required this.animation,
    required this.active,
  }) : super(repaint: animation);
  final Color color;
  final int bars, seed;
  final Animation<double> animation;
  double get phase => active ? animation.value : 0;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0) return;
    final count = math.min(bars, math.max(1, (size.width / 5).floor()));
    final step = size.width / count;
    final width = math.min(3.0, step * .5);
    final paint = Paint()..color = color.withValues(alpha: active ? .85 : .35);
    for (var i = 0; i < count; i++) {
      final amplitude = .22 + .68 * math.sin((i + seed % 7) * 1.83).abs();
      final motion = active
          ? .58 + .42 * math.sin(phase * 2 * math.pi + i * .64).abs()
          : 1.0;
      final height = math.max(3.0, size.height * amplitude * motion);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            i * step + (step - width) / 2,
            (size.height - height) / 2,
            width,
            height,
          ),
          const Radius.circular(3),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _VoiceWaveformPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.bars != bars ||
      oldDelegate.seed != seed ||
      oldDelegate.animation != animation ||
      oldDelegate.active != active;
}
