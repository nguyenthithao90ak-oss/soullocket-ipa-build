import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../utils/app_error_mapper.dart';
import '../cloudflare_r2_service.dart';
import '../offline_cache_service.dart';

class GameAssetInfo {
  final String gameId;
  final List<String> relativePaths;
  final String storagePath;
  final String downloadSizeLabel;

  const GameAssetInfo({
    required this.gameId,
    required this.relativePaths,
    required this.storagePath,
    required this.downloadSizeLabel,
  });
}

class GameDownloadDisclosure {
  final String sizeLabel;
  final int fileCount;

  const GameDownloadDisclosure({
    required this.sizeLabel,
    required this.fileCount,
  });
}

class GameDownloadService extends ChangeNotifier {
  static final GameDownloadService _instance = GameDownloadService._internal();
  factory GameDownloadService() => _instance;
  GameDownloadService._internal();

  final Map<String, double> _downloadProgress = {};
  final Map<String, bool> _isDownloading = {};

  double? getProgress(String gameId) => _downloadProgress[gameId];
  bool isDownloading(String gameId) => _isDownloading[gameId] ?? false;

  // Cấu hình các file cần tải cho từng game
  final Map<String, GameAssetInfo> _gameConfigs = {
    'soul_block': const GameAssetInfo(
      gameId: 'soul_block',
      storagePath: 'game_assets/soul_block',
      downloadSizeLabel: 'khoảng 2 MB',
      relativePaths: [
        'soul_block_bgm.mp3',
        'big_win.mp3',
        'clear_burst.mp3',
        'drag_lift.mp3',
      ],
    ),
  };

  GameDownloadDisclosure disclosureFor(String gameId) {
    final config = _gameConfigs[gameId];
    if (config == null || config.relativePaths.isEmpty) {
      return const GameDownloadDisclosure(sizeLabel: '0 MB', fileCount: 0);
    }
    return GameDownloadDisclosure(
      sizeLabel: config.downloadSizeLabel,
      fileCount: config.relativePaths.length,
    );
  }

  Future<String> getLocalPath(String gameId, String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/games/$gameId/$fileName';
  }

  Future<bool> isGameDownloaded(String gameId) async {
    final config = _gameConfigs[gameId];
    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    final savedStatus = prefs.getBool('game_downloaded_$gameId') ?? false;
    if (savedStatus) {
      return true;
    }
    if (config == null || config.relativePaths.isEmpty) {
      return false;
    }

    final directory = await getApplicationDocumentsDirectory();
    for (final fileName in config.relativePaths) {
      final file = File('${directory.path}/games/$gameId/$fileName');
      if (!await file.exists()) {
        return false;
      }
    }

    await prefs.setBool('game_downloaded_$gameId', true);
    return true;
  }

  Future<void> downloadGame(String gameId) async {
    final config = _gameConfigs[gameId];
    if (_isDownloading[gameId] ?? false) return;
    if (config == null) {
      _isDownloading[gameId] = true;
      _downloadProgress[gameId] = 0.0;
      notifyListeners();

      // Simulate download for bundled games
      for (int i = 1; i <= 10; i++) {
        await Future.delayed(const Duration(milliseconds: 150));
        _downloadProgress[gameId] = i / 10.0;
        notifyListeners();
      }

      final prefs = OfflineCacheService.getPrefsSync() ??
          await SharedPreferences.getInstance();
      await prefs.setBool('game_downloaded_$gameId', true);
      _downloadProgress.remove(gameId);
      _isDownloading[gameId] = false;
      notifyListeners();
      return;
    }

    _isDownloading[gameId] = true;
    _downloadProgress[gameId] = 0.0;
    notifyListeners();

    try {
      if (config.relativePaths.isEmpty) {
        // Simulate download for bundled games so UI shows progress
        for (int i = 1; i <= 10; i++) {
          await Future.delayed(const Duration(milliseconds: 100));
          _downloadProgress[gameId] = i / 10.0;
          notifyListeners();
        }
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final gameDir = Directory('${directory.path}/games/$gameId');
        if (!await gameDir.exists()) {
          await gameDir.create(recursive: true);
        }

        int totalFiles = config.relativePaths.length;
        int downloadedFiles = 0;

        for (final fileName in config.relativePaths) {
          final localPath = '${gameDir.path}/$fileName';
          final localFile = File(localPath);

          if (await localFile.exists()) {
            downloadedFiles++;
            continue;
          }

          // Tải từ Cloudflare R2 (public domain)
          final fullStoragePath = '${config.storagePath}/$fileName';
          CloudflareR2Service.instance.init();
          final cleanDomain =
              _getCleanR2Domain(CloudflareR2Service.publicDomain);
          final remoteUrl = '$cleanDomain/$fullStoragePath';

          final client = http.Client();
          try {
            final request = http.Request('GET', Uri.parse(remoteUrl));
            final response = await client.send(request);

            if (response.statusCode < 200 || response.statusCode >= 300) {
              throw HttpException(
                'Tải file thất bại (mã lỗi: ${response.statusCode})',
                uri: Uri.parse(remoteUrl),
              );
            }

            final totalBytes = response.contentLength ?? -1;
            int receivedBytes = 0;
            final sink = localFile.openWrite();

            await for (final chunk in response.stream) {
              sink.add(chunk);
              receivedBytes += chunk.length;
              if (totalBytes > 0) {
                final fileProgress = receivedBytes / totalBytes;
                _downloadProgress[gameId] =
                    (downloadedFiles + fileProgress) / totalFiles;
                notifyListeners();
              }
            }

            await sink.flush();
            await sink.close();
          } catch (e) {
            if (await localFile.exists()) {
              await localFile.delete();
            }
            rethrow;
          } finally {
            client.close();
          }
          downloadedFiles++;
        }
      }

      // Lưu trạng thái đã tải
      final prefs = OfflineCacheService.getPrefsSync() ??
          await SharedPreferences.getInstance();
      await prefs.setBool('game_downloaded_$gameId', true);

      _downloadProgress.remove(gameId);
      _isDownloading[gameId] = false;
      notifyListeners();
    } catch (e) {
      final errorMessage = AppErrorMapper.resolve(e).message;
      debugPrint('Lỗi tải game: $errorMessage');
      _isDownloading[gameId] = false;
      _downloadProgress.remove(gameId);
      notifyListeners();
      throw errorMessage;
    }
  }

  Future<void> deleteGameData(String gameId) async {
    final directory = await getApplicationDocumentsDirectory();
    final gameDir = Directory('${directory.path}/games/$gameId');
    if (await gameDir.exists()) {
      await gameDir.delete(recursive: true);
    }
    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    await prefs.setBool('game_downloaded_$gameId', false);
    notifyListeners();
  }

  String _getCleanR2Domain(String domain) {
    final d = domain.trim();
    if (d.startsWith('https://images.weserv.nl/if (url != null) url!=')) {
      final sub = d.substring('https://images.weserv.nl/if (url != null) url!='.length);
      return 'https://$sub';
    }
    return d;
  }
}
