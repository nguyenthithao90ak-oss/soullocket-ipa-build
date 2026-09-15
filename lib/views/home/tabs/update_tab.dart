import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_config.dart';
import '../../../core/sl_route.dart';
import '../../../utils/services/auth_service.dart';
import '../../../utils/services/core/cloud_functions_helper.dart';
import '../../../utils/services/l10n_service.dart';
import '../../utilities/user_support_chat_screen.dart';
import '../screens/document_viewer_screen.dart';
import 'settings_tab.dart';
import 'widgets/update_hub_body.dart';

class UpdateTab extends StatefulWidget {
  const UpdateTab({super.key});
  @override
  State<UpdateTab> createState() => _UpdateTabState();
}

class _UpdateTabState extends State<UpdateTab>
    with AutomaticKeepAliveClientMixin {
  static const _supportEmail = 'hotroviethoangdev.lo.ve@gmail.com';
  final _feedbackCtrl = TextEditingController();
  bool _isSendingFeedback = false;
  String? _version;
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() => _version = '${info.version}+${info.buildNumber}');
      }
    } catch (error) {
      debugPrint('[UpdateHub] Version unavailable: $error');
    }
  }

  @override
  void dispose() {
    _feedbackCtrl.dispose();
    super.dispose();
  }

  void _openDocument(UpdateHubDocument document) {
    Navigator.push(
      context,
      SLRoute(
        builder: (_) => DocumentViewerScreen(
          title: context.tr(document.key),
          assetPath: document.asset,
        ),
      ),
    );
  }

  void _toast(String key) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.tr(key))));
  }

  Future<void> _openExternal(Uri uri, {String? fallback}) async {
    try {
      if (await launchUrl(uri, mode: LaunchMode.platformDefault)) return;
    } catch (error) {
      debugPrint('[UpdateHub] Link unavailable: $error');
    }
    if (!mounted) return;
    if (fallback != null) {
      try {
        await Clipboard.setData(ClipboardData(text: fallback));
        _toast('update_hub_link_copied');
        return;
      } catch (error) {
        debugPrint('[UpdateHub] Clipboard unavailable: $error');
      }
    }
    _toast('update_hub_link_failed');
  }

  void _showNews() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('update_hub_recent'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            for (final key in ['layout', 'style', 'help']) ...[
              Text(
                context.tr('update_hub_change_$key'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(context.tr('update_hub_change_${key}_note')),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    L10nScope.of(context);
    final isIos = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    return Scaffold(
      body: UpdateHubBody(
        version: _version,
        onSettings: () => Navigator.push(
          context,
          SLRoute(builder: (_) => const SettingsTab()),
        ),
        onDocument: _openDocument,
        onSupport: () => Navigator.push(
          context,
          SLRoute(builder: (_) => const UserSupportChatScreen()),
        ),
        onEmail: () => _openExternal(
          Uri(
            scheme: 'mailto',
            path: _supportEmail,
            queryParameters: const {'subject': 'SoulLocket Support'},
          ),
          fallback: _supportEmail,
        ),
        onDeleteRequest: () {
          final uri = AppConfig.legalDocumentUri(
            'delete-account.html',
            languageCode: L10nService().locale.languageCode,
          );
          _openExternal(uri, fallback: uri.toString());
        },
        onWebsite: isIos
            ? null
            : () => _openExternal(
                Uri.parse(AppConfig.webBaseUrl),
                fallback: AppConfig.webBaseUrl,
              ),
        onNews: _showNews,
        feedback: _feedback(),
      ),
    );
  }

  Widget _feedback() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        context.tr('update_hub_feedback_intro'),
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _feedbackCtrl,
        minLines: 4,
        maxLines: 7,
        maxLength: 500,
        enabled: !_isSendingFeedback,
        decoration: InputDecoration(
          labelText: context.tr('update_hub_feedback'),
          hintText: context.tr('update_hub_feedback_hint'),
          alignLabelWithHint: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
      const SizedBox(height: 14),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _isSendingFeedback ? null : _sendFeedback,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFA83F65),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          icon: _isSendingFeedback
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send_rounded, size: 18),
          label: Text(
            context.tr(
              _isSendingFeedback ? 'update_hub_sending' : 'update_hub_send',
            ),
          ),
        ),
      ),
    ],
  );

  Future<void> _sendFeedback() async {
    if (_isSendingFeedback) return;
    final content = _feedbackCtrl.text.trim();
    if (content.length < 5) {
      _toast('update_hub_feedback_short');
      return;
    }
    if (content.length > 500) {
      _toast('update_hub_feedback_long');
      return;
    }
    if (AuthService().currentUser == null) {
      _toast('update_hub_feedback_signin');
      return;
    }
    setState(() => _isSendingFeedback = true);
    try {
      final response = await CloudFunctionsHelper.callSecure<dynamic>(
        'submitFeedbackSecure',
        payload: <String, dynamic>{'content': content},
        fallbackErrorMessage: context.tr('update_hub_feedback_failed'),
      );
      if (!mounted) return;
      final data = response.data;
      if (data is! Map || data['success'] != true) {
        _toast('update_hub_feedback_failed');
        return;
      }
      _feedbackCtrl.clear();
      _toast('update_hub_feedback_thanks');
    } catch (error) {
      debugPrint('[Feedback] Error sending feedback: $error');
      _toast('update_hub_feedback_failed');
    } finally {
      if (mounted) setState(() => _isSendingFeedback = false);
    }
  }
}
