import 'dart:async';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/sl_theme.dart';
import '../../../utils/services/l10n_service.dart';
import 'models/tarot_models.dart';
import 'painters/tarot_painters.dart';

class TarotScreen extends StatefulWidget {
  final String houseId;
  final String relationshipMode;
  final String myName;
  const TarotScreen({
    super.key,
    required this.houseId,
    required this.relationshipMode,
    required this.myName,
  });
  @override
  State<TarotScreen> createState() => _TarotScreenState();
}

enum _TarotTab { read, library, journal }

class _TarotScreenState extends State<TarotScreen> {
  bool get isDark => Theme.of(context).brightness == Brightness.dark;
  Color get ink => isDark ? const Color(0xFFF4EDDF) : const Color(0xFF30283D);
  Color get muted => isDark ? const Color(0xFFB7ADC4) : const Color(0xFF80748B);
  Color get plum => isDark ? const Color(0xFFC4A9E8) : const Color(0xFF775A9A);
  Color get dark => const Color(0xFF34253F);
  Color get cream => isDark ? const Color(0xFF201B27) : const Color(0xFFF8F5EF);
  Color get surface => isDark ? const Color(0xFF2D2537) : Colors.white;
  Color get onPlum => isDark ? dark : Colors.white;
  Color get gold => const Color(0xFFD5AA66);
  Color get rose => const Color(0xFFDFA5A5);
  bool get reduceMotion => MediaQuery.disableAnimationsOf(context);
  final l10n = L10nService();
  final question = TextEditingController();
  final search = TextEditingController();
  final note = TextEditingController();
  final random = Random();
  _TarotTab tab = _TarotTab.read;
  int phase = 0, promptIndex = 0;
  List<TarotCard> deck = [];
  final chosen = <int>{};
  String sessionId = '';
  DateTime sessionDate = DateTime.now();
  String? savedSessionId;
  StreamSubscription<User?>? authSubscription;
  bool scopeLost = false;
  int journalRevision = 0;
  String topic = 'self', filter = 'all', uid = '';
  TarotSpread spread = tarotSpreads.first;
  List<TarotDraw> draws = [];
  List<TarotSession> journal = [];
  bool busy = false, saving = false;
  String tr(String key) => l10n.translate('tarot2_$key');
  String fmt(String key, Map<String, Object?> values) =>
      l10n.format('tarot2_$key', values);

  @override
  void initState() {
    super.initState();
    l10n.addListener(refreshLocale);
    loadJournal();
    try {
      authSubscription = FirebaseAuth.instance.authStateChanges().listen((
        user,
      ) {
        if (uid.isNotEmpty && user?.uid != uid && mounted) {
          setState(() {
            journalRevision++;
            scopeLost = true;
            journal = [];
          });
        }
      });
    } catch (_) {}
  }

