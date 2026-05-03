import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GameAssetInfo {
  final String gameId;
  final List<String> relativePaths;
  final String baseUrl;

  const GameAssetInfo({
    required this.gameId,
    required this.relativePaths,
    required this.baseUrl,
  });
}

class GameDownloadService extends ChangeNotifier {
  static final GameDownloadService _instance = GameDownloadService._internal();
  factory GameDownloadService() => _instance;
  GameDownloadService._internal();

  final Dio _dio = Dio();
  final Map<String, double> _downloadProgress = {};
  final Map<String, bool> _isDownloading = {};

  double? getProgress(String gameId) => _downloadProgress[gameId];
  bool isDownloading(String gameId) => _isDownloading[gameId] ?? false;

  // Cấu hình các file cần tải cho từng game
  final Map<String, GameAssetInfo> _gameConfigs = {
    'soul_block': const GameAssetInfo(
      gameId: 'soul_block',
      baseUrl: 'https://firebasestorage.googleapis.com/v0/b/soullocket-app.appspot.com/o/game_assets%2Fsoul_block%2F',
      relativePaths: [
        'soul_block_bgm.mp3',
        'big_win.mp3',
        'clear_burst.mp3',
        'drag_lift.mp3',
      ],
    ),
    'soul_rhythm': const GameAssetInfo(
      gameId: 'soul_rhythm',
      baseUrl: 'https://firebasestorage.googleapis.com/v0/b/soullocket-app.appspot.com/o/game_assets%2Fsoul_rhythm%2F',
      relativePaths: [
        'AxelF_CrazyFrog_Tutorial.mp3',
        '2PhutHon_Phao_tutorial.mp3',
        'Believer_ImagineDragons_Tutorial.mp3',
      ],
    ),
  };

  Future<String> getLocalPath(String gameId, String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/games/$gameId/$fileName';
  }

  Future<bool> isGameDownloaded(String gameId) async {
    final config = _gameConfigs[gameId];
    if (config == null) return true; // Game không có assets nặng

    for (final path in config.relativePaths) {
      final localPath = await getLocalPath(gameId, path);
      if (!await File(localPath).exists()) {
        return false;
      }
    }
    return true;
  }

  Future<void> downloadGame(String gameId) async {
    final config = _gameConfigs[gameId];
    if (config == null || (_isDownloading[gameId] ?? false)) return;

    _isDownloading[gameId] = true;
    _downloadProgress[gameId] = 0.0;
    notifyListeners();

    try {
      final directory = await getApplicationDocumentsDirectory();
      final gameDir = Directory('${directory.path}/games/$gameId');
      if (!await gameDir.exists()) {
        await gameDir.create(recursive: true);
      }

      int totalFiles = config.relativePaths.length;
      int downloadedFiles = 0;

      for (final fileName in config.relativePaths) {
        final localPath = '${gameDir.path}/$fileName';
        final remoteUrl = '${config.baseUrl}$fileName?alt=media';

        await _dio.download(
          remoteUrl,
          localPath,
          onReceiveProgress: (received, total) {
            if (total != -1) {
              double fileProgress = received / total;
              _downloadProgress[gameId] = (downloadedFiles + fileProgress) / totalFiles;
              notifyListeners();
            }
          },
        );
        downloadedFiles++;
      }

      // Lưu trạng thái đã tải
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('game_downloaded_$gameId', true);

      _downloadProgress.remove(gameId);
      _isDownloading[gameId] = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Lỗi tải game $gameId: $e');
      _isDownloading[gameId] = false;
      _downloadProgress.remove(gameId);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteGameData(String gameId) async {
    final directory = await getApplicationDocumentsDirectory();
    final gameDir = Directory('${directory.path}/games/$gameId');
    if (await gameDir.exists()) {
      await gameDir.delete(recursive: true);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('game_downloaded_$gameId', false);
    notifyListeners();
  }
}
