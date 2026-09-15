import 'package:flutter/material.dart';

import '../../../../core/sl_theme.dart';
import '../../../../utils/services/l10n_service.dart';

class UpdateHubDocument {
  const UpdateHubDocument(this.key, this.asset, this.icon);
  final String key;
  final String asset;
  final IconData icon;
}

const updateHubDocuments = [
  UpdateHubDocument(
    'update_hub_guide',
    'assets/docs/huong_dan.html',
    Icons.menu_book_rounded,
  ),
  UpdateHubDocument(
    'update_hub_setup',
    'assets/docs/huong_dan_cai_dat_lan_dau.html',
    Icons.rocket_launch_outlined,
  ),
  UpdateHubDocument(
    'update_hub_about',
    'assets/docs/about.html',
    Icons.favorite_border_rounded,
  ),
  UpdateHubDocument(
    'update_hub_privacy',
    'assets/docs/privacy.html',
    Icons.shield_outlined,
  ),
  UpdateHubDocument(
    'update_hub_terms',
    'assets/docs/terms.html',
    Icons.description_outlined,
  ),
  UpdateHubDocument(
    'update_hub_cookies',
    'assets/docs/cookie-policy.html',
    Icons.cookie_outlined,
  ),
  UpdateHubDocument(
    'update_hub_delete',
    'assets/docs/delete_account.html',
    Icons.manage_accounts_outlined,
  ),
];

/// Giao diện thuần: không gọi Firebase trong lúc dựng các khung nội dung.
class UpdateHubBody extends StatefulWidget {
  const UpdateHubBody({
    super.key,
    required this.version,
    required this.onSettings,
    required this.onDocument,
    required this.onSupport,
    required this.onEmail,
    required this.onDeleteRequest,
    required this.onNews,
    required this.feedback,
    this.onWebsite,
  });
  final String? version;
  final VoidCallback onSettings;
  final ValueChanged<UpdateHubDocument> onDocument;
  final VoidCallback onSupport;
  final VoidCallback onEmail;
  final VoidCallback onDeleteRequest;
  final VoidCallback onNews;
  final VoidCallback? onWebsite;
  final Widget feedback;

  @override
  State<UpdateHubBody> createState() => _UpdateHubBodyState();
}

class _UpdateHubBodyState extends State<UpdateHubBody> {
  int _section = 0;
  bool get _dark => Theme.of(context).brightness == Brightness.dark;
  Color get _ink => _dark ? const Color(0xFFF4EAF1) : const Color(0xFF3B303D);
  Color get _muted => _dark ? const Color(0xFFC8B9C7) : const Color(0xFF7A6B7C);
  Color get _paper => _dark ? const Color(0xFF302A38) : const Color(0xFFFFFDFC);
  Color get _accent =>
      _dark ? const Color(0xFFF6A2BE) : const Color(0xFFA83F65);
  Color get _line => _dark ? const Color(0xFF504355) : const Color(0xFFECE1E8);

  TextStyle _type(double size, {bool strong = false, Color? color}) =>
      SLTheme.quicksand(
        fontSize: size,
        height: 1.4,
        fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
        color: color ?? _ink,
      );

