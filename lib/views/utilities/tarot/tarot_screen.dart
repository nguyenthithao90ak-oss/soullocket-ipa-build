import 'dart:math';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/sl_theme.dart';
import '../../../utils/services/l10n_service.dart';
import '../../../utils/services/tarot_reading_service.dart';

part 'models/tarot_models.dart';
part 'painters/tarot_painters.dart';

final List<TarotCard> _allCards = [
  TarotCard(
      name: 'The Fool',
      symbol: '🪁',
      uprightMeaning: L10nService().translate('util_mtkhiumiyb_69a121'),
      reversedMeaning: L10nService().translate('util_svivnghocn_831dbf')),
  TarotCard(
      name: 'The Magician',
      symbol: '✨',
      uprightMeaning: L10nService().translate('util_bnckhnngbi_222433'),
      reversedMeaning: L10nService().translate('util_nnglngangb_eb5169')),
  TarotCard(
      name: 'The High Priestess',
      symbol: '🔮',
      uprightMeaning: L10nService().translate('util_trcgicrtmn_b7f63e'),
      reversedMeaning: L10nService().translate('util_bnangbquat_917c34')),
  TarotCard(
      name: 'The Empress',
      symbol: '🌷',
      uprightMeaning: L10nService().translate('util_nnglngnuid_fe7eee'),
      reversedMeaning: L10nService().translate('util_schmscangm_1aee7f')),
  TarotCard(
      name: 'The Emperor',
      symbol: '🛡️',
      uprightMeaning: L10nService().translate('util_srrngranhg_ff9c12'),
      reversedMeaning: L10nService().translate('util_kimsotquta_562f9a')),
  TarotCard(
      name: 'The Lovers',
      symbol: '💞',
      uprightMeaning: L10nService().translate('util_tnhcmlachn_c55c2e'),
      reversedMeaning: L10nService().translate('util_mtcnbnghoc_8bd0c6')),
  TarotCard(
      name: 'The Chariot',
      symbol: '🏹',
      uprightMeaning: L10nService().translate('util_cmxcmuntin_80677b'),
      reversedMeaning: L10nService().translate('util_bnangcyqun_df95ab')),
  TarotCard(
      name: 'Strength',
      symbol: '🦁',
      uprightMeaning: L10nService().translate('util_sdummnhbit_22f465'),
      reversedMeaning: L10nService().translate('util_btananglmb_fb948e')),
  TarotCard(
      name: 'The Hermit',
      symbol: '🕯️',
      uprightMeaning: L10nService().translate('util_bncnmtqung_fa6015'),
      reversedMeaning: L10nService().translate('util_skhpliangd_9eaa01')),
  TarotCard(
      name: 'Wheel of Fortune',
      symbol: '🎡',
      uprightMeaning: L10nService().translate('util_mtbcngotcm_4d6d49'),
      reversedMeaning: L10nService().translate('util_bnangchngl_04ea64')),
  TarotCard(
      name: 'Justice',
      symbol: '⚖️',
      uprightMeaning: L10nService().translate('util_mithihisth_9be6af'),
      reversedMeaning: L10nService().translate('util_mtphaangnt_ea389e')),
  TarotCard(
      name: 'The Hanged Man',
      symbol: '🪞',
      uprightMeaning: L10nService().translate('util_cnigcnhnhi_f3f101'),
      reversedMeaning: L10nService().translate('util_schnchangk_fa687f')),
  TarotCard(
      name: 'Death',
      symbol: '🦋',
      uprightMeaning: L10nService().translate('util_mtlpcmxcca_f51277'),
      reversedMeaning: L10nService().translate('util_bnangnumti_7d7304')),
  TarotCard(
      name: 'Temperance',
      symbol: '🍷',
      uprightMeaning: L10nService().translate('util_cnbngchaln_889b06'),
      reversedMeaning: L10nService().translate('util_cmxcanglch_213be8')),
  TarotCard(
      name: 'The Devil',
      symbol: '⛓️',
      uprightMeaning: L10nService().translate('util_smnhdnhmch_b6b4b3'),
      reversedMeaning: L10nService().translate('util_bnangcchig_3dfb60')),
  TarotCard(
      name: 'The Tower',
      symbol: '⚡',
      uprightMeaning: L10nService().translate('util_mtsthtmnhc_132ccc'),
      reversedMeaning: L10nService().translate('util_bnangtrhon_c9bc90')),
  TarotCard(
      name: 'The Star',
      symbol: '⭐',
      uprightMeaning: L10nService().translate('util_hyvngchaln_c66c59'),
      reversedMeaning: L10nService().translate('util_bncntinliv_18533e')),
  TarotCard(
      name: 'The Moon',
      symbol: '🌙',
      uprightMeaning: L10nService().translate('util_nismhvtrcg_5f74a0'),
      reversedMeaning: L10nService().translate('util_sngmangdnt_488841')),
  TarotCard(
      name: 'The Sun',
      symbol: '🌞',
      uprightMeaning: L10nService().translate('util_ssngrmpvcm_2cea33'),
      reversedMeaning: L10nService().translate('util_nimvuiangb_a50170')),
  TarotCard(
      name: 'Judgement',
      symbol: '🎺',
      uprightMeaning: L10nService().translate('util_mtligithct_36f5b0'),
      reversedMeaning: L10nService().translate('util_bnangchnch_327f10')),
  TarotCard(
      name: 'The World',
      symbol: '🌍',
      uprightMeaning: L10nService().translate('util_mtvngcmxct_4bf877'),
      reversedMeaning: L10nService().translate('util_ciugcndang_f50965')),
  TarotCard(
      name: 'Ace of Cups',
      symbol: '💗',
      uprightMeaning: L10nService().translate('util_cmxcmiduvc_5d5c8d'),
      reversedMeaning: L10nService().translate('util_cmxcbnnhoc_ef2f5b')),
  TarotCard(
      name: 'Two of Cups',
      symbol: '🥂',
      uprightMeaning: L10nService().translate('util_sngiuvktni_afbc3d'),
      reversedMeaning: L10nService().translate('util_lchnhpcmxc_c7d730')),
  TarotCard(
      name: 'Three of Swords',
      symbol: '💔',
      uprightMeaning: L10nService().translate('util_niauchocvt_9875c5'),
      reversedMeaning: L10nService().translate('util_giaionhiph_904415')),
  TarotCard(
      name: 'Ten of Cups',
      symbol: '🌈',
      uprightMeaning: L10nService().translate('util_nnglngvinm_345e6a'),
      reversedMeaning: L10nService().translate('util_bctranhpan_75390f')),
  TarotCard(
      name: 'Queen of Cups',
      symbol: '👑',
      uprightMeaning: L10nService().translate('util_tritimrtnh_62a4d2'),
      reversedMeaning: L10nService().translate('util_bnangmcmxc_76d380')),
  TarotCard(
      name: 'Knight of Wands',
      symbol: '🔥',
      uprightMeaning: L10nService().translate('util_nnglngammc_24d8a1'),
      reversedMeaning: L10nService().translate('util_sbcngcthlm_7a75e1')),
];

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

