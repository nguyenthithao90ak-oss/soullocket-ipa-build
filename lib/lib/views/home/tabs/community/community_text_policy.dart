part of '../community_tab.dart';

String _normalizeCommunityText(String input) {
  var value = input.toLowerCase();
  final replacements = <String, String>{
    L10nService().translate('home_txt_147e69'): 'a',
    L10nService().translate('home_txt_ae2260'): 'e',
    L10nService().translate('home_txt_08e9a3'): 'i',
    L10nService().translate('home_txt_76fa4b'): 'o',
    L10nService().translate('home_txt_95beaf'): 'u',
    L10nService().translate('home_txt_2a7735'): 'y',
    L10nService().translate('home_txt_b5407d'): 'd',
  };
  replacements.forEach((pattern, replacement) {
    value = value.replaceAll(RegExp('[$pattern]'), replacement);
  });
  value = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  return value;
}

String _sanitizeCommunityRenderText(String input) {
  return input
      .replaceAll(RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]'), '')
      .replaceAll('\u2028', '\n')
      .replaceAll('\u2029', '\n')
      .trim();
}

class _CommunityModerationResult {
  final bool hasViolation;
  final bool shouldPrivate;
  final String reason;

  const _CommunityModerationResult({
    required this.hasViolation,
    required this.shouldPrivate,
    required this.reason,
  });

  const _CommunityModerationResult.clean()
      : hasViolation = false,
        shouldPrivate = false,
        reason = '';
}

_CommunityModerationResult _moderateCommunityText(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) {
    return const _CommunityModerationResult.clean();
  }

  if (_containsBannedWords(trimmed)) {
    return _CommunityModerationResult(
      hasViolation: true,
      shouldPrivate: true,
      reason: _ct(
        L10nService().translate('home_nidungctkh_fa163a'),
        'The content contains a community-standard violation keyword.',
      ),
    );
  }

  final normalized = _normalizeCommunityText(trimmed);
  final links = RegExp(r'(https?:\/\/|www\.)', caseSensitive: false)
      .allMatches(trimmed)
      .length;
  if (links > 1) {
    return _CommunityModerationResult(
      hasViolation: true,
      shouldPrivate: false,
      reason: _ct(
        L10nService().translate('home_nidungcqun_e26487'),
        'The content has too many links and may be treated as spam.',
      ),
    );
  }
  if (RegExp(r'(.)\1{7,}').hasMatch(normalized)) {
    return _CommunityModerationResult(
      hasViolation: true,
      shouldPrivate: false,
      reason: _ct(
        L10nService().translate('home_nidungcktl_568351'),
        'The content has too many repeated characters.',
      ),
    );
  }

  final emojiLikeCount = RegExp(
    r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]',
    unicode: true,
  ).allMatches(trimmed).length;
  if (emojiLikeCount >= 18 && trimmed.length < 80) {
    return _CommunityModerationResult(
      hasViolation: true,
      shouldPrivate: false,
      reason: _ct(
        L10nService().translate('home_nidungcqun_499268'),
        'The content has too many emojis for a short post.',
      ),
    );
  }

  if (normalized.length <= 6 && RegExp(r'^(.)\1{3,}$').hasMatch(normalized)) {
    return _CommunityModerationResult(
      hasViolation: true,
      shouldPrivate: false,
      reason: _ct(
        L10nService().translate('home_nidungqung_273027'),
        'The content is too short and looks spammy.',
      ),
    );
  }

  return const _CommunityModerationResult.clean();
}

String? _validateCommunityText(
  String text, {
  required bool isComment,
}) {
  final trimmed = text.trim();
  final maxLength =
      isComment ? _communityCommentMaxLength : _communityPostMaxLength;
  if (trimmed.isEmpty) {
    return isComment
        ? _ct(
            L10nService().translate('home_bnhlunangt_6471ae'),
            'The comment is empty. Write a kind line before sending.',
          )
        : _ct(
            L10nService().translate('home_bivitangtr_41e9a3'),
            'The post is empty. Add text or a photo before posting.',
          );
  }
  if (trimmed.length > maxLength) {
    return isComment
        ? _ctf(
            'Bình luận chỉ nên tối đa {count} ký tự để dễ theo dõi.',
            'Comments should stay within {count} characters for readability.',
            {'count': maxLength},
          )
        : _ctf(
            'Bài viết chỉ nên tối đa {count} ký tự.',
            'Posts should stay within {count} characters.',
            {'count': maxLength},
          );
  }

  final moderation = _moderateCommunityText(trimmed);
  if (moderation.hasViolation && !moderation.shouldPrivate) {
    return moderation.reason;
  }
  return null;
}

bool _containsBannedWords(String text) {
  final normalized = _normalizeCommunityText(text);
  for (final term in _blockedCommunityTerms) {
    if (normalized.contains(term)) {
      return true;
    }
  }
  return false;
}
