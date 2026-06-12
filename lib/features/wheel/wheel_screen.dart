import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../core/sl_theme.dart';
import '../../utils/services/location_service.dart';
import '../../utils/app_error_mapper.dart';
import '../../utils/services/love_wheel_service.dart';

class WheelScreen extends StatefulWidget {
  final String houseId;

  const WheelScreen({super.key, required this.houseId});

  @override
  State<WheelScreen> createState() => _WheelScreenState();
}

class _WheelScreenState extends State<WheelScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _restaurantFetchTimeout = Duration(seconds: 12);
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final LoveWheelService _wheelService = LoveWheelService();
  StreamSubscription<DatabaseEvent>? _wheelSub;
  StreamSubscription<List<Map<String, dynamic>>>? _historySub;

  List<String> _items = [
    L10nService().translate('util_ainucm_2b8319'),
    L10nService().translate('util_airabt_f0a676'),
    L10nService().translate('util_ailaunh_38cac1'),
    L10nService().translate('util_aigit_48460b')
  ];
  final TextEditingController _itemController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;

  String _result = '';
  bool _isSpinning = false;
  bool _isFetchingRestaurants = false;
  late final AnimationController _spinController;
  Animation<double>? _spinAnimation;
  double _currentAngle = 0;
  int? _selectedIndex;
  List<_WheelHistoryEntry> _history = const [];

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _handleSpinCompleted();
        }
      });
    _itemController.text = _items.join('\n');
    _loadWheelData();
    _listenToHistory();
  }

  void _loadWheelData() {
    _wheelSub?.cancel();
    _wheelSub = _dbRef
        .child('houses/${widget.houseId}/wheel_items')
        .onValue
        .listen((event) {
      final parsed = _parseItems(event.snapshot.value);
      if (parsed == null) return;
      if (mounted) {
        setState(() {
          _items = parsed;
          if (_items.isEmpty) {
            _result = '';
            _selectedIndex = null;
          } else if (_selectedIndex != null &&
              _selectedIndex! >= _items.length) {
            _selectedIndex = null;
          }
          if (!_focusNode.hasFocus) {
            final newText = _items.join('\n');
            if (_itemController.text != newText) {
              _itemController.text = newText;
            }
          }
        });
      }
    });
  }

  List<String>? _parseItems(Object? value) {
    if (value == null) return null;
    if (value is List) {
      return value
          .whereType<String>()
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (value is Map) {
      final keys = value.keys.toList()
        ..sort((a, b) => a.toString().compareTo(b.toString()));
      final items = <String>[];
      for (final k in keys) {
        final v = value[k];
        if (v is String) {
          final s = v.trim();
          if (s.isNotEmpty) items.add(s);
        }
      }
      return items;
    }
    return null;
  }

  Future<void> _saveWheelData() async {
    await _dbRef.child('houses/${widget.houseId}/wheel_items').set(_items);
  }

  void _listenToHistory() {
    _historySub?.cancel();
    _historySub = _wheelService.listenToWheelHistory(widget.houseId).listen((
      records,
    ) {
      if (!mounted) return;
      setState(() {
        _history =
            records.map(_WheelHistoryEntry.fromMap).toList(growable: false);
      });
    });
  }

  void _onTextChanged(String text) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () async {
      final newItems = text
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (!mounted) return;
      setState(() {
        _items = newItems;
      });
      await _saveWheelData();
    });
  }

  Future<void> _fetchNearbyRestaurants() async {
    setState(() {
      _isFetchingRestaurants = true;
    });
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception(L10nService().translate('util_dchvnhvcha_809638'));
      }

      if (!mounted) return;
      final hasPerm = await LocationService()
          .requestPermission(context: context);
      if (!hasPerm) {
        throw Exception(L10nService().translate('util_quyntruycp_d7e682'));
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      const apiKey =
          String.fromEnvironment('GOOGLE_MAPS_API_KEY', defaultValue: '');
      List<String> newItems = [];

      if (apiKey.isNotEmpty) {
        // Fetch from Google Places Nearby Search
        final url = Uri.parse(
            'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=${position.latitude},${position.longitude}&radius=1500&type=restaurant&keyword=food&key=$apiKey');
        final response = await http.get(url).timeout(_restaurantFetchTimeout);
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['results'] != null) {
            final results = data['results'] as List;
            for (var i = 0; i < results.length && i < 8; i++) {
              final name = results[i]['name'];
              if (name != null) newItems.add(name.toString());
            }
          }
        }
      } else {
        // Fallback to OpenStreetMap Overpass API if no Google Maps API key is configured
        final overpassUrl =
            Uri.parse('https://overpass-api.de/api/interpreter');
        final query = '''
          [out:json];
          (
            node["amenity"="restaurant"](around:1500,${position.latitude},${position.longitude});
            node["amenity"="cafe"](around:1500,${position.latitude},${position.longitude});
            node["amenity"="fast_food"](around:1500,${position.latitude},${position.longitude});
          );
          out center 20;
        ''';
        final response = await http
            .post(overpassUrl, body: query)
            .timeout(_restaurantFetchTimeout);
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['elements'] != null) {
            final elements = data['elements'] as List;
            for (var el in elements) {
              final tags = el['tags'];
              if (tags != null && tags['name'] != null) {
                newItems.add(tags['name'].toString());
                if (newItems.length >= 8) break;
              }
            }
          }
        }
      }

      if (newItems.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _items = newItems;
          _itemController.text = newItems.join('\n');
        });
        await _saveWheelData();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Đã tìm thấy ${newItems.length} quán ăn gần bạn!'),
          backgroundColor: Colors.green,
        ));
      } else {
        throw Exception(L10nService().translate('util_khngtmthyq_bdb7de'));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            L10nService().translate('util_khngtmcqun_717598'),
          ),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingRestaurants = false;
        });
      }
    }
  }

  Future<void> _spin() async {
    if (_items.length < 2 || _spinController.isAnimating || _isSpinning) {
      return;
    }

    _focusNode.unfocus();
    setState(() {
      _isSpinning = true;
      _result = '';
      _selectedIndex = null;
    });

    try {
      final itemsSnapshot = List<String>.from(_items, growable: false);
      final targetIndex = await _wheelService.spinTheWheel(
        widget.houseId,
        itemsSnapshot,
      );
      if (!mounted || itemsSnapshot.isEmpty) return;

      final rand = Random();
      final spins = 10 + rand.nextInt(10);
      final sweep = 2 * pi / itemsSnapshot.length;
      final pointerAngle =
          (targetIndex * sweep) + sweep * (0.2 + rand.nextDouble() * 0.6);
      final targetNormalized = _normalizeAngle((2 * pi) - pointerAngle);
      final currentNormalized = _normalizeAngle(_currentAngle);
      final delta = _normalizeAngle(targetNormalized - currentNormalized);
      final endAngle = _currentAngle + spins * 2 * pi + delta;

      _spinAnimation = Tween<double>(
        begin: _currentAngle,
        end: endAngle,
      ).animate(
        CurvedAnimation(parent: _spinController, curve: Curves.easeOutQuart),
      );

      _spinController.forward(from: 0);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSpinning = false;
      });
      final errorInfo = AppErrorMapper.resolve(
        e,
        fallbackMessage: L10nService().translate('util_chathquayl_0d5dc0'),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorInfo.message),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _handleSpinCompleted() {
    final angle = _spinAnimation?.value ?? _currentAngle;
    _currentAngle = angle;
    if (_items.isEmpty) {
      if (mounted) {
        setState(() {
          _isSpinning = false;
          _result = '';
          _selectedIndex = null;
        });
      }
      return;
    }
    final idx = _selectedIndexForAngle(angle, _items.length);
    if (mounted) {
      setState(() {
        _isSpinning = false;
        _selectedIndex = idx;
        _result = _items[idx];
      });
    }
  }

  int _selectedIndexForAngle(double angle, int count) {
    if (count <= 0) return 0;
    final sweep = 2 * pi / count;
    final normalized = _normalizeAngle(angle);
    final pointer = (2 * pi - normalized) % (2 * pi);
    final idx = (pointer / sweep).floor();
    return idx.clamp(0, count - 1);
  }

  double _normalizeAngle(double angle) {
    const twoPi = 2 * pi;
    var a = angle % twoPi;
    if (a < 0) a += twoPi;
    return a;
  }

  @override
  void dispose() {
    _wheelSub?.cancel();
    _historySub?.cancel();
    _debounce?.cancel();
    _spinController.dispose();
    _itemController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SLTheme.appBar(context, L10nService().translate('util_vngquaynhm_856e66')),
      body: SLTheme.background(
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                SLSpacing.h20,
                _buildInputArea(),
                SLSpacing.gapH(30),
                _buildWheelArea(),
                SLSpacing.gapH(30),
                _buildResultArea(),
                SLSpacing.gapH(24),
                _buildHistorySection(),
                SLSpacing.gapH(40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: SLRadius.lgAll,
        border: Border.all(
          color: SLTheme.primary.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: SLTheme.primary.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.only(left: 16, top: 12, right: 16, bottom: 10),
            decoration: BoxDecoration(
              color: SLTheme.primary.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  L10nService().translate('util_nhpcclachn_bd1e90'),
                  style: SLTheme.quicksand(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: SLTheme.primary,
                  ),
                ),
                GestureDetector(
                  onTap:
                      _isFetchingRestaurants ? null : _fetchNearbyRestaurants,
                  child: Row(
                    children: [
                      if (_isFetchingRestaurants)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(SLTheme.primary),
                          ),
                        )
                      else
                        const Icon(Icons.restaurant_menu,
                            color: SLTheme.primary, size: 16),
                      SLSpacing.w4,
                      Text(
                        L10nService().translate('util_tmqungny_6f19d7'),
                        style: SLTheme.quicksand(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: SLTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          TextField(
            controller: _itemController,
            focusNode: _focusNode,
            maxLines: 5,
            minLines: 3,
            style: SLTheme.quicksand(
              color: SLTheme.textMain,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
            decoration: InputDecoration(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: InputBorder.none,
              hintText: 'Ví dụ:\nAi nấu cơm?\nAi rửa bát?',
              hintStyle: SLTheme.quicksand(
                color: SLTheme.textMuted.withValues(alpha: 0.5),
                fontWeight: FontWeight.w600,
              ),
            ),
            onChanged: _onTextChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildWheelArea() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = min(constraints.maxWidth, 340.0);
          return Center(
            child: Container(
              width: size + 20,
              height: size + 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.9),
                boxShadow: [
                  BoxShadow(
                    color: SLTheme.primary.withValues(alpha: 0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Center(
                child: SizedBox(
                  width: size,
                  height: size,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _spinController,
                        builder: (context, child) {
                          final angle = _spinAnimation?.value ?? _currentAngle;
                          return Transform.rotate(
                            angle: angle,
                            child: SizedBox.expand(
                              child: CustomPaint(
                                painter: _WheelPainter(
                                    items: _items,
                                    selectedIndex: _selectedIndex),
                              ),
                            ),
                          );
                        },
                      ),
                      Positioned(
                        top: 0,
                        child: _Pointer(),
                      ),
                      GestureDetector(
                        onTap:
                            (_items.length >= 2 && !_spinController.isAnimating)
                                ? _spin
                                : null,
                        child: Container(
                          width: size * 0.22,
                          height: size * 0.22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              'SPIN',
                              style: SLTheme.quicksand(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: SLTheme.primary,
                                letterSpacing: 1.0,
                              ),
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
        },
      ),
    );
  }

  Widget _buildResultArea() {
    return Column(
      children: [
        if (_isSpinning)
          AnimatedBuilder(
            animation: _spinController,
            builder: (context, child) {
              final angle = _spinAnimation?.value ?? _currentAngle;
              final idx = _selectedIndexForAngle(angle, _items.length);
              final currentItem = _items.isNotEmpty ? _items[idx] : '';
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: SLTheme.primary.withValues(alpha: 0.3), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: SLTheme.primary.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  currentItem.isEmpty ? L10nService().translate('util_chquay_eb9f26') : currentItem,
                  style: SLTheme.quicksand(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: SLTheme.primary,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            },
          )
        else if (_result.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFB3D9), SLTheme.primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: SLTheme.primary.withValues(alpha: 0.4),
                  blurRadius: 16,
                  spreadRadius: 2,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Text(
              '🎉 $_result 🎉',
              style: SLTheme.quicksand(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                shadows: [
                  const Shadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          )
              .animate(key: ValueKey(_result))
              .scale(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutBack)
              .shimmer(
                  duration: const Duration(milliseconds: 1500),
                  color: Colors.white.withValues(alpha: 0.6))
              .elevation(duration: const Duration(milliseconds: 600)),
        SLSpacing.h20,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _items.length < 2 || _isSpinning ? null : _spin,
              style: ElevatedButton.styleFrom(
                backgroundColor: SLTheme.primary,
                disabledBackgroundColor: SLTheme.primary.withValues(alpha: 0.5),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 4,
                shadowColor: SLTheme.primary.withValues(alpha: 0.35),
              ),
              child: Text(
                _isSpinning ? L10nService().translate('util_angquay_3580ce') : L10nService().translate('util_btuquay_5c5ee8'),
                style: SLTheme.quicksand(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistorySection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: SLRadius.lgAll,
        border: Border.all(color: SLTheme.primary.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
            color: SLTheme.primary.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: SLTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.history_rounded,
                  color: SLTheme.primary,
                ),
              ),
              SLSpacing.w12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      L10nService().translate('util_5ltquaygnn_75187c'),
                      style: SLTheme.quicksand(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: SLTheme.primary,
                      ),
                    ),
                    Text(
                      L10nService().translate('util_lulinidung_62d967'),
                      style: SLTheme.quicksand(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: SLTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: SLTheme.primary.withValues(alpha: 0.18),
                  ),
                ),
                child: Text(
                  '${_history.length}/5',
                  style: SLTheme.quicksand(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: SLTheme.primary,
                  ),
                ),
              ),
            ],
          ),
          SLSpacing.h16,
          if (_history.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: BoxDecoration(
                color: SLTheme.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: SLTheme.primary.withValues(alpha: 0.12)),
              ),
              child: Text(
                L10nService().translate('util_chaclchsqu_9e0f48'),
                style: SLTheme.quicksand(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: SLTheme.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
            )
          else
            ..._history.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == _history.length - 1 ? 0 : 12,
                ),
                child: _buildHistoryCard(index, item),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(int index, _WheelHistoryEntry entry) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white,
            index == 0
                ? const Color(0xFFFFF3F8)
                : SLTheme.primary.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SLTheme.primary.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: SLTheme.primary.withValues(alpha: index == 0 ? 0.18 : 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: SLTheme.quicksand(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: SLTheme.primary,
                    ),
                  ),
                ),
              ),
              SLSpacing.w12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      L10nService().translate('util_ktqu_80d598'),
                      style: SLTheme.quicksand(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: SLTheme.textMuted,
                        letterSpacing: 0.2,
                      ),
                    ),
                    SLSpacing.gapH(3),
                    Text(
                      entry.resultText,
                      style: SLTheme.quicksand(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: SLTheme.primary,
                      ),
                    ),
                    if (entry.formattedTime.isNotEmpty) ...[
                      SLSpacing.gapH(4),
                      Text(
                        entry.formattedTime,
                        style: SLTheme.quicksand(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: SLTheme.textMuted.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0F6),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: SLTheme.primary.withValues(alpha: 0.18)),
                ),
                child: Text(
                  '${entry.options.length} mục',
                  style: SLTheme.quicksand(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: SLTheme.primary,
                  ),
                ),
              ),
            ],
          ),
          SLSpacing.h12,
          Text(
            L10nService().translate('util_nidunglcqu_48a701'),
            style: SLTheme.quicksand(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: SLTheme.textMuted,
            ),
          ),
          SLSpacing.gapH(8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < entry.options.length; i++)
                _buildHistoryOptionChip(
                  label: entry.options[i],
                  isWinner: entry.selectedIndex == i ||
                      (entry.selectedIndex == null &&
                          entry.options[i] == entry.resultText),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryOptionChip({
    required String label,
    required bool isWinner,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: isWinner
            ? SLTheme.primary.withValues(alpha: 0.14)
            : const Color(0xFFF7F7FB),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isWinner
              ? SLTheme.primary.withValues(alpha: 0.32)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isWinner) ...[
            const Icon(Icons.favorite, size: 14, color: SLTheme.primary),
            SLSpacing.gapW(6),
          ],
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 210),
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: SLTheme.quicksand(
                fontSize: 12,
                fontWeight: isWinner ? FontWeight.w900 : FontWeight.w700,
                color: isWinner ? SLTheme.primary : SLTheme.textMain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WheelHistoryEntry {
  final String id;
  final String resultText;
  final List<String> options;
  final int? selectedIndex;
  final int spinnedAt;

  const _WheelHistoryEntry({
    required this.id,
    required this.resultText,
    required this.options,
    required this.selectedIndex,
    required this.spinnedAt,
  });

  factory _WheelHistoryEntry.fromMap(Map<String, dynamic> data) {
    final rawOptions = data['options'];
    final options = rawOptions is List
        ? rawOptions
            .map((item) => item?.toString().trim() ?? '')
            .where((item) => item.isNotEmpty)
            .toList(growable: false)
        : const <String>[];

    return _WheelHistoryEntry(
      id: data['id']?.toString() ?? '',
      resultText: data['resultText']?.toString().trim() ?? '',
      options: options,
      selectedIndex: _toInt(data['selectedIndex']),
      spinnedAt: _toInt(data['spinnedAt']) ?? 0,
    );
  }

  String get formattedTime {
    if (spinnedAt <= 0) {
      return '';
    }
    return DateFormat('HH:mm  dd/MM/yyyy').format(
      DateTime.fromMillisecondsSinceEpoch(spinnedAt),
    );
  }

  static int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}

class _WheelPainter extends CustomPainter {
  final List<String> items;
  final int? selectedIndex;

  _WheelPainter({required this.items, required this.selectedIndex});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = min(size.width, size.height) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final bgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    if (items.isEmpty) {
      final borderPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawCircle(center, radius, borderPaint);
      return;
    }

    final count = items.length;
    final sweep = 2 * pi / count;
    const startAngle = -pi / 2;

    final colorPalette = [
      const Color(0xFFFF85B3),
      const Color(0xFF81D4FA),
      const Color(0xFFFFD54F),
      const Color(0xFFB388FF),
      const Color(0xFF81C784),
      const Color(0xFFFFB74D),
      const Color(0xFF4FC3F7),
      const Color(0xFFF06292),
      const Color(0xFF4DB6AC),
    ];

    for (var i = 0; i < count; i++) {
      final baseColor = count <= colorPalette.length
          ? colorPalette[i % colorPalette.length]
          : HSVColor.fromAHSV(1, (i * (360 / count)) % 360, 0.55, 1.0)
              .toColor();

      final paint = Paint()
        ..color = baseColor.withValues(alpha: 0.9)
        ..style = PaintingStyle.fill;

      canvas.drawArc(rect, startAngle + i * sweep, sweep, true, paint);

      final dividerPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawArc(rect, startAngle + i * sweep, sweep, true, dividerPaint);

      if (selectedIndex != null && selectedIndex == i) {
        final highlightPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6;
        canvas.drawArc(rect, startAngle + i * sweep + 0.02, sweep - 0.04, true,
            highlightPaint);
      }

      final mid = startAngle + (i + 0.5) * sweep;
      final labelPos = Offset(
        center.dx + cos(mid) * radius * 0.62,
        center.dy + sin(mid) * radius * 0.62,
      );

      final tp = TextPainter(
        text: TextSpan(
          text: items[i],
          style: SLTheme.quicksand(
            fontSize: max(11, min(14, 240 / count)),
            fontWeight: FontWeight.w900,
            color: Colors.white,
            shadows: [
              Shadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 10),
            ],
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: ui.TextDirection.ltr,
        maxLines: 2,
        ellipsis: '…',
      )..layout(maxWidth: radius * 0.78);

      tp.paint(canvas, labelPos - Offset(tp.width / 2, tp.height / 2));
    }

    final ringPaint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        radius,
        [
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.4),
        ],
        [0.6, 1.0],
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;
    canvas.drawCircle(center, radius - 5, ringPaint);

    final outerBorderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawCircle(center, radius - 3, outerBorderPaint);
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) {
    return oldDelegate.items != items ||
        oldDelegate.selectedIndex != selectedIndex;
  }
}

class _Pointer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.92),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.favorite, color: Color(0xFFFC4A1A), size: 18),
        ),
        SLSpacing.gapH(2),
        CustomPaint(
          size: const Size(22, 16),
          painter: _TrianglePainter(),
        ),
      ],
    );
  }
}

class _TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.92);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
