import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/sl_theme.dart';
import '../../../models/single_match_models.dart';
import '../../../utils/services/l10n_service.dart';

enum MatchPeopleFilter { forYou, interests, nearby, video }

enum MatchConnectAction { audio, video, secretCode }

enum MatchPersonAction { message, audio, video }

/// Chỉ dữ liệu đã có bằng chứng; không suy ra online/đã gọi từ thời gian mở màn.
class MatchConversationPreview {
  const MatchConversationPreview({
    required this.houseId,
    required this.name,
    this.avatar = '',
    this.message = '',
    this.updatedAt = 0,
    this.unread = false,
  });

  final String houseId;
  final String name;
  final String avatar;
  final String message;
  final int updatedAt;
  final bool unread;
}

class MatchMessengerPalette {
  const MatchMessengerPalette(this.dark);
  factory MatchMessengerPalette.of(BuildContext context) =>
      MatchMessengerPalette(Theme.of(context).brightness == Brightness.dark);
  final bool dark;
  Color get background =>
      dark ? const Color(0xFF191923) : const Color(0xFFFFFCFE);
  Color get surface => dark ? const Color(0xFF252532) : Colors.white;
  Color get soft => dark ? const Color(0xFF302A3B) : const Color(0xFFF6EFFA);
  Color get ink => dark ? const Color(0xFFF5EFF8) : const Color(0xFF342C46);
  Color get muted => dark ? const Color(0xFFBDB2C9) : const Color(0xFF756C82);
  Color get accent => dark ? const Color(0xFFD5B8FF) : const Color(0xFF7752AC);
  Color get action => dark ? const Color(0xFFD5B8FF) : const Color(0xFF7950B3);
  Color get onAction => dark ? const Color(0xFF251A37) : Colors.white;
  Color get line => dark ? const Color(0xFF393543) : const Color(0xFFF0E9F2);
  Color tint(int index) => dark
      ? [
          const Color(0xFF382B42),
          const Color(0xFF293B3B),
          const Color(0xFF3B3345),
          const Color(0xFF40352D),
        ][index % 4]
      : [
          const Color(0xFFFBEAF3),
          const Color(0xFFEAF5EF),
          const Color(0xFFF0EBFF),
          const Color(0xFFFFF0DD),
        ][index % 4];
}

/// Widget trình bày độc lập Firebase để kiểm thử đúng các kích thước điện thoại.
class SingleMatchMessengerView extends StatefulWidget {
  const SingleMatchMessengerView({
    super.key,
    required this.name,
    required this.avatar,
    required this.conversations,
    required this.people,
    required this.calls,
    required this.onBack,
    required this.onSettings,
    required this.onRefresh,
    required this.onConversation,
    required this.onPerson,
    required this.onConnect,
    required this.onCallEntry,
    required this.onNearby,
    required this.onDisableNearby,
    this.nearbyPeople = const [],
    this.distanceBands = const {},
    this.myTags = const [],
    this.loading = false,
    this.busy = false,
    this.nearbyLoading = false,
    this.nearbyEnabled = false,
    this.inboxError,
    this.peopleError,
    this.nearbyError,
  });

  final String name;
  final String avatar;
  final List<MatchConversationPreview> conversations;
  final List<SingleMatchCandidate> people;
  final List<SingleMatchHistoryEntry> calls;
  final List<SingleMatchCandidate> nearbyPeople;
  final Map<String, String> distanceBands;
  final List<String> myTags;
  final bool loading;
  final bool busy;
  final bool nearbyLoading;
  final bool nearbyEnabled;
  final String? inboxError;
  final String? peopleError;
  final String? nearbyError;
  final VoidCallback onBack;
  final VoidCallback onSettings;
  final Future<void> Function() onRefresh;
  final ValueChanged<MatchConversationPreview> onConversation;
  final ValueChanged<SingleMatchCandidate> onPerson;
  final ValueChanged<MatchConnectAction> onConnect;
  final ValueChanged<SingleMatchHistoryEntry> onCallEntry;
  final VoidCallback onNearby;
  final VoidCallback onDisableNearby;

  @override
  State<SingleMatchMessengerView> createState() =>
      _SingleMatchMessengerViewState();
}

