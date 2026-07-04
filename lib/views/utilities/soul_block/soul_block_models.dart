part of '../soul_block_game.dart';

class _SoulTile {
  const _SoulTile({
    required this.toneIndex,
    required this.pieceId,
    required this.placedTurn,
  });

  final int toneIndex;
  final int pieceId;
  final int placedTurn;
}

class _SoulPieceOption {
  const _SoulPieceOption({
    required this.id,
    required this.template,
    required this.toneIndex,
    this.isGold = false,
    this.isBomb = false,
  });

  final int id;
  final _SoulPieceTemplate template;
  final int toneIndex;
  final bool isGold;
  final bool isBomb;
}

class _SoulPieceTemplate {
  const _SoulPieceTemplate({
    required this.id,
    required this.label,
    required this.cells,
    required this.tier,
    required this.width,
    required this.height,
    required this.cellCount,
  });

  final String id;
  final String label;
  final List<Point<int>> cells;
  final int tier;
  final int width;
  final int height;
  final int cellCount;

  static final Map<String, ({int width, int height, int cellCount})>
      _metadataCache = <String, ({int width, int height, int cellCount})>{};
  static final Map<String, Set<int>> _cellKeyCache = <String, Set<int>>{};

  ({int width, int height, int cellCount}) get metadata =>
      _metadataCache[id] ??=
          (width: width, height: height, cellCount: cellCount);

  Set<int> get cellKeySet => _cellKeyCache[id] ??= cells
      .map((Point<int> cell) => (cell.x << 16) ^ (cell.y & 0xFFFF))
      .toSet();

  _SoulPieceTemplate rotate() {
    final rotatedCells = cells.map((p) => Point<int>(-p.y, p.x)).toList();
    final minX = rotatedCells.map((p) => p.x).reduce(min);
    final minY = rotatedCells.map((p) => p.y).reduce(min);
    final normalizedCells =
        rotatedCells.map((p) => Point<int>(p.x - minX, p.y - minY)).toList();

    final newWidth = normalizedCells.map((p) => p.x).reduce(max) + 1;
    final newHeight = normalizedCells.map((p) => p.y).reduce(max) + 1;

    return _SoulPieceTemplate(
      id: id,
      label: label,
      cells: normalizedCells,
      tier: tier,
      width: newWidth,
      height: newHeight,
      cellCount: cellCount,
    );
  }
}

class _PlacementEval {
  const _PlacementEval({
    required this.row,
    required this.col,
    required this.clearedLines,
    required this.heuristic,
    required this.boardAfter,
  });

  final int row;
  final int col;
  final int clearedLines;
  final double heuristic;
  final List<List<bool>> boardAfter;
}

class _PlacementResolution {
  const _PlacementResolution({
    required this.board,
    required this.occupiedCells,
    required this.rowsToClear,
    required this.colsToClear,
  });

  final List<List<_SoulTile?>> board;
  final List<Point<int>> occupiedCells;
  final Set<int> rowsToClear;
  final Set<int> colsToClear;
}

class _LineClearResolution {
  const _LineClearResolution({
    required this.board,
    required this.clearedRows,
    required this.clearedCols,
  });

  final List<List<_SoulTile?>> board;
  final Set<int> clearedRows;
  final Set<int> clearedCols;
}

class _TemplateScore {
  const _TemplateScore({
    required this.template,
    required this.bestHeuristic,
    required this.playableCount,
  });

  final _SoulPieceTemplate template;
  final double bestHeuristic;
  final int playableCount;
}

class _BatchChoice {
  const _BatchChoice({
    required this.templates,
    required this.score,
  });

  final List<_SoulPieceTemplate> templates;
  final double score;
}

class _RecommendedMove {
  const _RecommendedMove({
    required this.pieceId,
    required this.row,
    required this.col,
    required this.heuristic,
    required this.expectedGain,
    required this.clearCount,
  });

  final int pieceId;
  final int row;
  final int col;
  final double heuristic;
  final int expectedGain;
  final int clearCount;
}

class _PreparedSoulRun {
  const _PreparedSoulRun({
    required this.board,
    required this.tray,
    required this.recommendedMove,
    required this.sessionId,
    this.holdPiece,
    this.boardSize,
  });

  final List<List<_SoulTile?>> board;
  final List<_SoulPieceOption> tray;
  final _RecommendedMove? recommendedMove;
  final int sessionId;
  final _SoulPieceOption? holdPiece;
  final int? boardSize;
}

