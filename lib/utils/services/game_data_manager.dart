import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../app_error_mapper.dart';

class GameDataManager {
  static const String _downloadedKeyPrefix = 'game_downloaded_';

  // Base URL cho game assets (Cần upload các file assets lên hosting/Firebase Storage này)
  static const String _remoteBaseUrl = 'https://firebasestorage.googleapis.com/v0/b/soullocket-app.appspot.com/o/game_assets';

  static Future<String> getGameFolder(String gameId) async {
    final docDir = await getApplicationSupportDirectory();
    final gameDir = Directory('${docDir.path}/games/$gameId');
    if (!await gameDir.exists()) {
      await gameDir.create(recursive: true);
    }
    return gameDir.path;
  }

  static Future<bool> isGameDownloaded(String gameId) async {
    final prefs = await SharedPreferences.getInstance();
    final isMarked = prefs.getBool('$_downloadedKeyPrefix$gameId') ?? false;
    if (!isMarked) return false;

    // Kiểm tra thực tế thư mục có tồn tại không
    final folder = await getGameFolder(gameId);
    return Directory(folder).existsSync();
  }

  static Future<void> downloadGame(String gameId, {Function(double)? onProgress}) async {
    final folder = await getGameFolder(gameId);

    // Danh sách file cần tải cho từng game
    final Map<String, List<String>> gameFiles = {
      'block_blast': [
        'audio/soul_block/big_win.mp3',
        'audio/soul_block/big_win_memory_second_half.mp3',
        'audio/soul_block/big_win_place_first_half.mp3',
        'audio/soul_block/clear_burst.mp3',
        'audio/soul_block/drag_lift.mp3',
        'audio/soul_block/soul_block_bgm.mp3',
      ],
      'soul_rhythm': [
        'games/rhythm-tiles/icon.png',
        'audio/soul_rhythm_reference/sfx/button_tap.ogg',
        'audio/soul_rhythm_reference/sfx/click.ogg',
        'audio/soul_rhythm_reference/sfx/gameCompleted.ogg',
        'audio/soul_rhythm_reference/sfx/popup_close.ogg',
        'audio/soul_rhythm_reference/sfx/popup_open.ogg',
        'audio/soul_rhythm_reference/sfx/result_bgm.ogg',
        'audio/soul_rhythm_reference/sfx/start_song.ogg',
        'audio/soul_rhythm_reference/tutorial_songs/AxelF_CrazyFrog_Tutorial.mp3',
      ],
    };

    final files = gameFiles[gameId] ?? [];
    if (files.isEmpty) return;

    for (int i = 0; i < files.length; i++) {
      final fileRelativePath = files[i];
      final url = '$_remoteBaseUrl${Uri.encodeComponent(fileRelativePath)}?alt=media';
      final savePath = '$folder/${fileRelativePath.split('/').last}';

      try {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          final file = File(savePath);
          await file.create(recursive: true);
          await file.writeAsBytes(response.bodyBytes);
        }
      } catch (e) {
        debugPrint('Error downloading game asset: ${AppErrorMapper.resolve(
          e,
          fallbackMessage: 'Không thể tải tài nguyên game.',
        ).message}');
      }

      onProgress?.call((i + 1) / files.length);
    }

    await markAsDownloaded(gameId);
  }

  static Future<void> markAsDownloaded(String gameId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_downloadedKeyPrefix$gameId', true);
  }

  static Future<void> deleteGameData(String gameId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_downloadedKeyPrefix$gameId');

    final folder = await getGameFolder(gameId);
    final dir = Directory(folder);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  static Future<String?> getLocalFilePath(String gameId, String fileName) async {
    final folder = await getGameFolder(gameId);
    final file = File('$folder/$fileName');
    if (await file.exists()) {
      return file.path;
    }
    return null;
  }
}
