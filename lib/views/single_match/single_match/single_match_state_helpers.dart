part of '../single_match_hub_screen.dart';

List<String> _singleMatchParseTags(String raw) {
  final seen = <String>{};
  final tags = <String>[];
  for (final part in raw.split(',')) {
    final normalized = part.trim();
    if (normalized.isEmpty) {
      continue;
    }
    final key = normalized.toLowerCase();
    if (seen.add(key)) {
      tags.add(normalized);
    }
    if (tags.length >= 8) {
      break;
    }
  }
  return tags;
}

int? _singleMatchAgeFromDob(String rawDob) {
  final parsed = DateTime.tryParse(rawDob.trim());
  if (parsed == null) {
    return null;
  }
  final now = DateTime.now();
  var age = now.year - parsed.year;
  final hadBirthday = now.month > parsed.month ||
      (now.month == parsed.month && now.day >= parsed.day);
  if (!hadBirthday) {
    age -= 1;
  }
  if (age < 0 || age > 120) {
    return null;
  }
  return age;
}

void _singleMatchShowSnack(
  BuildContext context,
  String message, {
  required bool isError,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError ? const Color(0xFFB3261E) : null,
    ),
  );
}

String _singleMatchAvailableModesLabel({
  required bool canAudioCall,
  required bool canVideoCall,
}) {
  if (canAudioCall && canVideoCall) {
    return L10nService().translate('match_thoihocvid_61d810');
  }
  if (canVideoCall) {
    return L10nService().translate('match_utinvideoc_f3b4fe');
  }
  return L10nService().translate('match_cthgithoin_b1c34e');
}

String _singleMatchBuildCandidatePreviewText(
  SingleMatchCandidate candidate, {
  required List<String> sharedTags,
  required bool canAudioCall,
  required bool canVideoCall,
}) {
  if (candidate.intro.trim().isNotEmpty) {
    return candidate.intro.trim();
  }
  if (candidate.bio.trim().isNotEmpty) {
    return candidate.bio.trim();
  }
  if (sharedTags.isNotEmpty) {
    final highlighted = sharedTags.take(2).join(', ');
    return 'Hai bạn cùng thích $highlighted, khá hợp để mở đầu bằng một cuộc gọi ngắn và tự nhiên.';
  }
  return 'Hồ sơ này hợp với kiểu ${_singleMatchAvailableModesLabel(canAudioCall: canAudioCall, canVideoCall: canVideoCall).toLowerCase()}. Bạn có thể mở hồ sơ hoặc kết nối ngay.';
}

String _singleMatchChoiceLabel(List<_MatchChoice> options, String value) {
  for (final option in options) {
    if (option.value == value) {
      return option.label;
    }
  }
  return value;
}

String _singleMatchFormatRelativeTime(int epochMs) {
  if (epochMs <= 0) {
    return L10nService().translate('match_vaxong_e92d16');
  }
  final diff = DateTime.now().difference(
    DateTime.fromMillisecondsSinceEpoch(epochMs),
  );
  if (diff.inMinutes < 1) {
    return L10nService().translate('match_vaxong_e92d16');
  }
  if (diff.inMinutes < 60) {
    return '${diff.inMinutes} phút trước';
  }
  if (diff.inHours < 24) {
    return '${diff.inHours} giờ trước';
  }
  if (diff.inDays < 7) {
    return '${diff.inDays} ngày trước';
  }
  final date = DateTime.fromMillisecondsSinceEpoch(epochMs);
  final dd = date.day.toString().padLeft(2, '0');
  final mm = date.month.toString().padLeft(2, '0');
  return '$dd/$mm/${date.year}';
}

String _singleMatchFormatDuration(int seconds) {
  if (seconds <= 0) {
    return L10nService().translate('match_chabtmyr_9abb94');
  }
  final minutes = seconds ~/ 60;
  final remain = seconds % 60;
  if (minutes <= 0) {
    return '$remain giây';
  }
  return '${minutes}m ${remain.toString().padLeft(2, '0')}s';
}

_ScoredCandidate? _resolveFeaturedCandidate(
  List<_ScoredCandidate> candidates,
  String? featuredHouseId,
) {
  if (candidates.isEmpty) {
    return null;
  }
  if (featuredHouseId != null) {
    for (final item in candidates) {
      if (item.candidate.houseId == featuredHouseId) {
        return item;
      }
    }
  }
  return candidates.first;
}