class _LeaderboardEntry {
  const _LeaderboardEntry({
    required this.sessionId,
    required this.score,
    required this.lines,
    required this.timestampMs,
  });

  final int sessionId;
  final int score;
  final int lines;
  final int timestampMs;
  static final Map<int, String> _stampLabelCache = <int, String>{};

  factory _LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return _LeaderboardEntry(
      sessionId: (json['sessionId'] as num?)?.toInt() ?? 0,
      score: (json['score'] as num?)?.toInt() ?? 0,
      lines: (json['lines'] as num?)?.toInt() ?? 0,
      timestampMs: (json['timestampMs'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'sessionId': sessionId,
      'score': score,
      'lines': lines,
      'timestampMs': timestampMs,
    };
  }

  String get stampLabel =>
      _stampLabelCache[timestampMs] ??= _formatStampLabel(timestampMs);

  static String _formatStampLabel(int timestampMs) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month - $hour:$minute';
  }
}

class _SoulSfxTone {
  const _SoulSfxTone({
    required this.frequency,
    required this.durationMs,
    required this.volume,
    this.noiseMix = 0,
  });

  final double frequency;
  final int durationMs;
  final double volume;
  final double noiseMix;
}

class _ExplosionParticle {
  const _ExplosionParticle({
    required this.startOffset,
    required this.endOffset,
    required this.color,
    required this.size,
    required this.rotation,
    required this.twist,
    required this.opacity,
    required this.delayFraction,
    required this.isShard,
    required this.simpleDraw,
  });

  final Offset startOffset;
  final Offset endOffset;
  final Color color;
  final double size;
  final double rotation;
  final double twist;
  final double opacity;
  final double delayFraction;
  final bool isShard;
  final bool simpleDraw;
}

class _MemoryBurstSnapshot {
  const _MemoryBurstSnapshot({
    required this.imageUrl,
    required this.label,
    required this.subtitle,
    required this.accent,
  });

  final String imageUrl;
  final String label;
  final String subtitle;
  final Color accent;
}

enum _SoulBlockPerformanceTier {
  low,
  mid,
  high,
}

class _SoulBlockPerformanceProfile {
  const _SoulBlockPerformanceProfile({
    required this.tier,
    required this.maxImageDevicePixelRatio,
    required this.maxImageCacheWidth,
    required this.maxImageCacheHeight,
    required this.subtleParticleCap,
    required this.strongParticleCap,
    required this.subtleDistanceScale,
    required this.strongDistanceScale,
    required this.opacityScale,
    required this.delayScale,
    required this.memoryBurstSparkleCount,
    required this.memoryBurstShadowScale,
    required this.memoryBurstRotationScale,
    required this.memoryBurstScaleBoost,
    required this.memoryBurstWarmLimit,
  });

  final _SoulBlockPerformanceTier tier;
  final double maxImageDevicePixelRatio;
  final int maxImageCacheWidth;
  final int maxImageCacheHeight;
  final int subtleParticleCap;
  final int strongParticleCap;
  final double subtleDistanceScale;
  final double strongDistanceScale;
  final double opacityScale;
  final double delayScale;
  final int memoryBurstSparkleCount;
  final double memoryBurstShadowScale;
  final double memoryBurstRotationScale;
  final double memoryBurstScaleBoost;
  final int memoryBurstWarmLimit;

  static const _SoulBlockPerformanceProfile low = _SoulBlockPerformanceProfile(
    tier: _SoulBlockPerformanceTier.low,
    maxImageDevicePixelRatio: 1.2,
    maxImageCacheWidth: 420,
    maxImageCacheHeight: 500,
    subtleParticleCap: 4,
    strongParticleCap: 5,
    subtleDistanceScale: 0.78,
    strongDistanceScale: 0.82,
    opacityScale: 0.84,
    delayScale: 0.78,
    memoryBurstSparkleCount: 0,
    memoryBurstShadowScale: 0.0,
    memoryBurstRotationScale: 0.35,
    memoryBurstScaleBoost: 0.12,
    memoryBurstWarmLimit: 1,
  );

  static const _SoulBlockPerformanceProfile mid = _SoulBlockPerformanceProfile(
    tier: _SoulBlockPerformanceTier.mid,
    maxImageDevicePixelRatio: 1.6,
    maxImageCacheWidth: 540,
    maxImageCacheHeight: 620,
    subtleParticleCap: 5,
    strongParticleCap: 7,
    subtleDistanceScale: 0.92,
    strongDistanceScale: 0.94,
    opacityScale: 0.92,
    delayScale: 0.90,
    memoryBurstSparkleCount: 2,
    memoryBurstShadowScale: 0.58,
    memoryBurstRotationScale: 0.65,
    memoryBurstScaleBoost: 0.17,
    memoryBurstWarmLimit: 2,
  );