  @override
  Widget build(BuildContext context) {
    L10nScope.of(context);
    return DecoratedBox(
      key: const ValueKey('update-hub-backdrop'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _dark
              ? [const Color(0xFF231F2B), const Color(0xFF2D2433)]
              : [
                  const Color(0xFFFBF4EB),
                  const Color(0xFFF6EDF5),
                  const Color(0xFFEEEAF8),
                ],
        ),
      ),
      child: CustomPaint(
        painter: _NotebookBackground(_line),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 16, 18, 14),
                    child: Row(
                      children: [
                        _stamp(Icons.auto_awesome_outlined, _accent),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tr('update_hub_title'),
                                style: _type(22, strong: true),
                              ),
                              Text(
                                context.tr('update_hub_subtitle'),
                                style: _type(11, color: _muted),
                              ),
                            ],
                          ),
                        ),
                        IconButton.filledTonal(
                          onPressed: widget.onSettings,
                          tooltip: context.tr('update_hub_settings'),
                          style: IconButton.styleFrom(
                            backgroundColor: _paper,
                            foregroundColor: _ink,
                          ),
                          icon: const Icon(Icons.tune_rounded, size: 22),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 956),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: _paper,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: _line),
                      ),
                      child: Row(
                        children: [
                          for (var i = 0; i < 3; i++)
                            Expanded(
                              child: Semantics(
                                selected: _section == i,
                                child: TextButton(
                                  key: ValueKey('update-section-$i'),
                                  onPressed: () => setState(() => _section = i),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 12,
                                    ),
                                    backgroundColor: _section == i
                                        ? _accent
                                        : Colors.transparent,
                                    foregroundColor: _section == i
                                        ? (_dark
                                              ? const Color(0xFF302332)
                                              : Colors.white)
                                        : _muted,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(17),
                                    ),
                                    textStyle: _type(12, strong: true),
                                  ),
                                  child: Text(
                                    context.tr(
                                      [
                                        'update_hub_explore',
                                        'update_hub_documents',
                                        'update_hub_support',
                                      ][i],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: IndexedStack(
                  index: _section,
                  children: [
                    _scroll('explore', [
                      _hero(),
                      const SizedBox(height: 24),
                      _heading(context.tr('update_hub_shortcuts')),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = constraints.maxWidth >= 650 ? 4 : 2;
                          final width =
                              (constraints.maxWidth - (columns - 1) * 12) /
                              columns;
                          final cards = <Widget>[
                            SizedBox(
                              width: width,
                              child: _shortcut(
                                Icons.menu_book_rounded,
                                'update_hub_guide',
                                'update_hub_guide_note',
                                const Color(0xFF8668AF),
                                () => widget.onDocument(updateHubDocuments[0]),
                              ),
                            ),
                            SizedBox(
                              width: width,
                              child: _shortcut(
                                Icons.support_agent_rounded,
                                'update_hub_chat',
                                'update_hub_chat_note',
                                const Color(0xFF458880),
                                widget.onSupport,
                              ),
                            ),
                            SizedBox(
                              width: width,
                              child: _shortcut(
                                Icons.shield_outlined,
                                'update_hub_privacy',
                                'update_hub_privacy_note',
                                const Color(0xFFB16A46),
                                () => widget.onDocument(updateHubDocuments[3]),
                              ),
                            ),
                            SizedBox(
                              width: width,
                              child: _shortcut(
                                Icons.edit_note_rounded,
                                'update_hub_feedback',
                                'update_hub_feedback_note',
                                const Color(0xFFA83F65),
                                () => setState(() => _section = 2),
                              ),
                            ),
                          ];
                          return Column(
                            children: [
                              for (
                                var start = 0;
                                start < cards.length;
                                start += columns
                              )
                                Padding(
                                  padding: EdgeInsets.only(
                                    top: start == 0 ? 0 : 12,
                                  ),
                                  child: IntrinsicHeight(
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        for (
                                          var i = start;
                                          i < start + columns;
                                          i++
                                        ) ...[
                                          if (i > start)
                                            const SizedBox(width: 12),
                                          cards[i],
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      _heading(
                        context.tr('update_hub_recent'),
                        action: TextButton(
                          onPressed: widget.onNews,
                          child: Text(
                            context.tr('update_hub_details'),
                            style: _type(12, strong: true, color: _accent),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _sheet(
                        child: Column(
                          children: [
                            _summary(
                              Icons.dashboard_customize_outlined,
                              'update_hub_change_layout',
                              'update_hub_change_layout_note',
                            ),
                            Divider(height: 28, color: _line),
                            _summary(
                              Icons.favorite_outline_rounded,
                              'update_hub_change_style',
                              'update_hub_change_style_note',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _sheet(
                        child: Theme(
                          data: Theme.of(
                            context,
                          ).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            childrenPadding: const EdgeInsets.only(top: 12),
                            iconColor: _muted,
                            collapsedIconColor: _muted,
                            title: Text(
                              context.tr('update_hub_features'),
                              style: _type(15, strong: true),
                            ),
                            subtitle: Text(
                              context.tr('update_hub_features_hint'),
                              style: _type(12, color: _muted),
                            ),
                            children: [
                              _summary(
                                Icons.photo_album_outlined,
                                'update_hub_memories',
                                'update_hub_memories_note',
                              ),
                              const SizedBox(height: 20),
                              _summary(
                                Icons.link_rounded,
                                'update_hub_pairing',
                                'update_hub_pairing_note',
                              ),
                              const SizedBox(height: 20),
                              _summary(
                                Icons.widgets_outlined,
                                'update_hub_tools',
                                'update_hub_tools_note',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ]),
                    _scroll('documents', [
                      _sectionIntro(
                        Icons.menu_book_rounded,
                        'update_hub_documents',
                        'update_hub_documents_note',
                      ),
                      const SizedBox(height: 20),
                      _sheet(
                        child: Column(
                          children: [
                            for (
                              var i = 0;
                              i < updateHubDocuments.length;
                              i++
                            ) ...[
                              if (i > 0) Divider(height: 16, color: _line),
                              _link(
                                updateHubDocuments[i].icon,
                                updateHubDocuments[i].key,
                                () => widget.onDocument(updateHubDocuments[i]),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _sheet(
                        child: _link(
                          Icons.open_in_new_rounded,
                          'update_hub_delete_request',
                          widget.onDeleteRequest,
                        ),
                      ),
                    ]),
                    _scroll('support', [
                      _sectionIntro(
                        Icons.mark_email_unread_outlined,
                        'update_hub_here',
                        'update_hub_here_note',
                      ),
                      const SizedBox(height: 20),
                      _sheet(
                        child: Column(
                          children: [
                            _link(
                              Icons.chat_bubble_outline_rounded,
                              'update_hub_chat',
                              widget.onSupport,
                            ),
                            Divider(height: 16, color: _line),
                            _link(
                              Icons.alternate_email_rounded,
                              'update_hub_email',
                              widget.onEmail,
                            ),
                            if (widget.onWebsite != null) ...[
                              Divider(height: 16, color: _line),
                              _link(
                                Icons.language_rounded,
                                'update_hub_website',
                                widget.onWebsite!,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _heading(context.tr('update_hub_feedback')),
                      const SizedBox(height: 12),
                      _sheet(child: widget.feedback),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scroll(String id, List<Widget> children) => ListView(
    key: PageStorageKey('update-$id'),
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 132),
    children: [
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 956),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...children,
              const SizedBox(height: 28),
              Text(
                widget.version == null
                    ? 'SoulLocket'
                    : 'SoulLocket · ${widget.version}',
                textAlign: TextAlign.center,
                style: _type(11, color: _muted),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _hero() => Container(
    key: const ValueKey('update-hub-hero'),
    decoration: BoxDecoration(
      color: _dark ? const Color(0xFF463448) : const Color(0xFFF3DFE5),
      borderRadius: BorderRadius.circular(30),
      boxShadow: [
        BoxShadow(
          color: _accent.withValues(alpha: .09),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    padding: const EdgeInsets.only(bottom: 7),
    child: Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _dark
              ? [const Color(0xFF3F3347), const Color(0xFF302B3F)]
              : [const Color(0xFFFFFAF3), const Color(0xFFF8EAF2)],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _paper, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr('update_hub_eyebrow'),
                  style: _type(11, strong: true, color: _accent),
                ),
              ),
              const Icon(
                Icons.auto_awesome,
                size: 18,
                color: Color(0xFFBE8D50),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final showArt =
                  constraints.maxWidth >= 290 &&
                  MediaQuery.textScalerOf(context).scale(1) < 1.5;
              final copy = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('update_hub_welcome'),
                    style: _type(25, strong: true),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    context.tr('update_hub_welcome_note'),
                    style: _type(12, color: _muted),
                  ),
                ],
              );
              return Row(
                children: [
                  Expanded(child: copy),
                  if (showArt) ...[
                    const SizedBox(width: 12),
                    ExcludeSemantics(
                      child: SizedBox(
                        width: 102,
                        height: 132,
                        child: _LetterArtwork(dark: _dark),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Semantics(
            button: true,
            child: Material(
              color: const Color(0xFFA83F65),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: () => widget.onDocument(updateHubDocuments[0]),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 15,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.menu_book_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          context.tr('update_hub_open_guide'),
                          style: SLTheme.quicksand(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _sheet({required Widget child}) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: _paper,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: _line),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .025),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Material(type: MaterialType.transparency, child: child),
  );

  Widget _heading(String label, {Widget? action}) => Row(
    children: [
      Container(
        width: 4,
        height: 18,
        decoration: BoxDecoration(
          color: _accent,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(child: Text(label, style: _type(16, strong: true))),
      ?action,
    ],
  );

  Widget _stamp(IconData icon, Color color) => Container(
    width: 44,
    height: 44,
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: color.withValues(alpha: .16)),
    ),
    child: Icon(icon, color: _dark ? _accent : color, size: 23),
  );

  Widget _shortcut(
    IconData icon,
    String title,
    String note,
    Color color,
    VoidCallback onTap,
  ) => Material(
    color: _paper,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(23),
      side: BorderSide(color: _line),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(23),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _stamp(icon, color),
                const Spacer(),
                Icon(Icons.north_east_rounded, size: 16, color: _muted),
              ],
            ),
            const SizedBox(height: 13),
            Text(context.tr(title), style: _type(14, strong: true)),
            const SizedBox(height: 4),
            Text(context.tr(note), style: _type(11, color: _muted)),
          ],
        ),
      ),
    ),
  );

  Widget _summary(IconData icon, String title, String note) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _stamp(icon, _accent),
      const SizedBox(width: 13),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr(title), style: _type(13, strong: true)),
            const SizedBox(height: 5),
            Text(context.tr(note), style: _type(12, color: _muted)),
          ],
        ),
      ),
    ],
  );

  Widget _sectionIntro(IconData icon, String title, String note) =>
      _sheet(child: _summary(icon, title, note));

  Widget _link(IconData icon, String label, VoidCallback onTap) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 22, color: _accent),
            const SizedBox(width: 14),
            Expanded(
              child: Text(context.tr(label), style: _type(13, strong: true)),
            ),
            Icon(Icons.chevron_right_rounded, color: _muted, size: 20),
          ],
        ),
      ),
    ),
  );
}

/// Thiệp và con dấu vẽ bằng widget: sắc nét mọi DPI, không thêm ảnh nặng vào APK.
class _LetterArtwork extends StatelessWidget {
  const _LetterArtwork({required this.dark});
  final bool dark;
  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      Transform.rotate(
        angle: -.15,
        child: Container(
          width: 84,
          height: 108,
          decoration: BoxDecoration(
            color: const Color(0xFFDCD1ED),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
      ),
      Transform.rotate(
        angle: .09,
        child: Container(
          width: 84,
          height: 108,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFAEF),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F7A4961),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(width: 34, height: 12, color: const Color(0xFFEBC7D4)),
              const SizedBox(height: 10),
              const Icon(
                Icons.favorite_rounded,
                size: 30,
                color: Color(0xFFB6577B),
              ),
              const SizedBox(height: 9),
              Container(height: 3, color: const Color(0xFFE4D7DC)),
              const SizedBox(height: 5),
              Container(height: 3, width: 28, color: const Color(0xFFE4D7DC)),
            ],
          ),
        ),
      ),
      const Positioned(
        right: 0,
        bottom: 0,
        child: Icon(Icons.auto_awesome, color: Color(0xFFBF904E), size: 24),
      ),
    ],
  );
}

class _NotebookBackground extends CustomPainter {
  const _NotebookBackground(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: .5);
    for (double x = 12; x < size.width; x += 24) {
      for (double y = 10; y < size.height; y += 24) {
        canvas.drawCircle(Offset(x, y), .8, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_NotebookBackground oldDelegate) =>
      oldDelegate.color != color;
}