_ScoredCandidate _pickRandomCandidateFromPool(
  List<_ScoredCandidate> candidates,
  String? featuredHouseId,
  Random random,
) {
  final poolWithoutFeatured = candidates
      .where((item) => item.candidate.houseId != featuredHouseId)
      .toList(growable: false);
  final candidatePool =
      poolWithoutFeatured.isNotEmpty ? poolWithoutFeatured : candidates;
  final topScore = candidatePool.first.score;
  final shortlist = candidatePool
      .take(min(10, candidatePool.length))
      .where((item) => item.score >= topScore - 12)
      .toList(growable: false);
  final top = (shortlist.isNotEmpty
          ? shortlist
          : candidatePool.take(min(6, candidatePool.length)).toList())
      .toList(growable: false);
  final totalWeight = top.fold<double>(0, (sum, item) => sum + item.score);
  if (totalWeight <= 0) {
    return top[random.nextInt(top.length)];
  }

  var cursor = random.nextDouble() * totalWeight;
  for (final item in top) {
    cursor -= item.score;
    if (cursor <= 0) {
      return item;
    }
  }
  return top.last;
}

class _SingleMatchDiscoverySnapshot {
  const _SingleMatchDiscoverySnapshot({
    required this.history,
    required this.candidates,
  });

  final List<SingleMatchHistoryEntry> history;
  final List<SingleMatchCandidate> candidates;
}

Stream<R> _combineLatest2<A, B, R>(
  Stream<A> first,
  Stream<B> second,
  R Function(A first, B second) combiner,
) async* {
  A? latestA;
  B? latestB;
  bool hasA = false;
  bool hasB = false;

  await for (final event in _StreamGroup.merge<(bool, Object?)>([
    first.map<(bool, Object?)>((value) => (true, value)),
    second.map<(bool, Object?)>((value) => (false, value)),
  ])) {
    if (event.$1) {
      latestA = event.$2 as A;
      hasA = true;
    } else {
      latestB = event.$2 as B;
      hasB = true;
    }

    if (hasA && hasB) {
      yield combiner(latestA as A, latestB as B);
    }
  }
}

class _StreamGroup {
  static Stream<T> merge<T>(List<Stream<T>> streams) {
    final controller = StreamController<T>();
    final subscriptions = <StreamSubscription<T>>[];
    var completed = 0;

    void closeIfDone() {
      if (completed == streams.length && !controller.isClosed) {
        controller.close();
      }
    }

    controller.onCancel = () async {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    };

    for (final stream in streams) {
      final subscription = stream.listen(
        controller.add,
        onError: (Object error) {
          debugPrint(
            '[SingleMatch] merged stream failed: ${AppErrorMapper.resolve(
              error,
              fallbackMessage:
                  L10nService().translate('match_khngthtidl_74b99d'),
            ).message}',
          );
        },
        onDone: () {
          completed++;
          closeIfDone();
        },
      );
      subscriptions.add(subscription);
    }

    if (streams.isEmpty) {
      controller.close();
    }

    return controller.stream;
  }
}

class _MatchChoice {
  const _MatchChoice({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;
}

class _ScoredCandidate {
  const _ScoredCandidate({
    required this.candidate,
    required this.score,
    required this.reasons,
    required this.sharedTags,
    required this.canAudioCall,
    required this.canVideoCall,
    required this.previewText,
  });

  final SingleMatchCandidate candidate;
  final double score;
  final List<String> reasons;
  final List<String> sharedTags;
  final bool canAudioCall;
  final bool canVideoCall;
  final String previewText;
}

extension _SingleMatchHubScreenHelperMethods on _SingleMatchHubScreenState {
  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }
    _singleMatchShowSnack(context, message, isError: isError);
  }

  String _availableModesLabel({
    required bool canAudioCall,
    required bool canVideoCall,
  }) {
    return _singleMatchAvailableModesLabel(
      canAudioCall: canAudioCall,
      canVideoCall: canVideoCall,
    );
  }

  String _buildCandidatePreviewText(
    SingleMatchCandidate candidate, {
    required List<String> sharedTags,
    required bool canAudioCall,
    required bool canVideoCall,
  }) {
    return _singleMatchBuildCandidatePreviewText(
      candidate,
      sharedTags: sharedTags,
      canAudioCall: canAudioCall,
      canVideoCall: canVideoCall,
    );
  }

  String _choiceLabel(List<_MatchChoice> options, String value) {
    return _singleMatchChoiceLabel(options, value);
  }

  String _formatRelativeTime(int epochMs) {
    return _singleMatchFormatRelativeTime(epochMs);
  }

  String _formatDuration(int seconds) {
    return _singleMatchFormatDuration(seconds);
  }
}