  static const _SoulBlockPerformanceProfile high = _SoulBlockPerformanceProfile(
    tier: _SoulBlockPerformanceTier.high,
    maxImageDevicePixelRatio: 2.0,
    maxImageCacheWidth: 640,
    maxImageCacheHeight: 720,
    subtleParticleCap: 6,
    strongParticleCap: 8,
    subtleDistanceScale: 1.0,
    strongDistanceScale: 1.0,
    opacityScale: 1.0,
    delayScale: 1.0,
    memoryBurstSparkleCount: 4,
    memoryBurstShadowScale: 1.0,
    memoryBurstRotationScale: 1.0,
    memoryBurstScaleBoost: 0.22,
    memoryBurstWarmLimit: 4,
  );
}

const Color _kSoulStageTop = Color(0xFF0B1022);
const Color _kSoulStageMid = Color(0xFF16244F);
const Color _kSoulStageBottom = Color(0xFF050814);
const Color _kSoulPanelTop = Color(0xFF314A9C);
const Color _kSoulPanelMid = Color(0xFF1A2F73);
const Color _kSoulPanelBottom = Color(0xFF0A1436);
const Color _kSoulBoardTop = Color(0xFF1A3270);
const Color _kSoulBoardMid = Color(0xFF101F49);
const Color _kSoulBoardBottom = Color(0xFF060C22);
const Color _kSoulChrome = Color(0xFFDCE7FF);
const Color _kSoulIvory = Color(0xFFF7FAFF);

const List<Color> _kSoulTones = <Color>[
  Color(0xFF5B8CFF),
  Color(0xFF36D1FF),
  Color(0xFF45E0B8),
  Color(0xFF8C6CFF),
  Color(0xFFFF6FAE),
  Color(0xFFFFA24D),
  Color(0xFFFFD85E),
  Color(0xFF8CE35F),
];

const List<Color> _kSoulBurstPalette = <Color>[
  Color(0xFFD8E4FF),
  Color(0xFF8CC7FF),
  Color(0xFF8DF5E0),
  Color(0xFFC3A7FF),
  Color(0xFFFFA8CF),
  Color(0xFFFFC07B),
  Color(0xFFFFE59A),
  Color(0xFFAAF29A),
];

