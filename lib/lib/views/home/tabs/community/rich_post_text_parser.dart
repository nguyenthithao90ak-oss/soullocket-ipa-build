enum RichPostTextSegmentKind {
  plain,
  hashtag,
  mention,
}

class RichPostTextSegment {
  final String text;
  final RichPostTextSegmentKind kind;

  const RichPostTextSegment._(this.text, this.kind);

  const RichPostTextSegment.plain(String text)
      : this._(text, RichPostTextSegmentKind.plain);

  const RichPostTextSegment.hashtag(String text)
      : this._(text, RichPostTextSegmentKind.hashtag);

  const RichPostTextSegment.mention(String text)
      : this._(text, RichPostTextSegmentKind.mention);

  bool get isInteractive => kind != RichPostTextSegmentKind.plain;
  bool get isHashtag => kind == RichPostTextSegmentKind.hashtag;
  bool get isMention => kind == RichPostTextSegmentKind.mention;
}

final RegExp richPostTextTokenPattern = RegExp(r'\B[#@]\w+');

List<RichPostTextSegment> parseRichPostTextSegments(String text) {
  if (text.isEmpty || (!text.contains('#') && !text.contains('@'))) {
    return <RichPostTextSegment>[RichPostTextSegment.plain(text)];
  }

  final segments = <RichPostTextSegment>[];
  int lastMatchEnd = 0;
  final matches = richPostTextTokenPattern.allMatches(text);

  for (final match in matches) {
    if (match.start > lastMatchEnd) {
      segments.add(
        RichPostTextSegment.plain(
          text.substring(lastMatchEnd, match.start),
        ),
      );
    }

    final token = match.group(0)!;
    segments.add(
      token.startsWith('#')
          ? RichPostTextSegment.hashtag(token)
          : RichPostTextSegment.mention(token),
    );
    lastMatchEnd = match.end;
  }

  if (lastMatchEnd < text.length) {
    segments.add(
      RichPostTextSegment.plain(text.substring(lastMatchEnd)),
    );
  }

  if (segments.isEmpty) {
    return <RichPostTextSegment>[RichPostTextSegment.plain(text)];
  }

  return segments;
}
