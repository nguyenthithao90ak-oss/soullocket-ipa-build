import 'package:flutter/material.dart';

import '../../core/sl_theme.dart';
import '../../utils/services/l10n_service.dart';
import '../../utils/services/love_card_link_service.dart';
import 'love_card_public_viewer_screen.dart';

class LoveCardPublicLinkScreen extends StatefulWidget {
  final Uri sourceUri;
  final VoidCallback onBack;
  final LoveCardLinkService linkService;

  const LoveCardPublicLinkScreen({
    super.key,
    required this.sourceUri,
    required this.onBack,
    this.linkService = const LoveCardLinkService(),
  });

  @override
  State<LoveCardPublicLinkScreen> createState() =>
      _LoveCardPublicLinkScreenState();
}

class _LoveCardPublicLinkScreenState extends State<LoveCardPublicLinkScreen> {
  late Future<LoveCardLinkPayload?> _payload;

  @override
  void initState() {
    super.initState();
    _payload = _loadPayload();
  }

  @override
  void didUpdateWidget(covariant LoveCardPublicLinkScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sourceUri != widget.sourceUri) {
      _payload = _loadPayload();
    }
  }

  Future<LoveCardLinkPayload?> _loadPayload() async {
    if (!LoveCardLinkService.isSupportedLoveCardUri(widget.sourceUri)) {
      return null;
    }
    final embedded = LoveCardLinkService.payloadFromUri(widget.sourceUri);
    if (embedded != null) return embedded;
    final shareId = LoveCardLinkService.shareIdFromUri(widget.sourceUri);
    if (shareId == null || shareId.isEmpty) return null;
    // Không để mất kết nối giữ người nhận ở màn hình tải vô thời hạn.
    return widget.linkService
        .fetchPayloadByShareId(shareId)
        .timeout(const Duration(seconds: 12));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LoveCardLinkPayload?>(
      future: _payload,
      builder: (context, snapshot) {
        final payload = snapshot.data;
        if (snapshot.connectionState == ConnectionState.done &&
            payload != null) {
          return LoveCardPublicViewerScreen(
            key: ValueKey(widget.sourceUri),
            payload: payload,
            sourceUri: widget.sourceUri,
            onBack: widget.onBack,
          );
        }
        final loading = snapshot.connectionState != ConnectionState.done;
        return Scaffold(
          backgroundColor: SLColors.bgMain,
          appBar: AppBar(
            leading: BackButton(onPressed: widget.onBack),
            title: Text(context.tr('util_thiptnhyu_4d90ec')),
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: loading
                  ? const CircularProgressIndicator()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.mail_outline_rounded,
                          color: SLColors.primary,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          context.tr(
                            snapshot.hasError
                                ? 'love_card_receiver_load_error'
                                : 'app_entry_linktthipk_810b8f',
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _payload = _loadPayload();
                            });
                          },
                          icon: const Icon(Icons.refresh_rounded),
                          label: Text(context.tr('core_retry')),
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}