const List<_SoulPieceTemplate> _kSoulBlockTemplates = <_SoulPieceTemplate>[
  _SoulPieceTemplate(
    id: 'single',
    label: 'Single',
    cells: <Point<int>>[Point<int>(0, 0)],
    tier: 0,
    width: 1,
    height: 1,
    cellCount: 1,
  ),
  _SoulPieceTemplate(
    id: 'duo_h',
    label: 'Duo H',
    cells: <Point<int>>[
      Point<int>(0, 0),
      Point<int>(1, 0),
    ],
    tier: 0,
    width: 2,
    height: 1,
    cellCount: 2,
  ),
  _SoulPieceTemplate(
    id: 'duo_v',
    label: 'Duo V',
    cells: <Point<int>>[
      Point<int>(0, 0),
      Point<int>(0, 1),
    ],
    tier: 0,
    width: 1,
    height: 2,
    cellCount: 2,
  ),
  _SoulPieceTemplate(
    id: 'tri_h',
    label: 'Line 3 H',
    cells: <Point<int>>[
      Point<int>(0, 0),
      Point<int>(1, 0),
      Point<int>(2, 0),
    ],
    tier: 0,
    width: 3,
    height: 1,
    cellCount: 3,
  ),
  _SoulPieceTemplate(
    id: 'tri_v',
    label: 'Line 3 V',
    cells: <Point<int>>[
      Point<int>(0, 0),
      Point<int>(0, 1),
      Point<int>(0, 2),
    ],
    tier: 0,
    width: 1,
    height: 3,
    cellCount: 3,
  ),
  _SoulPieceTemplate(
    id: 'square_2',
    label: 'Square 2',
    cells: <Point<int>>[
      Point<int>(0, 0),
      Point<int>(1, 0),
      Point<int>(0, 1),
      Point<int>(1, 1),
    ],
    tier: 0,
    width: 2,
    height: 2,
    cellCount: 4,
  ),
  _SoulPieceTemplate(
    id: 'l_small',
    label: 'L Small',
    cells: <Point<int>>[
      Point<int>(0, 0),
      Point<int>(0, 1),
      Point<int>(1, 1),
    ],
    tier: 0,
    width: 2,
    height: 2,
    cellCount: 3,
  ),
  _SoulPieceTemplate(
    id: 'line_4_h',
    label: 'Line 4 H',
    cells: <Point<int>>[
      Point<int>(0, 0),
      Point<int>(1, 0),
      Point<int>(2, 0),
      Point<int>(3, 0),
    ],
    tier: 1,
    width: 4,
    height: 1,
    cellCount: 4,
  ),
  _SoulPieceTemplate(
    id: 'line_4_v',
    label: 'Line 4 V',
    cells: <Point<int>>[
      Point<int>(0, 0),
      Point<int>(0, 1),
      Point<int>(0, 2),
      Point<int>(0, 3),
    ],
    tier: 1,
    width: 1,
    height: 4,
    cellCount: 4,
  ),
  _SoulPieceTemplate(
    id: 'l_tall',
    label: 'L Tall',
    cells: <Point<int>>[
      Point<int>(0, 0),
      Point<int>(0, 1),
      Point<int>(0, 2),
      Point<int>(1, 2),
    ],
    tier: 1,
    width: 2,
    height: 3,
    cellCount: 4,
  ),
  _SoulPieceTemplate(
    id: 'l_tall_r',
    label: 'L Tall R',
    cells: <Point<int>>[
      Point<int>(1, 0),
      Point<int>(1, 1),
      Point<int>(1, 2),
      Point<int>(0, 2),
    ],
    tier: 1,
    width: 2,
    height: 3,
    cellCount: 4,
  ),
  _SoulPieceTemplate(
    id: 't_cap',
    label: 'T',
    cells: <Point<int>>[
      Point<int>(0, 0),
      Point<int>(1, 0),
      Point<int>(2, 0),
      Point<int>(1, 1),
    ],
    tier: 1,
    width: 3,
    height: 2,
    cellCount: 4,
  ),
  _SoulPieceTemplate(
    id: 'zig',
    label: 'Zig',
    cells: <Point<int>>[
      Point<int>(0, 0),
      Point<int>(1, 0),
      Point<int>(1, 1),
      Point<int>(2, 1),
    ],
    tier: 1,
    width: 3,
    height: 2,
    cellCount: 4,
  ),
  _SoulPieceTemplate(
    id: 'zag',
    label: 'Zag',
    cells: <Point<int>>[
      Point<int>(1, 0),
      Point<int>(2, 0),
      Point<int>(0, 1),
      Point<int>(1, 1),
    ],
    tier: 1,
    width: 3,
    height: 2,
    cellCount: 4,
  ),
  _SoulPieceTemplate(
    id: 'line_5_h',
    label: 'Line 5 H',
    cells: <Point<int>>[
      Point<int>(0, 0),
      Point<int>(1, 0),
      Point<int>(2, 0),
      Point<int>(3, 0),
      Point<int>(4, 0),
    ],
    tier: 2,
    width: 5,
    height: 1,
    cellCount: 5,
  ),
  _SoulPieceTemplate(
    id: 'line_5_v',
    label: 'Line 5 V',
    cells: <Point<int>>[
      Point<int>(0, 0),
      Point<int>(0, 1),
      Point<int>(0, 2),
      Point<int>(0, 3),
      Point<int>(0, 4),
    ],
    tier: 2,
    width: 1,
    height: 5,
    cellCount: 5,
  ),
  _SoulPieceTemplate(
    id: 'plus_5',
    label: 'Plus',
    cells: <Point<int>>[
      Point<int>(1, 0),
      Point<int>(0, 1),
      Point<int>(1, 1),
      Point<int>(2, 1),
      Point<int>(1, 2),
    ],
    tier: 2,
    width: 3,
    height: 3,
    cellCount: 5,
  ),
  _SoulPieceTemplate(
    id: 'square_3',
    label: 'Square 3',
    cells: <Point<int>>[
      Point<int>(0, 0),
      Point<int>(1, 0),
      Point<int>(2, 0),
      Point<int>(0, 1),
      Point<int>(1, 1),
      Point<int>(2, 1),
      Point<int>(0, 2),
      Point<int>(1, 2),
      Point<int>(2, 2),
    ],
    tier: 2,
    width: 3,
    height: 3,
    cellCount: 9,
  ),
];