class _TarotScreenState extends State<TarotScreen>
    with TickerProviderStateMixin {
  final TarotReadingService _tarotReadingService = TarotReadingService();
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  List<PickedCard> _pickedCards = [];
  bool _isPicking = false;
  bool _isAnalyzingReading = false;
  bool _isProfileLoading = true;
  int _analysisSession = 0;
  int? _pressedCardIndex;
  String _viewerRole = 'user1';
  String? _analysisError;
  TarotPersonalizedReading? _personalizedReading;
  TarotViewerProfile? _viewerProfile;
  Map<String, dynamic> _settingsMap = const {};
  late TarotSpreadTemplate _selectedSpread;

  TarotViewerProfile get _resolvedProfile => TarotViewerProfile.fromSettings(
        viewerRole: _viewerRole,
        relationshipMode: widget.relationshipMode,
        localeCode: L10nService().locale.languageCode,
        settings: _settingsMap,
        fallbackName: widget.myName,
      );

  @override
  void initState() {
    super.initState();
    _selectedSpread = TarotReadingService.spreads.first;
    _loadViewerProfile();
  }

  Future<void> _loadViewerProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString('il_role') ?? 'user1';
      final settingsSnap =
          await _dbRef.child('houses/${widget.houseId}/settings').get();
      final settingsMap = settingsSnap.exists && settingsSnap.value is Map
          ? Map<String, dynamic>.from(
              Map<dynamic, dynamic>.from(settingsSnap.value as Map),
            )
          : <String, dynamic>{};
      final profile = TarotViewerProfile.fromSettings(
        viewerRole: role,
        relationshipMode: widget.relationshipMode,
        localeCode: L10nService().locale.languageCode,
        settings: settingsMap,
        fallbackName: widget.myName,
      );
      if (!mounted) return;
      setState(() {
        _viewerRole = role;
        _settingsMap = settingsMap;
        _viewerProfile = profile;
        _isProfileLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _viewerProfile = _resolvedProfile;
        _isProfileLoading = false;
      });
    }
  }

  void _selectSpread(TarotSpreadTemplate spread) {
    if (_selectedSpread.id == spread.id) return;
    setState(() {
      _selectedSpread = spread;
      _pickedCards = [];
      _personalizedReading = null;
      _analysisError = null;
    });
  }

  void _pickCards() {
    final session = _analysisSession + 1;
    setState(() {
      _analysisSession = session;
      _isPicking = true;
      _isAnalyzingReading = false;
      _analysisError = null;
      _personalizedReading = null;
      _pickedCards = [];
    });

    Future.delayed(const Duration(milliseconds: 1300), () {
      if (!mounted) return;
      final random = Random();
      final shuffled = List<TarotCard>.from(_allCards)..shuffle(random);
      setState(() {
        _pickedCards = shuffled
            .take(_selectedSpread.slots.length)
            .map(
              (card) => PickedCard(
                card: card,
                isReversed: random.nextBool(),
              ),
            )
            .toList();
        _isPicking = false;
      });
      _analyzePickedCards(session);
    });
  }

  Future<void> _analyzePickedCards(int session) async {
    if (!mounted || _pickedCards.length != _selectedSpread.slots.length) return;
    setState(() {
      _isAnalyzingReading = true;
      _analysisError = null;
    });

    try {
      final profile = _viewerProfile ?? _resolvedProfile;
      final reading = await _tarotReadingService.buildReading(
        houseId: widget.houseId,
        viewerProfile: profile,
        spread: _selectedSpread,
        selections: List.generate(_pickedCards.length, (index) {
          final picked = _pickedCards[index];
          final slot = _selectedSpread.slots[index];
          return TarotReadingSelection(
            slotId: slot.id,
            label: L10nService().translate(slot.labelKey),
            cardName: picked.card.name,
            isReversed: picked.isReversed,
            baseMeaning: picked.isReversed
                ? picked.card.reversedMeaning
                : picked.card.uprightMeaning,
          );
        }),
      );
      if (!mounted || session != _analysisSession) return;
      setState(() {
        _personalizedReading = reading;
        _isAnalyzingReading = false;
      });
    } catch (_) {
      if (!mounted || session != _analysisSession) return;
      setState(() {
        _isAnalyzingReading = false;
        _analysisError = L10nService().translate('tarot_analysis_failed');
      });
    }
  }

  void _flipCard(int index) {
    if (_pickedCards[index].isFlipped) return;
    setState(() => _pressedCardIndex = index);
    Future.delayed(const Duration(milliseconds: 120), () {
      if (!mounted || index >= _pickedCards.length) return;
      if (_pickedCards[index].isFlipped) return;
      setState(() {
        _pickedCards[index].isFlipped = true;
        if (_pressedCardIndex == index) {
          _pressedCardIndex = null;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = _viewerProfile ?? _resolvedProfile;
    return Scaffold(
      backgroundColor: const Color(0xFF0E1022),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          L10nService().translate('tarot_title'),
          style: SLTheme.quicksand(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          _buildBackdrop(),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = _isCompactWidth(constraints.maxWidth);
              final horizontalPadding =
                  _horizontalPaddingFor(constraints.maxWidth);
              return SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          compact ? 8 : 12,
                          horizontalPadding,
                          compact ? 16 : 24,
                        ),
                        children: [
                          _buildHeroHeader(profile),
                          SizedBox(height: compact ? 16 : 18),
                          _buildSpreadSelector(),
                          SizedBox(height: compact ? 16 : 18),
                          if (_isPicking)
                            _buildShufflingState()
                          else if (_pickedCards.isEmpty)
                            _buildEmptyState()
                          else ...[
                            _buildReadingPanel(profile),
                            const SizedBox(height: 10),
                            for (var i = 0; i < _pickedCards.length; i++)
                              _buildTarotCardInteractive(
                                _pickedCards[i],
                                _selectedSpread.slots[i],
                                i,
                              ),
                          ],
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        compact ? 6 : 8,
                        horizontalPadding,
                        compact ? 14 : 22,
                      ),
                      child: ElevatedButton(
                        onPressed: _isPicking || _isAnalyzingReading
                            ? null
                            : _pickCards,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF5D8F),
                          foregroundColor: Colors.white,
                          minimumSize: Size(double.infinity, compact ? 50 : 58),
                          shape: RoundedRectangleBorder(
                              borderRadius: SLRadius.xlAll),
                          elevation: 0,
                        ),
                        child: Text(
                          _pickedCards.isEmpty
                              ? L10nService().translate('tarot_pick_button')
                              : L10nService().translate('tarot_pick_again'),
                          style: SLTheme.quicksand(
                            fontWeight: FontWeight.w900,
                            fontSize: compact ? 14 : 16,
                            letterSpacing: compact ? 0.2 : 0.6,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  bool _isCompactWidth(double width) => width <= 390;

  double _horizontalPaddingFor(double width) =>
      _isCompactWidth(width) ? 12 : 18;

  double _panelRadiusFor(double width) => _isCompactWidth(width) ? 22 : 28;

  double _panelPaddingFor(double width) => _isCompactWidth(width) ? 14 : 18;

  Widget _buildTarotSticker({
    required double width,
    required double height,
    BoxFit fit = BoxFit.contain,
    double opacity = 1,
  }) {
    return Opacity(
      opacity: opacity,
      child: Image.asset(
        'assets/images/utility_stickers/tarot.png',
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(width * 0.28),
              gradient: const LinearGradient(
                colors: [Color(0xFF5D4BFF), Color(0xFFFF5D8F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white.withValues(alpha: 0.92),
              size: width * 0.46,
            ),
          );
        },
      ),
    );
  }

  Widget _buildBackdrop() {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF0E1022),
                Color(0xFF191934),
                Color(0xFF271C3D),
                Color(0xFF0E1022),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        Positioned(
          top: -40,
          left: -50,
          child: _glowOrb(const Color(0xFF6B5BFF), 180),
        ),
        Positioned(
          top: 220,
          right: -80,
          child: _glowOrb(const Color(0xFFFF6FA8), 220),
        ),
        Positioned(
          bottom: 120,
          left: -60,
          child: _glowOrb(const Color(0xFF3AC8C8), 190),
        ),
        IgnorePointer(
          child: CustomPaint(
            size: Size.infinite,
            painter: _TarotDustPainter(),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroHeader(TarotViewerProfile profile) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = _isCompactWidth(constraints.maxWidth);
        final panelRadius = _panelRadiusFor(constraints.maxWidth);
        final panelPadding = _panelPaddingFor(constraints.maxWidth);
        final heroArt = _buildTarotSticker(
          width: compact ? 68 : 94,
          height: compact ? 68 : 94,
        );

        final headerText = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 10 : 12,
                vertical: compact ? 5 : 6,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: const Color(0x22FFFFFF),
              ),
              child: Text(
                L10nService().translate('tarot_header_badge'),
                style: SLTheme.quicksand(
                  color: const Color(0xFFFFD4E4),
                  fontWeight: FontWeight.w800,
                  fontSize: compact ? 10 : 11,
                ),
              ),
            ),
            SizedBox(height: compact ? 8 : 12),
            Text(
              L10nService().translate('tarot_header_title'),
              style: SLTheme.quicksand(
                fontSize: compact ? 18.5 : 24,
                color: Colors.white,
                fontWeight: FontWeight.w900,
                height: 1.1,
              ),
            ),
            SizedBox(height: compact ? 7 : 10),
            Text(
              L10nService().translate('tarot_header_desc'),
              style: SLTheme.quicksand(
                color: Colors.white.withValues(alpha: 0.78),
                fontWeight: FontWeight.w600,
                fontSize: compact ? 12.2 : 14,
                height: 1.35,
              ),
            ),
          ],
        );

        return Container(
          padding: EdgeInsets.all(panelPadding),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(panelRadius),
            gradient: const LinearGradient(
              colors: [Color(0x33FFFFFF), Color(0x14FFFFFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.24),
                blurRadius: 28,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (compact) ...[
                Align(alignment: Alignment.centerRight, child: heroArt),
                SizedBox(height: compact ? 12 : 14),
                headerText,
              ] else
                Row(
                  children: [
                    Expanded(child: headerText),
                    SizedBox(width: compact ? 10 : 12),
                    heroArt,
                  ],
                ),
              SizedBox(height: compact ? 12 : 16),
              if (_isProfileLoading)
                Text(
                  L10nService().translate('tarot_profile_loading'),
                  style: SLTheme.quicksand(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontWeight: FontWeight.w700,
                    fontSize: compact ? 12 : 13,
                  ),
                )
              else
                Wrap(
                  spacing: compact ? 6 : 8,
                  runSpacing: compact ? 6 : 8,
                  children: [
                    _profileChip(profile.viewerName, const Color(0xFF6B5BFF)),
                    if (profile.viewerAgeLabel != null)
                      _profileChip(
                        profile.viewerAgeLabel!,
                        const Color(0xFFFF6FA8),
                      ),
                    if (profile.viewerZodiacLabel != null)
                      _profileChip(
                        '${profile.viewerZodiacEmoji ?? ''} ${profile.viewerZodiacLabel!}'
                            .trim(),
                        const Color(0xFF3AC8C8),
                      ),
                    if (profile.compatibilityScore != null)
                      _profileChip(
                        '${L10nService().translate('tarot_chip_compatibility')} ${profile.compatibilityScore}%',
                        const Color(0xFFFFB347),
                      ),
                    if (profile.maturityLabel.isNotEmpty)
                      _profileChip(
                        profile.maturityLabel,
                        const Color(0xFFA78BFA),
                      ),
                  ],
                ),
            ],
          ),
        ).animate().fadeIn(duration: 320.ms).slideY(begin: 0.05, end: 0);
      },
    );
  }

  Widget _buildSpreadSelector() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = _isCompactWidth(constraints.maxWidth);
        final cardWidth = (constraints.maxWidth * (compact ? 0.7 : 0.58))
            .clamp(compact ? 160.0 : 180.0, compact ? 216.0 : 240.0)
            .toDouble();
        final cardRadius = compact ? 20.0 : 24.0;
        final cardSpacing = compact ? 10.0 : 12.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              L10nService().translate('tarot_select_spread'),
              style: SLTheme.quicksand(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: compact ? 15 : 16,
              ),
            ),
            SizedBox(height: compact ? 10 : 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children:
                    List.generate(TarotReadingService.spreads.length, (index) {
                  final spread = TarotReadingService.spreads[index];
                  final selected = _selectedSpread.id == spread.id;
                  return Padding(
                    padding: EdgeInsets.only(
                      right: index == TarotReadingService.spreads.length - 1
                          ? 0
                          : cardSpacing,
                    ),
                    child: SizedBox(
                      width: cardWidth,
                      child: GestureDetector(
                        onTap: () => _selectSpread(spread),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          padding: EdgeInsets.all(compact ? 12 : 16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(cardRadius),
                            gradient: LinearGradient(
                              colors: selected
                                  ? const [Color(0xFF5D4BFF), Color(0xFFFF5D8F)]
                                  : const [
                                      Color(0x22FFFFFF),
                                      Color(0x12FFFFFF)
                                    ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(
                              color: selected
                                  ? Colors.white.withValues(alpha: 0.3)
                                  : Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                L10nService().translate(spread.badgeKey),
                                style: SLTheme.quicksand(
                                  color: selected
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.72),
                                  fontWeight: FontWeight.w800,
                                  fontSize: compact ? 10.5 : 11,
                                ),
                              ),
                              SizedBox(height: compact ? 18 : 22),
                              Text(
                                L10nService().translate(spread.titleKey),
                                style: SLTheme.quicksand(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: compact ? 14.5 : 17,
                                  height: 1.2,
                                ),
                              ),
                              SizedBox(height: compact ? 6 : 8),
                              Text(
                                L10nService().translate(spread.subtitleKey),
                                maxLines: compact ? null : 3,
                                overflow:
                                    compact ? null : TextOverflow.ellipsis,
                                style: SLTheme.quicksand(
                                  color: Colors.white.withValues(alpha: 0.82),
                                  fontWeight: FontWeight.w600,
                                  fontSize: compact ? 11.8 : 13,
                                  height: 1.3,
                                ),
                              ),
                              SizedBox(height: compact ? 8 : 10),
                              Text(
                                '${spread.slots.length} ${L10nService().translate('tarot_card_unit')}',
                                style: SLTheme.quicksand(
                                  color: Colors.white.withValues(alpha: 0.78),
                                  fontWeight: FontWeight.w800,
                                  fontSize: compact ? 11.5 : 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = _isCompactWidth(constraints.maxWidth);
        return Container(
          padding: EdgeInsets.all(compact ? 20 : 26),
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(_panelRadiusFor(constraints.maxWidth)),
            color: Colors.white.withValues(alpha: 0.05),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            children: [
              _buildTarotSticker(
                width: compact ? 82 : 120,
                height: compact ? 82 : 120,
              )
                  .animate(
                      onPlay: (controller) => controller.repeat(reverse: true))
                  .scale(
                    begin: const Offset(0.96, 0.96),
                    end: const Offset(1.04, 1.04),
                    duration: 1600.ms,
                  ),
              SizedBox(height: compact ? 14 : 18),
              Text(
                L10nService().translate('tarot_empty_title'),
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: compact ? 17 : 18,
                ),
              ),
              SizedBox(height: compact ? 8 : 10),
              Text(
                L10nService().translate('tarot_empty_desc'),
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontWeight: FontWeight.w600,
                  fontSize: compact ? 13 : 14,
                  height: 1.45,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShufflingState() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = _isCompactWidth(constraints.maxWidth);
        return Container(
          width: double.infinity,
          constraints: BoxConstraints(minHeight: compact ? 244 : 280),
          padding: EdgeInsets.symmetric(vertical: compact ? 12 : 16),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.center,
                children: List.generate(3, (index) {
                  return Transform.translate(
                    offset: Offset((index - 1) * (compact ? 16 : 18), 0),
                    child: Transform.rotate(
                      angle: (index - 1) * 0.18,
                      child: _miniCardBack(compact: compact),
                    ),
                  )
                      .animate(
                          onPlay: (controller) =>
                              controller.repeat(reverse: true))
                      .moveY(
                        begin: -10,
                        end: 10,
                        duration: 500.ms,
                        delay: (index * 120).ms,
                      );
                }),
              ),
              SizedBox(height: compact ? 20 : 26),
              Text(
                L10nService().translate('tarot_shuffling'),
                style: SLTheme.quicksand(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: compact ? 15 : 16,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReadingPanel(TarotViewerProfile profile) {
    if (_isAnalyzingReading) {
      return _glassPanel(
        child: Row(
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: Color(0xFFFF7AAE),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                L10nService().translate('tarot_reading_loading'),
                style: SLTheme.quicksand(
                  color: Colors.white.withValues(alpha: 0.82),
                  fontWeight: FontWeight.w700,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_analysisError != null) {
      return _glassPanel(
        child: Text(
          _analysisError!,
          style: SLTheme.quicksand(
            color: Colors.white.withValues(alpha: 0.78),
            fontWeight: FontWeight.w700,
            height: 1.45,
          ),
        ),
      );
    }

    if (_personalizedReading == null) return const SizedBox.shrink();

    final reading = _personalizedReading!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = _isCompactWidth(constraints.maxWidth);
        return _glassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                reading.headline,
                style: SLTheme.quicksand(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: compact ? 17 : 18,
                  height: 1.28,
                ),
              ),
              SizedBox(height: compact ? 8 : 10),
              Text(
                reading.spreadSummary,
                style: SLTheme.quicksand(
                  color: const Color(0xFFFFD8E7),
                  fontWeight: FontWeight.w800,
                  fontSize: compact ? 13 : 14,
                  height: 1.45,
                ),
              ),
              SizedBox(height: compact ? 10 : 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: reading.metrics
                    .map((item) => _metricChip(item.label, item.value))
                    .toList(),
              ),
              SizedBox(height: compact ? 12 : 14),
              ...reading.facets.map(
                (facet) => Padding(
                  padding: EdgeInsets.only(bottom: compact ? 8 : 10),
                  child: _facetTile(facet),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                reading.energySummary,
                style: SLTheme.quicksand(
                  color: Colors.white.withValues(alpha: 0.82),
                  fontWeight: FontWeight.w700,
                  fontSize: compact ? 13 : 14,
                  height: 1.45,
                ),
              ),
              SizedBox(height: compact ? 8 : 10),
              Text(
                reading.advice,
                style: SLTheme.quicksand(
                  color: const Color(0xFFFFD8E7),
                  fontWeight: FontWeight.w800,
                  fontSize: compact ? 13 : 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTarotCardInteractive(
    PickedCard pickedCard,
    TarotSpreadSlot slot,
    int index,
  ) {
    final isPressed = _pressedCardIndex == index && !pickedCard.isFlipped;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        if (pickedCard.isFlipped) return;
        setState(() => _pressedCardIndex = index);
      },
      onTapCancel: () {
        if (_pressedCardIndex != index) return;
        setState(() => _pressedCardIndex = null);
      },
      onTap: () => _flipCard(index),
      child: AnimatedScale(
        scale: isPressed ? 0.94 : 1,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: (pickedCard.isFlipped
                        ? const Color(0xFFFF8CC6)
                        : const Color(0xFF8B6DFF))
                    .withValues(
                        alpha: isPressed || pickedCard.isFlipped ? 0.24 : 0.08),
                blurRadius: isPressed ? 30 : 18,
                spreadRadius: isPressed ? 1.5 : 0,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 720),
            switchInCurve: Curves.easeOutBack,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              final rotate = Tween<double>(begin: pi, end: 0).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeInOutCubicEmphasized,
                ),
              );
              final lift = Tween<double>(begin: 0.985, end: 1).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
              );
              return AnimatedBuilder(
                animation: animation,
                builder: (context, child) {
                  final angle = rotate.value;
                  final isFront = angle < pi / 2;
                  return Transform.scale(
                    scale: lift.value,
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.0012)
                        ..rotateY(angle),
                      child: isFront
                          ? child
                          : Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()..rotateY(pi),
                              child: _buildCardBack(slot),
                            ),
                    ),
                  );
                },
                child: child,
              );
            },
            child: pickedCard.isFlipped
                ? _buildCardFront(pickedCard, slot, index)
                : _buildCardBack(slot, key: ValueKey('back_$index')),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 320.ms)
        .slideY(begin: 0.08, end: 0, delay: (index * 70).ms);
  }

  Widget _buildCardBack(TarotSpreadSlot slot, {Key? key}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = _isCompactWidth(constraints.maxWidth);
        final radius = _panelRadiusFor(constraints.maxWidth);
        return Container(
          key: key,
          margin: const EdgeInsets.only(top: 12),
          constraints: BoxConstraints(minHeight: compact ? 170 : 198),
          padding: EdgeInsets.fromLTRB(
            compact ? 16 : 18,
            compact ? 16 : 20,
            compact ? 16 : 18,
            compact ? 16 : 18,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: const LinearGradient(
              colors: [Color(0xFF251B45), Color(0xFF141730)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Stack(
            children: [
              Positioned(
                right: 0,
                top: 0,
                child: _buildTarotSticker(
                  width: compact ? 42 : 54,
                  height: compact ? 42 : 54,
                  opacity: 0.92,
                ),
              ),
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: compact ? constraints.maxWidth - 34 : 240,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? 12 : 14,
                          vertical: compact ? 7 : 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          L10nService().translate(slot.labelKey),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: SLTheme.quicksand(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: compact ? 12.5 : 13,
                          ),
                        ),
                      ),
                      SizedBox(height: compact ? 12 : 14),
                      Text(
                        L10nService().translate('tarot_tap_to_open'),
                        textAlign: TextAlign.center,
                        style: SLTheme.quicksand(
                          color: Colors.white.withValues(alpha: 0.66),
                          fontWeight: FontWeight.w700,
                          fontSize: compact ? 12.5 : 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCardFront(
      PickedCard pickedCard, TarotSpreadSlot slot, int index) {
    final reading = _personalizedReading?.cardFor(slot.id);
    final palette = _cardPalette(pickedCard.card.name);
    final meaning = reading?.interpretation ??
        (pickedCard.isReversed
            ? pickedCard.card.reversedMeaning
            : pickedCard.card.uprightMeaning);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 380;
        final stacked = constraints.maxWidth < 362;
        final radius = _panelRadiusFor(constraints.maxWidth);
        final panelWidth = (constraints.maxWidth * 0.30).clamp(104.0, 120.0);
        final orientationLabel = pickedCard.isReversed
            ? L10nService().translate('tarot_reversed')
            : L10nService().translate('tarot_upright');
        final panel = Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: palette,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.06),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.12),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
              Center(
                child: Transform.rotate(
                  angle: pickedCard.isReversed ? pi : 0,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      pickedCard.card.symbol,
                      style: TextStyle(fontSize: stacked ? 56 : 52),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 10,
                right: 10,
                bottom: 12,
                child: Text(
                  orientationLabel,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SLTheme.quicksand(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: compact ? 10.5 : 11,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
        );
        final stackedPanel = ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 138),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: palette,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.06),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.12),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Transform.rotate(
                          angle: pickedCard.isReversed ? pi : 0,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              pickedCard.card.symbol,
                              style: const TextStyle(fontSize: 56),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          orientationLabel,
                          textAlign: TextAlign.center,
                          style: SLTheme.quicksand(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: compact ? 10.5 : 11,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

        final details = Padding(
          padding: EdgeInsets.all(stacked ? 14 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: stacked ? constraints.maxWidth - 28 : 220,
                  ),
                  child: _profileChip(
                    L10nService().translate(slot.labelKey),
                    const Color(0xFF6B5BFF),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                pickedCard.card.name,
                maxLines: stacked ? null : 2,
                overflow: stacked ? null : TextOverflow.ellipsis,
                style: SLTheme.quicksand(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: compact ? 15.5 : 17,
                ),
              ),
              if (reading != null) ...[
                const SizedBox(height: 6),
                Text(
                  reading.headline,
                  maxLines: stacked ? null : 3,
                  overflow: stacked ? null : TextOverflow.ellipsis,
                  style: SLTheme.quicksand(
                    color: const Color(0xFFFFC8DB),
                    fontWeight: FontWeight.w800,
                    fontSize: compact ? 12.5 : 13,
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                meaning,
                style: SLTheme.quicksand(
                  color: Colors.white.withValues(alpha: 0.84),
                  fontWeight: FontWeight.w600,
                  fontSize: compact ? 13 : 14,
                  height: 1.45,
                ),
              ),
            ],
          ),
        );

        return Container(
          key: ValueKey('front_$index'),
          margin: const EdgeInsets.only(top: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            color: Colors.white.withValues(alpha: 0.06),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: stacked
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      stackedPanel,
                      details,
                    ],
                  )
                : IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: panelWidth,
                          child: panel,
                        ),
                        Expanded(child: details),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _glowOrb(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 80,
            spreadRadius: 12,
          ),
        ],
      ),
    );
  }

  Widget _glassPanel({required Widget child}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          padding: EdgeInsets.all(_panelPaddingFor(constraints.maxWidth)),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(
              _panelRadiusFor(constraints.maxWidth),
            ),
            gradient: const LinearGradient(
              colors: [Color(0x33FFFFFF), Color(0x14FFFFFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: child,
        );
      },
    );
  }

  Widget _miniCardBack({bool compact = false}) {
    return Container(
      width: compact ? 74 : 86,
      height: compact ? 110 : 126,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(compact ? 20 : 24),
        gradient: const LinearGradient(
          colors: [Color(0xFF5D4BFF), Color(0xFFFF5D8F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: _buildTarotSticker(
          width: compact ? 34 : 44,
          height: compact ? 34 : 44,
        ),
      ),
    );
  }

  Widget _profileChip(String text, Color color) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final compact = _isCompactWidth(screenWidth);
    return Container(
      constraints: BoxConstraints(
        maxWidth: (compact ? screenWidth - 96 : 220.0).clamp(132.0, 260.0),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 5.5 : 7,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: SLTheme.quicksand(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: compact ? 10.5 : 11.5,
        ),
      ),
    );
  }

  Widget _metricChip(String label, String value) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final compact = _isCompactWidth(screenWidth);
    final maxChipWidth = compact ? ((screenWidth - 38) / 2) : 164.0;
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: compact ? 92 : 108,
        maxWidth: maxChipWidth.clamp(120.0, 164.0),
      ),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 11 : 12,
          vertical: compact ? 9 : 10,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: SLTheme.quicksand(
                color: Colors.white.withValues(alpha: 0.6),
                fontWeight: FontWeight.w700,
                fontSize: compact ? 10.5 : 11,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: SLTheme.quicksand(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: compact ? 12.5 : 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _facetTile(TarotReadingFacet facet) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final compact = _isCompactWidth(screenWidth);
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(compact ? 18 : 20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _profileChip(facet.accent, const Color(0xFFFF7AAE)),
          SizedBox(height: compact ? 7 : 8),
          Text(
            facet.title,
            style: SLTheme.quicksand(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: compact ? 14 : 15,
            ),
          ),
          SizedBox(height: compact ? 5 : 6),
          Text(
            facet.body,
            style: SLTheme.quicksand(
              color: Colors.white.withValues(alpha: 0.8),
              fontWeight: FontWeight.w600,
              fontSize: compact ? 13 : 14,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  List<Color> _cardPalette(String cardName) {
    if (cardName == 'The Sun' ||
        cardName == 'The Star' ||
        cardName == 'The World') {
      return const [Color(0xFFFFB347), Color(0xFFFF6FA8)];
    }
    if (cardName == 'The Moon' || cardName == 'The High Priestess') {
      return const [Color(0xFF5876FF), Color(0xFF8B5CFF)];
    }
    if (cardName == 'The Tower' ||
        cardName == 'Death' ||
        cardName == 'Three of Swords') {
      return const [Color(0xFFFF6B6B), Color(0xFF8E2B5B)];
    }
    if (cardName == 'Temperance' ||
        cardName == 'The Lovers' ||
        cardName == 'Ace of Cups') {
      return const [Color(0xFF3AC8C8), Color(0xFF6B5BFF)];
    }
    return const [Color(0xFF5D4BFF), Color(0xFFFF5D8F)];
  }
}