class _SingleMatchMessengerViewState extends State<SingleMatchMessengerView> {
  final _search = TextEditingController();
  int _tab = 0;
  MatchPeopleFilter _filter = MatchPeopleFilter.forYou;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _explore([MatchPeopleFilter filter = MatchPeopleFilter.forYou]) {
    setState(() {
      _tab = 1;
      _filter = filter;
      _search.clear();
    });
    if (filter == MatchPeopleFilter.nearby) widget.onNearby();
  }

  bool _matches(String value) =>
      value.toLowerCase().contains(_search.text.trim().toLowerCase());

  @override
  Widget build(BuildContext context) {
    final p = MatchMessengerPalette.of(context);
    final titles = [
      context.tr('chat_title'),
      context.tr('update_hub_explore'),
      context.tr('ui_single_call_b25622'),
    ];
    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 12, 4),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: widget.onBack,
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).backButtonTooltip,
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        icon: Icon(Icons.arrow_back_rounded, color: p.ink),
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          titles[_tab],
                          style: SLTheme.quicksand(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: p.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        onPressed: widget.onSettings,
                        tooltip: context.tr('settings'),
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        icon: MatchPersonAvatar(
                          name: widget.name,
                          url: widget.avatar,
                          size: 38,
                          color: p.soft,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: widget.onRefresh,
                    color: p.accent,
                    child: CustomScrollView(
                      key: ValueKey('match-messenger-page-$_tab'),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                          sliver: SliverToBoxAdapter(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_tab == 0) ...[
                                  Text(
                                    context.tr('sm_inbox_note'),
                                    style: SLTheme.quicksand(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: p.muted,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                TextField(
                                  key: const ValueKey('match-inbox-search'),
                                  controller: _search,
                                  onChanged: (_) => setState(() {}),
                                  style: SLTheme.quicksand(
                                    fontSize: 15,
                                    color: p.ink,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: context.tr('sm_search'),
                                    hintStyle: SLTheme.quicksand(
                                      fontSize: 14,
                                      color: p.muted,
                                    ),
                                    filled: true,
                                    fillColor: p.soft,
                                    prefixIcon: Icon(
                                      Icons.search_rounded,
                                      color: p.muted,
                                    ),
                                    suffixIcon: _search.text.isEmpty
                                        ? null
                                        : IconButton(
                                            tooltip: MaterialLocalizations.of(
                                              context,
                                            ).deleteButtonTooltip,
                                            onPressed: () =>
                                                setState(_search.clear),
                                            icon: Icon(
                                              Icons.close_rounded,
                                              color: p.muted,
                                            ),
                                          ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 15,
                                      horizontal: 16,
                                    ),
                                    border: OutlineInputBorder(
                                      borderSide: BorderSide.none,
                                      borderRadius: BorderRadius.circular(22),
                                    ),
                                  ),
                                ),
                                if (widget.busy) ...[
                                  const SizedBox(height: 12),
                                  _progress(context.tr('sm_finding')),
                                ],
                              ],
                            ),
                          ),
                        ),
                        if (_tab == 0) ..._inbox(p),
                        if (_tab == 1) ..._people(p),
                        if (_tab == 2) ..._calls(p),
                        const SliverToBoxAdapter(child: SizedBox(height: 28)),
                      ],
                    ),
                  ),
                ),
                _navigation(p, titles),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _inbox(MatchMessengerPalette p) {
    final conversations = widget.conversations
        .where((c) => _matches(c.name))
        .toList();
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final items = [
                (
                  Icons.person_add_alt_1_rounded,
                  context.tr('sm_find_people'),
                  () => _explore(),
                ),
                (
                  Icons.near_me_rounded,
                  context.tr('sm_nearby'),
                  () => _explore(MatchPeopleFilter.nearby),
                ),
                (
                  Icons.call_rounded,
                  context.tr('sm_random_call'),
                  () => widget.onConnect(MatchConnectAction.audio),
                ),
                (
                  Icons.videocam_rounded,
                  context.tr('p4_soul_video_call'),
                  () => widget.onConnect(MatchConnectAction.video),
                ),
              ];
              final columns = MediaQuery.textScalerOf(context).scale(14) > 21
                  ? 2
                  : 4;
              final width =
                  (constraints.maxWidth - (columns - 1) * 8) / columns;
              return Wrap(
                spacing: 8,
                runSpacing: 10,
                children: [
                  for (var i = 0; i < items.length; i++)
                    SizedBox(
                      width: width,
                      child: _QuickAction(
                        icon: items[i].$1,
                        label: items[i].$2,
                        color: p.tint(i),
                        onTap: widget.busy ? null : items[i].$3,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
      if (widget.people.isNotEmpty && _search.text.isEmpty) ...[
        SliverToBoxAdapter(
          child: _section(
            context.tr('sm_new_people'),
            action: context.tr('update_hub_explore'),
            onAction: () => _explore(),
          ),
        ),
        SliverToBoxAdapter(child: _newPeople(p)),
      ],
      SliverToBoxAdapter(child: _section(context.tr('p9_match_chat_history'))),
      if (widget.inboxError != null)
        _emptySliver(
          Icons.cloud_off_rounded,
          widget.inboxError!,
          context.tr('match_tili_13be6c'),
          widget.onRefresh,
        )
      else if (widget.loading && widget.conversations.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: _progress(context.tr('loading')),
          ),
        )
      else if (conversations.isEmpty)
        _emptySliver(
          Icons.forum_rounded,
          context.tr(
            _search.text.isEmpty
                ? 'p9_match_chat_empty_title'
                : 'sm_no_results',
          ),
          context.tr('sm_find_people'),
          () => _explore(),
          body: context.tr('sm_empty_note'),
          art: _search.text.isEmpty,
        )
      else
        SliverList.builder(
          itemCount: conversations.length,
          itemBuilder: (context, index) =>
              _conversation(conversations[index], p),
        ),
    ];
  }

  Widget _newPeople(MatchMessengerPalette p) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.fromLTRB(18, 6, 18, 22),
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AvatarShortcut(
            label: context.tr('sm_code'),
            icon: Icons.link_rounded,
            color: p.soft,
            onTap: () => widget.onConnect(MatchConnectAction.secretCode),
          ),
          for (final person in widget.people.take(6))
            _AvatarShortcut(
              label: person.displayName,
              person: person,
              color: p.tint(person.houseId.hashCode.abs() % 4),
              onTap: () => widget.onPerson(person),
            ),
        ],
      ),
    ),
  );

  Widget _conversation(
    MatchConversationPreview item,
    MatchMessengerPalette p, {
    VoidCallback? onTap,
  }) => Material(
    color: Colors.transparent,
    child: InkWell(
      key: ValueKey('match-conversation-${item.houseId}'),
      onTap: widget.busy ? null : (onTap ?? () => widget.onConversation(item)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MatchPersonAvatar(
              name: item.name,
              url: item.avatar,
              size: 58,
              color: p.tint(item.houseId.hashCode.abs() % 4),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: SLTheme.quicksand(
                      fontSize: 16,
                      fontWeight: item.unread
                          ? FontWeight.w900
                          : FontWeight.w800,
                      color: p.ink,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item.message.isEmpty
                        ? context.tr('messenger_start_conversation')
                        : item.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: SLTheme.quicksand(
                      fontSize: 13,
                      height: 1.4,
                      fontWeight: item.unread
                          ? FontWeight.w800
                          : FontWeight.w500,
                      color: item.unread ? p.ink : p.muted,
                    ),
                  ),
                ],
              ),
            ),
            if (item.updatedAt > 0 || item.unread) ...[
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (item.updatedAt > 0)
                    Text(
                      _time(item.updatedAt),
                      style: SLTheme.quicksand(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: p.muted,
                      ),
                    ),
                  if (item.unread)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Semantics(
                        label: context.tr('notifications_status_unread'),
                        child: Container(
                          key: ValueKey('match-unread-${item.houseId}'),
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: p.action,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    ),
  );

  List<Widget> _people(MatchMessengerPalette p) {
    final nearby = _filter == MatchPeopleFilter.nearby;
    final source = nearby ? widget.nearbyPeople : widget.people;
    final tags = widget.myTags.map((e) => e.toLowerCase()).toSet();
    final people = source.where((person) {
      if (!_matches('${person.displayName} ${person.tags.join(' ')}')) {
        return false;
      }
      if (_filter == MatchPeopleFilter.video && !person.allowVideoCalls) {
        return false;
      }
      if (_filter == MatchPeopleFilter.interests &&
          !person.tags.any((t) => tags.contains(t.toLowerCase()))) {
        return false;
      }
      return true;
    }).toList();
    final error = nearby ? widget.nearbyError : widget.peopleError;
    return [
      SliverToBoxAdapter(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Row(
            children: [
              for (final filter in MatchPeopleFilter.values)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: ChoiceChip(
                    key: ValueKey('match-filter-${filter.name}'),
                    selected: _filter == filter,
                    onSelected: (_) => _explore(filter),
                    showCheckmark: false,
                    selectedColor: p.action,
                    backgroundColor: p.surface,
                    side: BorderSide(color: p.line),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 12,
                    ),
                    label: Text(
                      context.tr(switch (filter) {
                        MatchPeopleFilter.forYou => 'sm_for_you',
                        MatchPeopleFilter.interests => 'sm_interests',
                        MatchPeopleFilter.nearby => 'sm_nearby',
                        MatchPeopleFilter.video => 'p4_soul_video_call',
                      }),
                      style: SLTheme.quicksand(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _filter == filter ? p.onAction : p.ink,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      if (nearby)
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: p.tint(1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.near_me_rounded, color: p.accent),
                const SizedBox(height: 10),
                Text(
                  context.tr(
                    widget.nearbyEnabled
                        ? 'sm_nearby_active'
                        : 'sm_nearby_note',
                  ),
                  style: SLTheme.quicksand(
                    fontSize: 14,
                    height: 1.5,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: widget.nearbyLoading
                      ? null
                      : (widget.nearbyEnabled
                            ? widget.onDisableNearby
                            : widget.onNearby),
                  icon: Icon(
                    widget.nearbyEnabled
                        ? Icons.location_off_rounded
                        : Icons.location_searching_rounded,
                  ),
                  label: Text(
                    context.tr(
                      widget.nearbyEnabled ? 'sm_nearby_off' : 'sm_nearby_on',
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    foregroundColor: p.ink,
                  ),
                ),
                if (!widget.nearbyEnabled && widget.nearbyError != null)
                  TextButton.icon(
                    onPressed: widget.nearbyLoading
                        ? null
                        : widget.onDisableNearby,
                    icon: const Icon(Icons.location_off_rounded),
                    label: Text(context.tr('sm_nearby_off')),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                  ),
              ],
            ),
          ),
        ),
      if (nearby && widget.nearbyLoading || !nearby && widget.loading)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _progress(context.tr('loading')),
          ),
        )
      else if (error != null)
        _emptySliver(
          Icons.cloud_off_rounded,
          error,
          context.tr('match_tili_13be6c'),
          nearby ? widget.onNearby : widget.onRefresh,
        )
      else if (people.isEmpty)
        _emptySliver(
          nearby ? Icons.near_me_outlined : Icons.person_search_rounded,
          context.tr('sm_no_results'),
          context.tr('settings'),
          widget.onSettings,
          body: context.tr(nearby ? 'sm_nearby_empty' : 'sm_people_empty'),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList.separated(
            itemCount: people.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _person(people[index], index, p),
          ),
        ),
      if (!nearby)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: TextButton.icon(
              onPressed: () => widget.onConnect(MatchConnectAction.secretCode),
              icon: const Icon(Icons.link_rounded),
              label: Text(context.tr('sm_code')),
            ),
          ),
        ),
    ];
  }

  Widget _person(
    SingleMatchCandidate person,
    int index,
    MatchMessengerPalette p,
  ) => Material(
    color: p.tint(index),
    borderRadius: BorderRadius.circular(24),
    child: InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: widget.busy ? null : () => widget.onPerson(person),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MatchPersonAvatar(
              name: person.displayName,
              url: person.avatarUrl,
              size: 66,
              color: p.surface,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: SLTheme.quicksand(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: p.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    person.intro.isNotEmpty ? person.intro : person.bio,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: SLTheme.quicksand(
                      fontSize: 13,
                      height: 1.4,
                      color: p.muted,
                    ),
                  ),
                  if (person.tags.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 9),
                      child: Text(
                        person.tags.take(3).map((t) => '#$t').join('  '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: SLTheme.quicksand(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: p.accent,
                        ),
                      ),
                    ),
                  if (widget.distanceBands[person.houseId]
                      case final String band)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        context.tr(switch (band) {
                          'under25' => 'sm_distance_under25',
                          '25to50' => 'sm_distance_25to50',
                          _ => 'sm_distance_50to100',
                        }),
                        style: SLTheme.quicksand(fontSize: 12, color: p.muted),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    context.tr('p9_match_chat_message'),
                    style: SLTheme.quicksand(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: p.accent,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Icon(Icons.chevron_right_rounded, color: p.muted),
            ),
          ],
        ),
      ),
    ),
  );

  List<Widget> _calls(MatchMessengerPalette p) {
    final calls = widget.calls
        .where((call) => call.isCall && _matches(call.peerName))
        .toList();
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('sm_call_note'),
                style: SLTheme.quicksand(
                  fontSize: 14,
                  height: 1.5,
                  color: p.muted,
                ),
              ),
              const SizedBox(height: 16),
              _callAction(p, false),
              const SizedBox(height: 10),
              _callAction(p, true),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => _explore(MatchPeopleFilter.interests),
                icon: const Icon(Icons.interests_rounded),
                label: Text(context.tr('sm_interests')),
              ),
            ],
          ),
        ),
      ),
      SliverToBoxAdapter(child: _section(context.tr('home_gny_a3ae09'))),
      if (calls.isEmpty)
        _emptySliver(
          Icons.call_outlined,
          context.tr('sm_calls_empty'),
          context.tr('sm_find_people'),
          () => _explore(),
        )
      else
        SliverList.builder(
          itemCount: calls.length,
          itemBuilder: (context, index) {
            final call = calls[index];
            return _conversation(
              MatchConversationPreview(
                houseId: call.peerHouseId,
                name: call.peerName,
                avatar: call.peerAvatarUrl,
                updatedAt: call.startedAt,
                message: context.tr(
                  call.action == 'video_call'
                      ? 'sm_video_invite'
                      : 'sm_audio_invite',
                ),
              ),
              p,
              onTap: () => widget.onCallEntry(call),
            );
          },
        ),
    ];
  }

  Widget _callAction(MatchMessengerPalette p, bool video) => Material(
    color: p.tint(video ? 2 : 0),
    borderRadius: BorderRadius.circular(24),
    child: InkWell(
      onTap: widget.busy
          ? null
          : () => widget.onConnect(
              video ? MatchConnectAction.video : MatchConnectAction.audio,
            ),
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                video ? Icons.videocam_rounded : Icons.call_rounded,
                color: p.accent,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr(video ? 'p4_soul_video_call' : 'sm_random_call'),
                    style: SLTheme.quicksand(
                      fontSize: 16,
                      color: p.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.tr('sm_interests'),
                    style: SLTheme.quicksand(fontSize: 13, color: p.muted),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_rounded, color: p.accent),
          ],
        ),
      ),
    ),
  );

  Widget _navigation(MatchMessengerPalette p, List<String> labels) => Container(
    decoration: BoxDecoration(
      color: p.surface,
      border: Border(top: BorderSide(color: p.line)),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < 3; i++)
                Expanded(
                  child: Semantics(
                    selected: _tab == i,
                    child: TextButton(
                      key: ValueKey('match-messenger-nav-$i'),
                      onPressed: () => setState(() {
                        _tab = i;
                        _search.clear();
                      }),
                      style: TextButton.styleFrom(
                        foregroundColor: _tab == i ? p.accent : p.muted,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 8,
                        ),
                        minimumSize: const Size(48, 62),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: _tab == i ? p.soft : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              [
                                Icons.chat_bubble_rounded,
                                Icons.people_alt_rounded,
                                Icons.call_rounded,
                              ][i],
                              size: 23,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            labels[i],
                            textAlign: TextAlign.center,
                            style: SLTheme.quicksand(
                              fontSize: 12,
                              fontWeight: _tab == i
                                  ? FontWeight.w900
                                  : FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _section(String title, {String? action, VoidCallback? onAction}) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: SLTheme.quicksand(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: MatchMessengerPalette.of(context).ink,
                ),
              ),
            ),
            if (action != null)
              TextButton(
                onPressed: onAction,
                child: Text(
                  action,
                  style: SLTheme.quicksand(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
      );

  Widget _emptySliver(
    IconData icon,
    String title,
    String action,
    VoidCallback onTap, {
    String? body,
    bool art = false,
  }) {
    final p = MatchMessengerPalette.of(context);
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(30, 20, 30, 24),
        child: Column(
          children: [
            if (art)
              const SizedBox(
                width: 160,
                height: 104,
                child: CustomPaint(painter: _HelloBubbles()),
              )
            else
              Padding(
                padding: const EdgeInsets.all(12),
                child: Icon(icon, size: 34, color: p.accent),
              ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: p.ink,
              ),
            ),
            if (body != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  body,
                  textAlign: TextAlign.center,
                  style: SLTheme.quicksand(
                    fontSize: 13,
                    height: 1.5,
                    color: p.muted,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: p.action,
                foregroundColor: p.onAction,
                minimumSize: const Size(48, 48),
              ),
              child: Text(action),
            ),
          ],
        ),
      ),
    );
  }

  Widget _progress(String label) => Semantics(
    liveRegion: true,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (!MediaQuery.disableAnimationsOf(context)) ...[
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: MatchMessengerPalette.of(context).accent,
            ),
          ),
          const SizedBox(width: 12),
        ],
        Flexible(
          child: Text(
            label,
            style: SLTheme.quicksand(
              fontSize: 13,
              color: MatchMessengerPalette.of(context).muted,
            ),
          ),
        ),
      ],
    ),
  );

  String _time(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return MaterialLocalizations.of(context).formatTimeOfDay(
        TimeOfDay.fromDateTime(dt),
        alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
      );
    }
    return MaterialLocalizations.of(context).formatShortMonthDay(dt);
  }
}