  void refreshLocale() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    authSubscription?.cancel();
    l10n.removeListener(refreshLocale);
    question.dispose();
    search.dispose();
    note.dispose();
    super.dispose();
  }

  String get authUid {
    try {
      return FirebaseAuth.instance.currentUser?.uid ?? '';
    } catch (_) {
      return '';
    }
  }

  bool sameScope(String expectedUid, String expectedHouse) =>
      mounted &&
      !scopeLost &&
      uid == expectedUid &&
      authUid == expectedUid &&
      widget.houseId == expectedHouse;

  @override
  void didUpdateWidget(covariant TarotScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.houseId != widget.houseId) {
      journalRevision++;
      journal = [];
      uid = '';
      scopeLost = false;
      question.clear();
      search.clear();
      setup();
      loadJournal();
    }
  }

  Future<void> loadJournal() async {
    final current = authUid;
    final house = widget.houseId;
    final revision = ++journalRevision;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted ||
          revision != journalRevision ||
          current != authUid ||
          house != widget.houseId) {
        return;
      }
      final saved = TarotJournalStore.load(prefs, current, house);
      setState(() {
        uid = current;
        journal = saved;
      });
    } catch (_) {
      if (mounted && revision == journalRevision && current == authUid) {
        setState(() => uid = current);
      }
    }
  }

  Future<void> start([TarotCard? daily]) async {
    if (busy || saving) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => busy = true);
    await Future<void>.delayed(Duration(milliseconds: reduceMotion ? 0 : 250));
    if (!mounted) return;
    setState(() {
      sessionDate = DateTime.now();
      sessionId = sessionDate.microsecondsSinceEpoch.toString();
      savedSessionId = null;
      note.clear();
      chosen.clear();
      deck = shuffledTarotDeck(random);
      draws = [];
      if (daily != null) {
        spread = tarotSpreads.first;
        draws = [TarotDraw(daily, reversed: false)];
        phase = 2;
      } else {
        phase = 1;
      }
      busy = false;
    });
  }

  void choose(int index) {
    if (chosen.contains(index) || draws.length >= spread.slots.length) return;
    setState(() {
      chosen.add(index);
      draws = [
        ...draws,
        TarotDraw(deck[index], reversed: random.nextInt(4) == 0),
      ];
    });
  }

  void shuffle() {
    setState(() {
      deck = shuffledTarotDeck(random);
      chosen.clear();
      draws = [];
    });
  }

  void reveal(int index) {
    if (index >= draws.length || draws[index].revealed) return;
    final copy = List<TarotDraw>.of(draws);
    copy[index] = copy[index].reveal();
    setState(() => draws = copy);
  }

  void revealAll() {
    if (draws.isEmpty || allRevealed) return;
    setState(() => draws = [for (final draw in draws) draw.reveal()]);
  }
  bool get allRevealed =>
      draws.isNotEmpty && draws.every((draw) => draw.revealed);
  void setup() => setState(() {
    phase = 0;
    draws = [];
    chosen.clear();
    deck = [];
    savedSessionId = null;
    note.clear();
  });
  void snack(String value) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          value,
          style: SLTheme.quicksand(fontWeight: FontWeight.w700),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark,
      ),
    );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: cream,
    appBar: AppBar(
      backgroundColor: cream,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.maybePop(context),
        icon: Icon(Icons.arrow_back_rounded, color: ink),
      ),
      title: Text(
        tr('title'),
        style: SLTheme.quicksand(
          color: ink,
          fontSize: 19,
          fontWeight: FontWeight.w900,
        ),
      ),
      actions: [
        IconButton(
          tooltip: tr('guide'),
          onPressed: showGuide,
          icon: Icon(Icons.auto_awesome_outlined, color: plum),
        ),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              child: KeyedSubtree(
                key: ValueKey(tab.name + phase.toString()),
                child: body(),
              ),
            ),
          ),
          if (tab == _TarotTab.read && phase == 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
              child: startButton(),
            ),
          bottomNav(),
        ],
      ),
    ),
  );
  Widget body() {
    if (tab == _TarotTab.library) return library();
    if (tab == _TarotTab.journal) return journalView();
    return phase == 0
        ? setupView()
        : phase == 1
        ? drawView()
        : resultView();
  }

  Widget bottomNav() => Container(
    decoration: BoxDecoration(
      color: cream,
      border: Border(top: BorderSide(color: ink.withValues(alpha: .08))),
    ),
    padding: const EdgeInsets.fromLTRB(12, 7, 12, 9),
    child: Row(
      children: [
        nav(_TarotTab.read, Icons.auto_awesome_rounded, tr('read_tab')),
        nav(_TarotTab.library, Icons.menu_book_rounded, tr('library_tab')),
        nav(
          _TarotTab.journal,
          Icons.bookmark_border_rounded,
          tr('journal_tab'),
        ),
      ],
    ),
  );
  Widget nav(_TarotTab item, IconData icon, String label) {
    final active = tab == item;
    return Expanded(
      child: InkWell(
        key: ValueKey('tarot-tab-${item.name}'),
        onTap: () => setState(() => tab = item),
        borderRadius: BorderRadius.circular(17),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: active
                      ? plum.withValues(alpha: .13)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Icon(icon, size: 22, color: active ? plum : muted),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SLTheme.quicksand(
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w900 : FontWeight.w600,
                  color: active ? plum : muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget scroll(Widget child) => SingleChildScrollView(
    physics: const BouncingScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(18, 9, 18, 25),
    child: child,
  );

  Widget setupView() => scroll(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        hero(),
        const SizedBox(height: 17),
        daily(),
        const SizedBox(height: 22),
        Text(
          tr('setup_title'),
          style: SLTheme.quicksand(
            color: ink,
            fontSize: 23,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          tr('setup_desc'),
          style: SLTheme.quicksand(color: muted, fontSize: 14, height: 1.45),
        ),
        const SizedBox(height: 18),
        topics(),
        const SizedBox(height: 20),
        questionBox(),
        const SizedBox(height: 21),
        spreads(),
        const SizedBox(height: 18),
        howTo(),
      ],
    ),
  );
  Widget hero() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: dark,
      borderRadius: BorderRadius.circular(28),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome_outlined, color: gold, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                tr('deck_stats'),
                style: SLTheme.quicksand(
                  color: const Color(0xFFDBCADF),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final artWidth = constraints.maxWidth < 280 ? 82.0 : 100.0;
            final title = Text(
              tr('hero_title'),
              style: GoogleFonts.lora(
                color: const Color(0xFFF8EDDB),
                fontSize: constraints.maxWidth < 280 ? 20 : 21,
                height: 1.18,
                fontWeight: FontWeight.w500,
              ),
            );
            final artwork = SizedBox(
              width: artWidth,
              height: artWidth * 1.1,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Transform.translate(
                    offset: Offset(-artWidth * .23, 7),
                    child: Transform.rotate(
                      angle: -.2,
                      child: TarotArtwork(back: true, width: artWidth * .47),
                    ),
                  ),
                  Transform.translate(
                    offset: Offset(artWidth * .23, 7),
                    child: Transform.rotate(
                      angle: .2,
                      child: TarotArtwork(back: true, width: artWidth * .47),
                    ),
                  ),
                  TarotArtwork(card: tarotCards[17], width: artWidth * .56),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: gold,
                      size: 14,
                    ),
                  ),
                ],
              ),
            );
            if (MediaQuery.textScalerOf(context).scale(1) > 1.3) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  title,
                  const SizedBox(height: 8),
                  Center(child: artwork),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: title),
                const SizedBox(width: 10),
                artwork,
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        Text(
          tr('hero_desc'),
          style: SLTheme.quicksand(
            color: const Color(0xFFD9C9DD),
            fontSize: 12,
            height: 1.45,
          ),
        ),
      ],
    ),
  );

  Widget daily() {
    final card = tarotDailyCard(DateTime.now());
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: gold.withValues(alpha: .34)),
        boxShadow: [
          BoxShadow(
            color: ink.withValues(alpha: .04),
            blurRadius: 13,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          mini(card, 67),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('card_of_day'),
                  style: SLTheme.quicksand(
                    color: ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  card.localizedName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SLTheme.quicksand(
                    color: plum,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tr('daily_note'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: SLTheme.quicksand(
                    color: muted,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
                TextButton(
                  key: const Key('tarot-daily-reading'),
                  onPressed: () => start(card),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(44, 34),
                  ),
                  child: Text(
                    tr('open_daily'),
                    style: SLTheme.quicksand(
                      color: plum,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget topics() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        tr('themes'),
        style: SLTheme.quicksand(
          color: ink,
          fontSize: 16,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 7),
      Text(
        tr('topic_intro'),
        style: SLTheme.quicksand(color: muted, fontSize: 12, height: 1.35),
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final item in tarotTopics)
            ChoiceChip(
              label: Text(tr('topic_$item')),
              selected: topic == item,
              onSelected: (_) => setState(() => topic = item),
              selectedColor: plum,
              backgroundColor: surface,
              labelStyle: SLTheme.quicksand(
                color: topic == item ? surface : ink,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
        ],
      ),
    ],
  );
  Widget questionBox() => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(21),
      border: Border.all(color: ink.withValues(alpha: .08)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('question'),
          style: SLTheme.quicksand(
            color: ink,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('tarot-question-field'),
          controller: question,
          maxLines: 2,
          maxLength: 220,
          style: SLTheme.quicksand(color: ink, fontSize: 14),
          decoration: InputDecoration(
            hintText: tr('question_hint'),
            hintStyle: SLTheme.quicksand(color: muted, fontSize: 12),
            filled: true,
            fillColor: cream,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: gold.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('question_${topic}_$promptIndex'),
                style: SLTheme.quicksand(color: ink, fontSize: 13, height: 1.4),
              ),
              Wrap(
                spacing: 10,
                children: [
                  TextButton(
                    onPressed: () => setState(
                      () =>
                          question.text = tr('question_${topic}_$promptIndex'),
                    ),
                    child: Text(tr('use_prompt')),
                  ),
                  TextButton(
                    onPressed: () =>
                        setState(() => promptIndex = (promptIndex + 1) % 3),
                    child: Text(tr('new_prompt')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget spreads() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        tr('spreads'),
        style: SLTheme.quicksand(
          color: ink,
          fontSize: 16,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 5),
      Text(
        tr('spread_hint'),
        style: SLTheme.quicksand(color: muted, fontSize: 12),
      ),
      const SizedBox(height: 10),
      ...[for (final item in tarotSpreads) spreadTile(item)],
    ],
  );
  Widget spreadTile(TarotSpread item) {
    final active = spread.id == item.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        key: ValueKey('tarot-spread-${item.id}'),
        onTap: () => setState(() => spread = item),
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: active ? plum.withValues(alpha: .1) : surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: active ? plum : ink.withValues(alpha: .08),
              width: active ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: active ? plum : cream,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  active ? Icons.check_rounded : Icons.layers_outlined,
                  color: active ? surface : plum,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: SLTheme.quicksand(
                        color: ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: SLTheme.quicksand(
                        color: muted,
                        fontSize: 11.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                fmt('spread_count', {'count': item.slots.length}),
                style: SLTheme.quicksand(
                  color: plum,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget howTo() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: ink.withValues(alpha: .045),
      borderRadius: BorderRadius.circular(19),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('how_it_works'),
          style: SLTheme.quicksand(
            color: ink,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            step('1', tr('themes')),
            line(),
            step('2', tr('spreads')),
            line(),
            step('3', tr('tap_reveal')),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          tr('guide_short'),
          style: SLTheme.quicksand(color: muted, fontSize: 12, height: 1.4),
        ),
      ],
    ),
  );
  Widget step(String num, String text) => Expanded(
    child: Column(
      children: [
        Container(
          width: 29,
          height: 29,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: plum, shape: BoxShape.circle),
          child: Text(
            num,
            style: SLTheme.quicksand(
              color: const Color(0xFFFFFFFF),
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          text,
          maxLines: 2,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: SLTheme.quicksand(
            color: ink,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
  Widget line() => Container(
    width: 13,
    height: 1,
    color: plum.withValues(alpha: .25),
    margin: const EdgeInsets.only(bottom: 23),
  );
  Widget startButton() => SizedBox(
    width: double.infinity,
    height: 55,
    child: FilledButton(
      key: const Key('tarot-start-reading'),
      onPressed: busy ? null : start,
      style: FilledButton.styleFrom(
        backgroundColor: plum,
        foregroundColor: onPlum,
        disabledBackgroundColor: plum.withValues(alpha: .4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
      ),
      child: busy
          ? SizedBox(
              width: 21,
              height: 21,
              child: CircularProgressIndicator(strokeWidth: 2, color: surface),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.auto_awesome_rounded, size: 19),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    tr('begin'),
                    style: SLTheme.quicksand(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
    ),
  );

  Widget drawView() => scroll(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('pick_title'),
          style: GoogleFonts.lora(
            color: ink,
            fontSize: 26,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          tr('pick_desc'),
          style: SLTheme.quicksand(color: muted, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: Text(
                spread.title,
                style: SLTheme.quicksand(
                  color: ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              fmt('pick_progress', {
                'picked': draws.length,
                'total': spread.slots.length,
              }),
              style: SLTheme.quicksand(
                color: plum,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: draws.length / spread.slots.length,
          color: plum,
          backgroundColor: plum.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(8),
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, c) {
            final width = (c.maxWidth - 24) / 4;
            return Wrap(
              spacing: 8,
              runSpacing: 12,
              children: [
                for (var i = 0; i < 12; i++)
                  Semantics(
                    button: true,
                    selected: chosen.contains(i),
                    label: fmt('card_number', {'number': i + 1}),
                    child: InkWell(
                      key: Key('tarot-deck-$i'),
                      onTap: draws.length >= spread.slots.length
                          ? null
                          : () => choose(i),
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: width,
                        child: Stack(
                          children: [
                            Opacity(
                              opacity: chosen.contains(i) ? 0.45 : 1.0,
                              child: TarotArtwork(back: true, width: width),
                            ),
                            if (chosen.contains(i))
                              Positioned.fill(
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: surface,
                                    ),
                                    child: Icon(
                                      Icons.check_rounded,
                                      color: plum,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        if (draws.length == spread.slots.length) revealActions(),
        Wrap(
          spacing: 12,
          children: [
            TextButton.icon(
              key: const Key('tarot-shuffle'),
              onPressed: shuffle,
              icon: const Icon(Icons.shuffle_rounded, size: 17),
              label: Text(tr('shuffle')),
            ),
            TextButton(onPressed: setup, child: Text(tr('change_setup'))),
          ],
        ),
      ],
    ),
  );

  Widget revealActions() => Column(
    children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: gold.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(17),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              color: Color(0xFF9B6A21),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                tr('draw_done'),
                style: SLTheme.quicksand(
                  color: ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 11),
      SizedBox(
        width: double.infinity,
        height: 49,
        child: FilledButton(
          key: const Key('tarot-view-reading'),
          onPressed: () => setState(() => phase = 2),
          style: FilledButton.styleFrom(
            backgroundColor: dark,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Text(
            tr('view_reading'),
            style: SLTheme.quicksand(
              color: const Color(0xFFFFFFFF),
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    ],
  );

  Widget resultView() => scroll(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: saving ? null : setup,
              icon: Icon(Icons.arrow_back_rounded, color: ink),
            ),
            Expanded(
              child: Text(
                tr('results'),
                style: SLTheme.quicksand(
                  color: ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            IconButton(
              onPressed: showGuide,
              icon: Icon(Icons.info_outline_rounded, color: muted),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [dark, const Color(0xFF7658B8)]),
            borderRadius: BorderRadius.circular(23),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('topic_$topic'),
                style: SLTheme.quicksand(
                  color: gold,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                question.text.trim().isEmpty
                    ? tr('no_question')
                    : question.text.trim(),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: SLTheme.quicksand(
                  color: const Color(0xFFFFFFFF),
                  fontSize: 17,
                  height: 1.25,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                tr('reading_note'),
                style: SLTheme.quicksand(
                  color: Colors.white.withValues(alpha: .8),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ...[for (var i = 0; i < draws.length; i++) resultCard(i)],
        noteBox(),
        const SizedBox(height: 12),
        resultActions(),
      ],
    ),
  );
  Widget resultCard(int index) {
    final draw = draws[index], slot = spread.slots[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: ink.withValues(alpha: .07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 25,
                height: 25,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: plum.withValues(alpha: .1),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  (index + 1).toString(),
                  style: SLTheme.quicksand(
                    color: plum,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  tr('slot_$slot'),
                  style: SLTheme.quicksand(
                    color: ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Center(
            child: Semantics(
              button: !draw.revealed,
              label: draw.revealed ? draw.card.localizedName : tr('tap_reveal'),
              child: InkWell(
                key: Key('tarot-reveal-$index'),
                onTap: draw.revealed
                    ? () => showCard(draw.card)
                    : () => reveal(index),
                borderRadius: BorderRadius.circular(12),
                child: AnimatedSwitcher(
                  duration: Duration(milliseconds: reduceMotion ? 0 : 300),
                  child: KeyedSubtree(
                    key: ValueKey(draw.revealed),
                    child: cardVisual(draw, width: 136),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              draw.revealed ? draw.card.localizedName : tr('tap_reveal'),
              textAlign: TextAlign.center,
              style: GoogleFonts.lora(
                color: ink,
                fontSize: 21,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (draw.revealed) ...[
            const SizedBox(height: 6),
            Center(
              child: Text(
                '${draw.reversed ? tr('reversed') : tr('upright')} · ${draw.card.theme}',
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  color: muted,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 20),
            detail(tr('meaning'), draw.card.meaning(draw.reversed), plum),
            detail(tr('position'), tr('slot_desc_$slot'), gold),
            detail(tr('topic_lens'), tr('lens_$topic'), rose),
            detail(tr('reflection'), draw.card.reflection, plum),
            detail(
              tr('action'),
              '${draw.card.action} ${tr('topic_action_$topic')}',
              gold,
            ),
          ],
        ],
      ),
    );
  }

  Widget detail(String title, String text, Color color) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 4,
          height: 34,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: SLTheme.quicksand(
                  color: muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                text,
                style: SLTheme.quicksand(
                  color: ink,
                  fontSize: 13,
                  height: 1.42,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  Widget noteBox() => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 1),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: ink.withValues(alpha: .045),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.lightbulb_outline_rounded, color: plum, size: 20),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            '${fmt('theme_label', {'topic': tr('topic_$topic')})} · ${tr('perspective')}',
            style: SLTheme.quicksand(color: muted, fontSize: 12, height: 1.4),
          ),
        ),
      ],
    ),
  );
  Widget resultActions() => Column(
    children: [
      if (!allRevealed) ...[
        TextButton.icon(
          key: const Key('tarot-reveal-all'),
          onPressed: revealAll,
          icon: const Icon(Icons.auto_awesome_rounded),
          label: Text(tr('reveal_all')),
        ),
        const SizedBox(height: 8),
      ],

      SizedBox(
        width: double.infinity,
        height: 51,
        child: FilledButton.icon(
          key: const Key('tarot-save-reading'),
          onPressed: saving || !allRevealed ? null : openSave,
          style: FilledButton.styleFrom(
            backgroundColor: plum,
            foregroundColor: onPlum,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          icon: const Icon(Icons.bookmark_add_outlined),
          label: Text(
            savedSessionId == sessionId ? tr('saved') : tr('save'),
            style: SLTheme.quicksand(fontWeight: FontWeight.w900),
          ),
        ),
      ),
      const SizedBox(height: 9),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: setup,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(44, 48),
                side: BorderSide(color: ink.withValues(alpha: .2)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: Text(
                tr('new_reading'),
                style: SLTheme.quicksand(
                  color: ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              key: const Key('tarot-restart-reading'),
              onPressed: saving ? null : () => start(),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(44, 48),
                side: BorderSide(color: plum.withValues(alpha: .35)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: Text(
                tr('start_over'),
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  color: plum,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    ],
  );

  Widget library() {
    final q = search.text.trim().toLowerCase();
    final cards = tarotCards.where((card) {
      final okFilter =
          filter == 'all' ||
          (filter == 'major' && card.isMajor) ||
          (filter != 'major' &&
              filter != 'all' &&
              !card.isMajor &&
              card.suit.name == filter);
      return okFilter &&
          (q.isEmpty ||
              card.localizedName.toLowerCase().contains(q) ||
              card.theme.toLowerCase().contains(q) ||
              card.suitName.toLowerCase().contains(q) ||
              card.meaning(false).toLowerCase().contains(q) ||
              card.meaning(true).toLowerCase().contains(q));
    }).toList();
    return scroll(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('library_title'),
            style: SLTheme.quicksand(
              color: ink,
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            tr('library_desc'),
            style: SLTheme.quicksand(color: muted, fontSize: 13, height: 1.45),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: search,
            onChanged: (_) => setState(() {}),
            style: SLTheme.quicksand(color: ink, fontSize: 14),
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.search_rounded, color: plum),
              hintText: tr('search'),
              hintStyle: SLTheme.quicksand(color: muted, fontSize: 13),
              filled: true,
              fillColor: surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(17),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          filters(),
          const SizedBox(height: 13),
          if (cards.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(27),
                child: Text(
                  tr('no_results'),
                  textAlign: TextAlign.center,
                  style: SLTheme.quicksand(
                    color: muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
          else ...[
            for (final card in cards) libraryTile(card),
          ],
        ],
      ),
    );
  }

  Widget filters() => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final item in [
          'all',
          'major',
          'cups',
          'wands',
          'swords',
          'pentacles',
        ])
          Padding(
            padding: const EdgeInsets.only(right: 7),
            child: ChoiceChip(
              label: Text(
                item == 'all'
                    ? tr('all')
                    : item == 'major'
                    ? tr('major')
                    : tr('suit_$item'),
              ),
              selected: filter == item,
              onSelected: (_) => setState(() => filter = item),
              selectedColor: plum,
              backgroundColor: surface,
              labelStyle: SLTheme.quicksand(
                color: filter == item ? surface : ink,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(27),
              ),
            ),
          ),
      ],
    ),
  );
  Widget libraryTile(TarotCard card) {
    return InkWell(
      onTap: () => showCard(card),
      borderRadius: BorderRadius.circular(19),
      child: Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: ink.withValues(alpha: .07)),
        ),
        child: Row(
          children: [
            mini(card, 55),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.localizedName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SLTheme.quicksand(
                      color: ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    card.theme,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: SLTheme.quicksand(
                      color: muted,
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: muted),
          ],
        ),
      ),
    );
  }

  Widget journalView() => scroll(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('saved_readings'),
          style: SLTheme.quicksand(
            color: ink,
            fontSize: 25,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          fmt('saved_count', {'count': journal.length}),
          style: SLTheme.quicksand(color: muted, fontSize: 13),
        ),
        const SizedBox(height: 16),
        if (journal.isEmpty)
          emptyJournal()
        else ...[
          for (final item in journal) journalTile(item),
        ],
      ],
    ),
  );
  Widget emptyJournal() => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(20, 27, 20, 27),
    decoration: BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(25),
      border: Border.all(color: ink.withValues(alpha: .07)),
    ),
    child: Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: plum.withValues(alpha: .1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.bookmark_border_rounded, color: plum, size: 29),
        ),
        const SizedBox(height: 15),
        Text(
          tr('journal_empty'),
          textAlign: TextAlign.center,
          style: SLTheme.quicksand(
            color: ink,
            fontSize: 20,
            height: 1.12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          tr('journal_empty_desc'),
          textAlign: TextAlign.center,
          style: SLTheme.quicksand(color: muted, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 13),
        Text(
          tr('journal_storage'),
          textAlign: TextAlign.center,
          style: SLTheme.quicksand(color: muted, fontSize: 11, height: 1.35),
        ),
      ],
    ),
  );
  Widget journalTile(TarotSession item) {
    final date =
        '${item.date.day.toString().padLeft(2, '0')}/${item.date.month.toString().padLeft(2, '0')}/${item.date.year}';
    return InkWell(
      onTap: () => showSession(item),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ink.withValues(alpha: .07)),
        ),
        child: Row(
          children: [
            mini(item.draws.first.card, 54),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('topic_${item.topic}'),
                    style: SLTheme.quicksand(
                      color: plum,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fmt('reading_date', {'date': date}),
                    style: SLTheme.quicksand(color: muted, fontSize: 11),
                  ),
                  if (item.note.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        item.note,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SLTheme.quicksand(color: ink, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => deleteSession(item),
              tooltip: tr('delete_entry'),
              icon: Icon(Icons.delete_outline_rounded, color: muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget cardVisual(TarotDraw draw, {bool compact = false, double? width}) {
    final w = width ?? (compact ? 100.0 : 132.0);
    return SizedBox(
      width: w,
      height: w * 1.54,
      child: Stack(
        children: [
          TarotArtwork(card: draw.card, back: !draw.revealed, width: w),
          if (draw.revealed)
            Positioned(
              left: 6,
              right: 6,
              bottom: 11,
              child: Text(
                draw.card.localizedName,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: SLTheme.quicksand(
                  color: const Color(0xFF40375D),
                  fontSize: w < 75 ? 8 : 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget mini(TarotCard card, double width) =>
      cardVisual(TarotDraw(card, revealed: true), compact: true, width: width);
  Future<void> openSave() async {
    if (!allRevealed || saving) return;
    final owner = uid, house = widget.houseId, readingId = sessionId;
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(29)),
      ),
      builder: (sheet) => SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheet).bottom,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: ink.withValues(alpha: .16),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  tr('save_prompt'),
                  style: SLTheme.quicksand(
                    color: ink,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  tr('perspective'),
                  style: SLTheme.quicksand(color: muted, fontSize: 13),
                ),
                const SizedBox(height: 13),
                TextField(
                  key: const Key('tarot-note-field'),
                  controller: note,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 1200,
                  style: SLTheme.quicksand(color: ink, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: tr('note_hint'),
                    hintStyle: SLTheme.quicksand(color: muted),
                    filled: true,
                    fillColor: surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(19),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const Key('tarot-save-note'),
                    onPressed: () => Navigator.pop(sheet, note.text.trim()),
                    style: FilledButton.styleFrom(
                      backgroundColor: plum,
                      foregroundColor: onPlum,
                      minimumSize: const Size(48, 51),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      tr('save'),
                      style: SLTheme.quicksand(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result == null || !sameScope(owner, house) || sessionId != readingId) {
      return;
    }
    await saveSession(result);
  }

  Future<void> saveSession(String reflection) async {
    final owner = uid, house = widget.houseId;
    if (owner.isEmpty || !sameScope(owner, house)) {
      snack(tr('journal_anonymous'));
      return;
    }
    final session = TarotSession(
      id: sessionId,
      date: sessionDate,
      topic: topic,
      spreadId: spread.id,
      question: question.text.trim(),
      draws: List.of(draws),
      note: reflection,
    );
    setState(() => saving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!sameScope(owner, house)) return;
      final saved = await TarotJournalStore.save(prefs, owner, house, session);
      if (!sameScope(owner, house)) return;
      setState(() {
        journal = saved;
        savedSessionId = session.id;
      });
      snack(tr('saved'));
    } catch (_) {
      if (sameScope(owner, house)) snack(tr('save_failed'));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> deleteSession(TarotSession item) async {
    final owner = uid, house = widget.houseId;
    if (owner.isEmpty || !sameScope(owner, house)) return;
    final ok =
        await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
            title: Text(
              tr('delete_confirm'),
              style: SLTheme.quicksand(color: ink, fontWeight: FontWeight.w900),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog, false),
                child: Text(tr('cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialog, true),
                style: FilledButton.styleFrom(
                  backgroundColor: plum,
                  foregroundColor: onPlum,
                ),
                child: Text(tr('confirm')),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok || !sameScope(owner, house)) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!sameScope(owner, house)) return;
      final rest = await TarotJournalStore.delete(prefs, owner, house, item.id);
      if (sameScope(owner, house)) setState(() => journal = rest);
    } catch (_) {
      if (sameScope(owner, house)) snack(tr('save_failed'));
    }
  }

  Future<void> showCard(TarotCard card) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(29)),
      ),
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: mini(card, 87)),
              const SizedBox(height: 13),
              Center(
                child: Text(
                  card.localizedName,
                  textAlign: TextAlign.center,
                  style: SLTheme.quicksand(
                    color: ink,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Center(
                child: Text(
                  card.theme,
                  textAlign: TextAlign.center,
                  style: SLTheme.quicksand(
                    color: plum,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 17),
              detail(tr('meaning_up'), card.meaning(false), plum),
              detail(tr('meaning_rev'), card.meaning(true), rose),
              detail(tr('try_prompt'), card.reflection, gold),
              detail(tr('small_step'), card.action, plum),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> showSession(TarotSession item) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(29)),
      ),
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 17, 20, 25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('saved_readings'),
                style: SLTheme.quicksand(
                  color: ink,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                tr('topic_${item.topic}'),
                style: SLTheme.quicksand(
                  color: plum,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (item.question.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    item.question,
                    style: SLTheme.quicksand(
                      color: ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              const SizedBox(height: 13),
              for (var i = 0; i < item.draws.length; i++)
                detail(
                  tr(
                    'slot_${item.spread.slots[min(i, item.spread.slots.length - 1)]}',
                  ),
                  item.draws[i].card.meaning(item.draws[i].reversed),
                  plum,
                ),
              if (item.note.trim().isNotEmpty)
                detail(tr('note'), item.note, gold),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> showGuide() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(29)),
      ),
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ink.withValues(alpha: .16),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
              const SizedBox(height: 17),
              Text(
                tr('guide_title'),
                style: SLTheme.quicksand(
                  color: ink,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tr('guide_intro'),
                style: SLTheme.quicksand(
                  color: muted,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 17),
              guideItem(
                Icons.help_outline_rounded,
                tr('guide_question_title'),
                tr('guide_question_body'),
              ),
              guideItem(
                Icons.compare_arrows_rounded,
                tr('guide_orientation_title'),
                tr('guide_orientation_body'),
              ),
              guideItem(
                Icons.layers_outlined,
                tr('guide_deck_title'),
                tr('guide_deck_body'),
              ),
              guideItem(
                Icons.edit_note_rounded,
                tr('guide_reflect_title'),
                tr('guide_reflect_body'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() => tab = _TarotTab.library);
                },
                child: Text(
                  tr('browse'),
                  style: SLTheme.quicksand(
                    color: plum,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget guideItem(IconData icon, String title, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: plum.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: plum, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: SLTheme.quicksand(
                  color: ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                text,
                style: SLTheme.quicksand(
                  color: muted,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
