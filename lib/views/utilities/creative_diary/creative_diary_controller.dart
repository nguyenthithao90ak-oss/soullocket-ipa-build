import 'dart:async';
import 'package:flutter/material.dart';
import '../../../utils/services/creative_diary_service.dart';
import '../../../utils/services/house_service.dart';
import '../../home/tabs/diary/controllers/diary_guard_controller.dart';

class DiaryPageData {
  final String id;
  final String authorId;
  final String authorName;
  final String content;
  final String? imageUrl;
  final String? stickerUrl;
  final int createdAtMs;
  final String? backgroundTone;
  final int index;

  const DiaryPageData({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.content,
    this.imageUrl,
    this.stickerUrl,
    required this.createdAtMs,
    this.backgroundTone,
    required this.index,
  });

  factory DiaryPageData.fromMap(Map<dynamic, dynamic> map, int idx) {
    return DiaryPageData(
      id: map['id']?.toString() ?? '',
      authorId: map['authorId']?.toString() ?? '',
      authorName: map['authorName']?.toString() ?? '',
      content: map['content']?.toString() ?? '',
      imageUrl: map['imageUrl']?.toString(),
      stickerUrl: map['stickerUrl']?.toString(),
      createdAtMs: map['createdAtMs'] is int
          ? map['createdAtMs']
          : int.tryParse(map['createdAtMs']?.toString() ?? '0') ?? 0,
      backgroundTone: map['backgroundTone']?.toString(),
      index: idx,
    );
  }
}

class CreativeDiaryController extends ChangeNotifier {
  final String? initialHouseId;
  final CreativeDiaryService _creativeDiaryService = CreativeDiaryService();
  final HouseService _houseService = HouseService();
  final DiaryGuardController guardController = DiaryGuardController();

  StreamSubscription<List<Map<dynamic, dynamic>>>? _pagesSubscription;

  List<DiaryPageData> _pages = [];
  List<DiaryPageData> get pages => _pages;

  int _currentIndex = 0;
  int get currentIndex => _currentIndex;

  String? _houseId;
  String? get houseId => _houseId;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _isRefreshing = false;
  bool get isRefreshing => _isRefreshing;

  CreativeDiaryController({this.initialHouseId}) {
    _init();
  }

  Future<void> _init() async {
    final resolvedHouseId = initialHouseId ?? await _houseService.getCurrentHouseId();

    if (resolvedHouseId == null || resolvedHouseId.isEmpty) {
      _houseId = null;
      _isLoading = false;
      notifyListeners();
      return;
    }

    _houseId = resolvedHouseId;
    await _pagesSubscription?.cancel();
    
    _pagesSubscription = _creativeDiaryService.listenToDiaryPages(resolvedHouseId).listen(
      (rawPages) {
        final nextPages = <DiaryPageData>[];
        for (var index = 0; index < rawPages.length; index++) {
          nextPages.add(DiaryPageData.fromMap(rawPages[index], index));
        }

        final hasExistingPages = _pages.isNotEmpty;
        _pages = nextPages;
        
        if (_pages.isEmpty) {
          _currentIndex = 0;
        } else if (_currentIndex >= _pages.length) {
          _currentIndex = _pages.length - 1;
        }
        
        _isLoading = false;
        _isRefreshing = hasExistingPages;
        notifyListeners();

        if (hasExistingPages) {
          Future.delayed(const Duration(milliseconds: 300), () {
            _isRefreshing = false;
            notifyListeners();
          });
        }
      },
      onError: (_) {
        _isLoading = false;
        _isRefreshing = false;
        notifyListeners();
      },
    );
  }

  void updateCurrentIndex(int index) {
    if (_currentIndex != index) {
      _currentIndex = index;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _pagesSubscription?.cancel();
    guardController.dispose();
    super.dispose();
  }
}