class MatchPersonAvatar extends StatelessWidget {
  const MatchPersonAvatar({
    super.key,
    required this.name,
    required this.url,
    required this.size,
    required this.color,
  });
  final String name;
  final String url;
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final fallback = Center(
      child: Text(
        name.trim().characters.take(1).toString(),
        style: SLTheme.quicksand(
          fontSize: size * .32,
          fontWeight: FontWeight.w900,
          color: MatchMessengerPalette.of(context).accent,
        ),
      ),
    );
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: ClipOval(
          child: ColoredBox(
            color: color,
            child: url.trim().isEmpty
                ? fallback
                : CachedNetworkImage(
                    imageUrl: url,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    fadeInDuration: Duration.zero,
                    fadeOutDuration: Duration.zero,
                    placeholder: (_, _) => ColoredBox(color: color),
                    errorWidget: (_, _, _) => fallback,
                  ),
          ),
        ),
      ),
    );
  }
}

/// Xem người thật và xác nhận hành động trước khi xin quyền camera/micro.
class MatchPersonSheet extends StatelessWidget {
  const MatchPersonSheet({
    super.key,
    required this.person,
    required this.preferences,
    this.preferredVideo,
  });

  final SingleMatchCandidate person;
  final SingleMatchPreferences preferences;
  final bool? preferredVideo;

