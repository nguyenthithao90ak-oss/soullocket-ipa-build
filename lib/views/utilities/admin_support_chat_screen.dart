import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:intl/intl.dart';

import '../../core/sl_theme.dart';
import '../../utils/app_error_mapper.dart';
import 'support_ticket_shared.dart';

class AdminSupportChatScreen extends StatefulWidget {
  const AdminSupportChatScreen({super.key});

  @override
  State<AdminSupportChatScreen> createState() => _AdminSupportChatScreenState();
}

class _AdminSupportChatScreenState extends State<AdminSupportChatScreen> {
  final _db = FirebaseDatabase.instance.ref();
  final List<Map<String, dynamic>> _tickets = [];
  StreamSubscription<DatabaseEvent>? _ticketsSub;

  @override
  void initState() {
    super.initState();
    _ticketsSub = _db
        .child('support_tickets')
        .orderByChild('last_ts')
        .limitToLast(100)
        .onValue
        .listen(
      (event) {
        final raw = event.snapshot.value;
        if (raw is! Map) {
          if (mounted) {
            setState(() => _tickets.clear());
          }
          return;
        }

        final loaded = <Map<String, dynamic>>[];
        raw.forEach((key, value) {
          if (key == 'general_chat' || value is! Map) return;
          final item = Map<String, dynamic>.from(value);
          item['id'] = key.toString();
          loaded.add(item);
        });

        loaded.sort(
          (a, b) => ((b['last_ts'] as num?)?.toInt() ?? 0)
              .compareTo((a['last_ts'] as num?)?.toInt() ?? 0),
        );

        if (!mounted) return;
        setState(() {
          _tickets
            ..clear()
            ..addAll(loaded);
        });
      },
      onError: (Object error) {
        String msg = 'util_khngthtida_9bb7ee';
        if (mounted) msg = context.tr(msg);
        debugPrint(
          'Admin support listener failed: ${AppErrorMapper.resolve(
            error,
            fallbackMessage: msg,
          ).message}',
        );
      },
    );
  }

  @override
  void dispose() {
    _ticketsSub?.cancel();
    super.dispose();
  }

  String _statusLabel(String raw) {
    switch (raw) {
      case 'waiting_for_admin':
        return context.tr('util_angch_2bfffc');
      case 'bot_handled':
        return context.tr('util_bothngdn_97773b');
      case 'resolved':
        return context.tr('util_phnhi_688d40');
      case 'closed':
        return context.tr('util_ng_d7bccb');
      default:
        return context.tr('util_mi_cd5dc8');
    }
  }

  Color _statusColor(String raw) {
    switch (raw) {
      case 'waiting_for_admin':
        return const Color(0xFFE65100);
      case 'bot_handled':
        return const Color(0xFF1565C0);
      case 'resolved':
        return const Color(0xFF2E7D32);
      case 'closed':
        return const Color(0xFF5D4037);
      default:
        return const Color(0xFFD81B60);
    }
  }

  String _ticketSummary(Map<String, dynamic> ticket) {
    final reason = ticket['reason']?.toString().trim() ?? '';
    if (reason.isNotEmpty) {
      return reason;
    }
    return ticket['last_message']?.toString().trim() ?? '';
  }

  List<String> _ticketBadges(Map<String, dynamic> ticket) {
    final badges = <String>[];
    final category = ticket['category']?.toString().trim() ?? '';
    final appVersion = ticket['app_version']?.toString().trim() ?? '';
    final deviceModel = ticket['device_model']?.toString().trim() ?? '';
    final devicePlatform = ticket['device_platform']?.toString().trim() ?? '';

    if (category.isNotEmpty) {
      badges.add(category);
    }
    if (appVersion.isNotEmpty) {
      badges.add(appVersion);
    }
    final deviceLabel = [deviceModel, devicePlatform]
        .where((item) => item.isNotEmpty)
        .join(' • ');
    if (deviceLabel.isNotEmpty) {
      badges.add(deviceLabel);
    }
    return badges;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Helpdesk (Admin)',
          style: SLTheme.quicksand(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFFF1F5F9),
      body: _tickets.isEmpty
          ? Center(
              child: Text(
                context.tr('util_khngcticke_1724ba'),
                style: SLTheme.quicksand(fontWeight: FontWeight.w700),
              ),
            )
          : ListView.separated(
              itemCount: _tickets.length,
              padding: const EdgeInsets.symmetric(vertical: 8),
              separatorBuilder: (_, __) => const SizedBox(height: 1),
              itemBuilder: (_, index) {
                final ticket = _tickets[index];
                final unread =
                    ((ticket['unread_admin'] as num?)?.toInt() ?? 0) > 0;
                final lastTs = (ticket['last_ts'] as num?)?.toInt() ?? 0;
                final time = lastTs == 0
                    ? ''
                    : DateFormat('HH:mm dd/MM').format(
                        DateTime.fromMillisecondsSinceEpoch(lastTs),
                      );
                final status = ticket['status']?.toString().trim() ?? 'new';
                final badges = _ticketBadges(ticket);

                return ListTile(
                  tileColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFD81B60),
                    child:
                        Icon(Icons.support_agent_rounded, color: Colors.white),
                  ),
                  title: Text(
                    ticket['name']?.toString() ??
                        context.tr('util_vdanh_f4df97'),
                    style: SLTheme.quicksand(
                      fontWeight: unread ? FontWeight.bold : FontWeight.w700,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _ticketSummary(ticket),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: SLTheme.quicksand(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF334155),
                          ),
                        ),
                        if (badges.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: badges
                                .take(3)
                                .map(
                                  (badge) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFCE4EC),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      badge,
                                      style: SLTheme.quicksand(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFFD81B60),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        time,
                        style: SLTheme.quicksand(
                          fontSize: 10,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _statusColor(status).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _statusLabel(status),
                          style: SLTheme.quicksand(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: _statusColor(status),
                          ),
                        ),
                      ),
                      if (unread)
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            context.tr('util_mi_cd5dc8'),
                            style: SLTheme.quicksand(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AdminSupportChatDetailScreen(
                          ticketId: ticket['id'].toString(),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

class AdminSupportChatDetailScreen extends StatefulWidget {
  const AdminSupportChatDetailScreen({
    super.key,
    required this.ticketId,
  });

  final String ticketId;

  @override
  State<AdminSupportChatDetailScreen> createState() =>
      _AdminSupportChatDetailScreenState();
}

class _AdminSupportChatDetailScreenState
    extends State<AdminSupportChatDetailScreen> {
  final _db = FirebaseDatabase.instance.ref();
  final _msgCtrl = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  StreamSubscription<DatabaseEvent>? _ticketSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _messagesSub;
  Map<String, dynamic>? _ticket;

  @override
  void initState() {
    super.initState();
    _db.child('support_tickets/${widget.ticketId}/unread_admin').set(0);

    _ticketSub = _db.child('support_tickets/${widget.ticketId}').onValue.listen(
      (event) {
        final raw = event.snapshot.value;
        if (raw is! Map) {
          if (mounted) {
            setState(() => _ticket = null);
          }
          return;
        }

        final item = Map<String, dynamic>.from(raw);
        item.remove('messages');
        if (!mounted) return;
        setState(() => _ticket = item);
      },
      onError: (Object error) {
        String msg = 'util_khngthtidl_617c2c';
        if (mounted) msg = context.tr(msg);
        debugPrint(
          'Admin ticket listener failed: ${AppErrorMapper.resolve(
            error,
            fallbackMessage: msg,
          ).message}',
        );
      },
    );

    _messagesSub = FirebaseFirestore.instance
        .collection('support_tickets')
        .doc(widget.ticketId)
        .collection('messages')
        .orderBy('ts')
        .snapshots()
        .listen(
      (snapshot) {
        final loaded = snapshot.docs.map((doc) {
          final value = doc.data();
          final item = Map<String, dynamic>.from(value);
          item['id'] = doc.id;
          return item;
        }).toList();

        if (!mounted) return;
        setState(() {
          _messages
            ..clear()
            ..addAll(loaded);
        });
      },
      onError: (Object error) {
        String msg = 'util_khngthtihi_4d3f34';
        if (mounted) msg = context.tr(msg);
        debugPrint(
          'Admin messages listener failed: ${AppErrorMapper.resolve(
            error,
            fallbackMessage: msg,
          ).message}',
        );
      },
    );
  }

  @override
  void dispose() {
    _ticketSub?.cancel();
    _messagesSub?.cancel();
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    await FirebaseFirestore.instance
        .collection('support_tickets')
        .doc(widget.ticketId)
        .collection('messages')
        .add({
      'text': text,
      'is_admin': true,
      'is_bot': false,
      'sender': 'Admin',
      'ts': DateTime.now().millisecondsSinceEpoch,
    });

    await _db.child('support_tickets/${widget.ticketId}').update({
      'last_message': text,
      'last_ts': ServerValue.timestamp,
      'status': 'resolved',
      'unread_admin': 0,
    });

    _msgCtrl.clear();
  }

  String _statusLabel(String raw) {
    switch (raw) {
      case 'waiting_for_admin':
        return context.tr('util_angchadmin_fa0fd4');
      case 'bot_handled':
        return context.tr('util_bothngdn_97653b');
      case 'resolved':
        return context.tr('util_phnhi_688d40');
      case 'closed':
        return context.tr('util_ng_d7bccb');
      default:
        return context.tr('util_mi_cd5dc8');
    }
  }

  Color _statusColor(String raw) {
    switch (raw) {
      case 'waiting_for_admin':
        return const Color(0xFFE65100);
      case 'bot_handled':
        return const Color(0xFF1565C0);
      case 'resolved':
        return const Color(0xFF2E7D32);
      case 'closed':
        return const Color(0xFF5D4037);
      default:
        return const Color(0xFFD81B60);
    }
  }

  Map<String, String> _resolvedContext() {
    final merged = <String, String>{};
    for (final message in _messages) {
      final isUserMessage =
          message['is_admin'] != true && message['is_bot'] != true;
      if (!isUserMessage) continue;
      final rawContext = message['context'];
      if (rawContext is Map) {
        merged.addAll(normalizeSupportContext(rawContext));
        break;
      }
    }

    final ticket = _ticket ?? const <String, dynamic>{};
    final rootPairs = <String, String>{
      'email': ticket['email']?.toString().trim() ?? '',
      'uid': ticket['user_uid']?.toString().trim() ?? '',
      'houseId': ticket['house_id']?.toString().trim() ?? '',
      'deviceModel': ticket['device_model']?.toString().trim() ?? '',
      'deviceOs': ticket['device_os']?.toString().trim() ?? '',
      'devicePlatform': ticket['device_platform']?.toString().trim() ?? '',
      'appVersion': ticket['app_version']?.toString().trim() ?? '',
      'buildName': ticket['build_name']?.toString().trim() ?? '',
      'buildNumber': ticket['build_number']?.toString().trim() ?? '',
      'openedFrom': ticket['opened_from']?.toString().trim() ?? '',
    };
    for (final entry in rootPairs.entries) {
      if (entry.value.isNotEmpty) {
        merged[entry.key] = entry.value;
      }
    }
    return merged;
  }

  String _ticketCategory() {
    final ticket = _ticket ?? const <String, dynamic>{};
    final category = ticket['category']?.toString().trim() ?? '';
    if (category.isNotEmpty) {
      return category;
    }
    final topicId = ticket['topic_id']?.toString().trim() ?? '';
    return supportTopicById(topicId)?.title ?? context.tr('util_htrkhc_abd8c5');
  }

  String _ticketSummary() {
    final ticket = _ticket ?? const <String, dynamic>{};
    final reason = ticket['reason']?.toString().trim() ?? '';
    if (reason.isNotEmpty) {
      return reason;
    }
    for (final message in _messages) {
      final isUserMessage =
          message['is_admin'] != true && message['is_bot'] != true;
      if (!isUserMessage) continue;
      final summary = message['summary']?.toString().trim() ?? '';
      if (summary.isNotEmpty) {
        return summary;
      }
    }
    return ticket['last_message']?.toString().trim() ?? '';
  }

  Widget _buildMetaRow(IconData icon, String label, String value) {
    if (value.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF64748B)),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: SLTheme.quicksand(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF334155),
                  height: 1.4,
                ),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketOverviewCard() {
    final ticket = _ticket;
    if (ticket == null) {
      return const SizedBox.shrink();
    }

    final status = ticket['status']?.toString().trim() ?? 'new';
    final context = _resolvedContext();
    final priority = ticket['priority']?.toString().trim() ?? '';
    final appVersion = [
      context['appVersion'] ?? '',
      if ((context['buildNumber'] ?? '').isNotEmpty)
        'build ${context['buildNumber']}',
    ].join(' ').trim();
    final deviceLabel = [
      context['deviceModel'] ?? '',
      context['devicePlatform'] ?? '',
      context['deviceOs'] ?? '',
    ].where((item) => item.isNotEmpty).join(' • ');

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _ticketCategory(),
                      style: SLTheme.quicksand(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _ticketSummary(),
                      style: SLTheme.quicksand(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF475569),
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _statusColor(status).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _statusLabel(status),
                  style: SLTheme.quicksand(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    color: _statusColor(status),
                  ),
                ),
              ),
            ],
          ),
          if (priority.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  L10nService()
                      .format('util_priority_label', {'priority': priority}),
                  style: SLTheme.quicksand(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFE65100),
                  ),
                ),
              ),
            ),
          _buildMetaRow(
            Icons.person_outline_rounded,
            L10nService().translate('util_ngigi_0c86fe'),
            [
              ticket['name']?.toString().trim() ?? '',
              context['email'] ?? '',
              if ((context['uid'] ?? '').isNotEmpty) 'UID ${context['uid']}',
            ].where((item) => item.isNotEmpty).join(' • '),
          ),
          _buildMetaRow(
            Icons.home_outlined,
            'House',
            context['houseId'] ?? '',
          ),
          _buildMetaRow(
            Icons.phone_android_rounded,
            L10nService().translate('util_thitb_bcf3a9'),
            deviceLabel,
          ),
          _buildMetaRow(
            Icons.system_update_alt_rounded,
            L10nService().translate('util_phinbnapp_d739a0'),
            appVersion,
          ),
          _buildMetaRow(
            Icons.route_outlined,
            L10nService().translate('util_mtlung_526929'),
            context['openedFrom'] ?? '',
          ),
        ],
      ),
    );
  }

  String _formatTime(int ts) {
    if (ts == 0) return '';
    return DateFormat('HH:mm dd/MM').format(
      DateTime.fromMillisecondsSinceEpoch(ts),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          L10nService()
              .format('util_chat_with_ticket', {'ticketId': widget.ticketId}),
          style: SLTheme.quicksand(
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          _buildTicketOverviewCard(),
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              padding: const EdgeInsets.all(15),
              itemBuilder: (_, index) {
                final message = _messages[index];
                final isAdmin =
                    message['is_admin'] == true || message['is_bot'] == true;
                final time = _formatTime((message['ts'] as num?)?.toInt() ?? 0);
                final sender = message['is_admin'] == true
                    ? 'Admin'
                    : message['is_bot'] == true
                        ? 'Bot'
                        : context.tr('util_ngidng_3bf886');

                return Align(
                  alignment:
                      isAdmin ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: isAdmin
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '$sender • $time',
                            style: SLTheme.quicksand(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.sizeOf(context).width * 0.75,
                          ),
                          decoration: BoxDecoration(
                            color: isAdmin
                                ? const Color(0xFF1E293B)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            message['text']?.toString() ?? '',
                            style: SLTheme.quicksand(
                              color: isAdmin ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w600,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    onSubmitted: (_) => _sendMessage(),
                    minLines: 1,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: context.tr('util_nhptinnhna_0d4f07'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _sendMessage,
                  icon: const Icon(
                    Icons.send_rounded,
                    color: Color(0xFF1E293B),
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