  @override
  Widget build(BuildContext context) {
    final p = MatchMessengerPalette.of(context);
    final actions = [
      MatchPersonAction.message,
      if (person.allowAudioCalls && preferences.allowAudioCalls)
        MatchPersonAction.audio,
      if (person.allowVideoCalls && preferences.allowVideoCalls)
        MatchPersonAction.video,
    ];
    final preferred = switch (preferredVideo) {
      true => MatchPersonAction.video,
      false => MatchPersonAction.audio,
      null => MatchPersonAction.message,
    };
    final primary = actions.contains(preferred)
        ? preferred
        : MatchPersonAction.message;

    Widget button(MatchPersonAction action, {bool filled = false}) {
      final label = context.tr(switch (action) {
        MatchPersonAction.message => 'p9_match_chat_message',
        MatchPersonAction.audio => 'match_githoi_ad3e35',
        MatchPersonAction.video => 'p4_soul_video_call',
      });
      final icon = Icon(switch (action) {
        MatchPersonAction.message => Icons.chat_bubble_rounded,
        MatchPersonAction.audio => Icons.call_rounded,
        MatchPersonAction.video => Icons.videocam_rounded,
      });
      final key = ValueKey('match-person-action-${action.name}');
      void select() => Navigator.pop(context, action);
      return filled
          ? FilledButton.icon(
              key: key,
              onPressed: select,
              style: FilledButton.styleFrom(
                backgroundColor: p.action,
                foregroundColor: p.onAction,
                minimumSize: const Size(48, 52),
              ),
              icon: icon,
              label: Text(label, textAlign: TextAlign.center),
            )
          : OutlinedButton.icon(
              key: key,
              onPressed: select,
              style: OutlinedButton.styleFrom(
                foregroundColor: p.ink,
                minimumSize: const Size(48, 50),
              ),
              icon: icon,
              label: Text(label, textAlign: TextAlign.center),
            );
    }

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          4,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MatchPersonAvatar(
              name: person.displayName,
              url: person.avatarUrl,
              size: 90,
              color: p.soft,
            ),
            const SizedBox(height: 16),
            Text(
              person.displayName,
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: p.ink,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              person.intro.isNotEmpty ? person.intro : person.bio,
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                fontSize: 14,
                height: 1.5,
                color: p.muted,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag in person.tags)
                  Chip(
                    label: Text(tag),
                    backgroundColor: p.soft,
                    side: BorderSide.none,
                  ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: button(primary, filled: true),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                for (final action in actions)
                  if (action != primary) button(action),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              context.tr('sm_connect_note'),
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                fontSize: 12,
                height: 1.5,
                color: p.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onTap,
    style: TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      minimumSize: const Size(48, 48),
      foregroundColor: MatchMessengerPalette.of(context).ink,
    ),
    child: Column(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            icon,
            color: MatchMessengerPalette.of(context).accent,
            size: 25,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: SLTheme.quicksand(
            fontSize: 11,
            height: 1.35,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _AvatarShortcut extends StatelessWidget {
  const _AvatarShortcut({
    required this.label,
    required this.color,
    required this.onTap,
    this.person,
    this.icon,
  });
  final String label;
  final Color color;
  final VoidCallback onTap;
  final SingleMatchCandidate? person;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 82,
    child: TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: MatchMessengerPalette.of(context).line,
                width: 2,
              ),
            ),
            child: person == null
                ? Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: MatchMessengerPalette.of(context).accent,
                    ),
                  )
                : MatchPersonAvatar(
                    name: label,
                    url: person!.avatarUrl,
                    size: 54,
                    color: color,
                  ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: SLTheme.quicksand(
              fontSize: 12,
              color: MatchMessengerPalette.of(context).ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}

class _HelloBubbles extends CustomPainter {
  const _HelloBubbles();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 160, size.height / 104);
    final paint = Paint();
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(7, 8, 88, 66),
        const Radius.circular(25),
      ),
      paint..color = const Color(0xFFE9DDF9),
    );
    canvas.drawCircle(const Offset(20, 78), 7, paint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(65, 36, 88, 60),
        const Radius.circular(24),
      ),
      paint..color = const Color(0xFFF8DFE9),
    );
    for (final origin in [const Offset(34, 36), const Offset(92, 61)]) {
      paint.color = const Color(0xFF74537D);
      canvas.drawCircle(origin, 2.3, paint);
      canvas.drawCircle(origin + const Offset(18, 0), 2.3, paint);
      canvas.drawArc(
        Rect.fromLTWH(origin.dx + 5, origin.dy + 5, 9, 7),
        0,
        3.14,
        false,
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
      paint.style = PaintingStyle.fill;
    }
    canvas.drawCircle(
      const Offset(136, 17),
      4,
      paint..color = const Color(0xFFE7BD71),
    );
    canvas.drawCircle(const Offset(119, 8), 2, paint);
  }

  @override
  bool shouldRepaint(covariant _HelloBubbles oldDelegate) => false;
}
