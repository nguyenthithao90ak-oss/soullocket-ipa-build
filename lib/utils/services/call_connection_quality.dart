import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_webrtc/flutter_webrtc.dart';

enum CallConnectionRoute { unknown, direct, relay }

enum CallVideoQuality { low, medium, high }

/// Số liệu cục bộ, không chứa IP, SDP hoặc credential và không gửi lên server.
/// Byte RTP là dữ liệu media; không dùng làm hóa đơn chính xác của TURN.
class CallConnectionQuality {
  const CallConnectionQuality({
    this.route = CallConnectionRoute.unknown,
    this.roundTripMs,
    this.lossFraction,
    this.availableOutgoingBitrate,
    this.sentBytes = 0,
    this.receivedBytes = 0,
    this.sentBitrate,
    this.receivedBitrate,
  });
  final CallConnectionRoute route;
  final double? roundTripMs;
  final double? lossFraction;
  final double? availableOutgoingBitrate;
  final int sentBytes;
  final int receivedBytes;
  final double? sentBitrate;
  final double? receivedBitrate;
}

class CallStatsAccumulator {
  final Map<String, Map<String, double?>> _previous = {};
  final Map<String, Duration> _lastSeen = {};
  int _sent = 0;
  int _received = 0;

  CallConnectionQuality sample(List<StatsReport> reports, Duration elapsed) {
    final current = {for (final r in reports) r.id: r.values};
    Map? pair;
    for (final report in reports.where((r) => r.type == 'transport')) {
      final selected = current[report.values['selectedCandidatePairId']];
      if (selected != null && selected['state'] == 'succeeded') pair = selected;
    }
    if (pair == null) {
      final selected = reports.where(
        (r) =>
            r.type == 'candidate-pair' &&
            r.values['state'] == 'succeeded' &&
            (r.values['selected'] == true || r.values['nominated'] == true),
      );
      // Nhiều cặp được đề cử chưa chứng minh cặp nào đang truyền media.
      if (selected.length == 1) pair = selected.single.values;
    }
    final localType = current[pair?['localCandidateId']]?['candidateType'];
    final remoteType = current[pair?['remoteCandidateId']]?['candidateType'];
    final route = localType == 'relay' || remoteType == 'relay'
        ? CallConnectionRoute.relay
        : const {'host', 'srflx', 'prflx'}.contains(localType) &&
              const {'host', 'srflx', 'prflx'}.contains(remoteType)
        ? CallConnectionRoute.direct
        : CallConnectionRoute.unknown;
    var sentDelta = 0;
    var receivedDelta = 0;
    double? sentRate;
    double? receivedRate;
    var receivedPackets = 0;
    var lostPackets = 0;
    double? outboundLoss;
    var hasPacketDelta = false;
    for (final report in reports) {
      final value = report.values;
      final old = _previous[report.id];
      final lastSeen = _lastSeen[report.id];
      final seconds = lastSeen == null
          ? null
          : (elapsed - lastSeen).inMicroseconds / 1000000;
      int delta(String field, {bool bytes = false}) {
        final n = _number(value[field]);
        final p = _number(old?[field]);
        if (n == null) return 0;
        if (p == null || n < p) return bytes ? n.toInt() : 0;
        return (n - p).toInt();
      }

      if (report.type == 'outbound-rtp' && value['isRemote'] != true) {
        final bytes = delta('bytesSent', bytes: true);
        sentDelta += bytes;
        if (seconds != null && seconds > 0) {
          sentRate = (sentRate ?? 0) + bytes * 8 / seconds;
        }
      } else if (report.type == 'inbound-rtp' && value['isRemote'] != true) {
        final bytes = delta('bytesReceived', bytes: true);
        receivedDelta += bytes;
        if (seconds != null && seconds > 0) {
          receivedRate = (receivedRate ?? 0) + bytes * 8 / seconds;
        }
        final packets = delta('packetsReceived');
        final lost = delta('packetsLost');
        receivedPackets += packets;
        lostPackets += lost;
        hasPacketDelta |= packets + lost > 0;
      } else if (report.type == 'remote-inbound-rtp') {
        final loss = _number(value['fractionLost']);
        if (loss != null && loss >= 0 && loss <= 1) {
          outboundLoss = math.max(outboundLoss ?? 0, loss);
        }
      }
      if (report.type == 'outbound-rtp' || report.type == 'inbound-rtp') {
        // Chỉ giữ counter; không lưu IP/candidate hay payload của báo cáo.
        _previous[report.id] = {
          for (final field in [
            'bytesSent',
            'bytesReceived',
            'packetsReceived',
            'packetsLost',
          ])
            field: _number(value[field]),
        };
        _lastSeen[report.id] = elapsed;
      }
    }
    _sent += sentDelta;
    _received += receivedDelta;
    final inboundLoss = hasPacketDelta
        ? lostPackets / (receivedPackets + lostPackets)
        : null;
    final loss = inboundLoss == null
        ? outboundLoss
        : math.max(inboundLoss, outboundLoss ?? 0);
    return CallConnectionQuality(
      route: route,
      roundTripMs: _number(pair?['currentRoundTripTime']) == null
          ? null
          : _number(pair?['currentRoundTripTime'])! * 1000,
      lossFraction: loss,
      availableOutgoingBitrate: _number(pair?['availableOutgoingBitrate']),
      sentBytes: _sent,
      receivedBytes: _received,
      sentBitrate: sentRate,
      receivedBitrate: receivedRate,
    );
  }

  static double? _number(Object? value) {
    final n = value is num
        ? value.toDouble()
        : value is String
        ? double.tryParse(value)
        : null;
    return n != null && n.isFinite && n >= 0 ? n : null;
  }
}

/// Giảm sau hai mẫu xấu, tăng từng nấc sau năm mẫu tốt (chu kỳ 3 giây).
class CallVideoAdaptation {
  CallVideoQuality quality = CallVideoQuality.medium;
  int _bad = 0;
  int _good = 0;
  CallVideoQuality update(CallConnectionQuality stats) {
    final bandwidth = stats.availableOutgoingBitrate;
    final loss = stats.lossFraction;
    final rtt = stats.roundTripMs;
    final poor =
        (bandwidth != null && bandwidth < 400000) ||
        (loss != null && loss >= .08) ||
        (rtt != null && rtt >= 650);
    final good =
        bandwidth != null &&
        bandwidth >= 1400000 &&
        loss != null &&
        loss < .025 &&
        rtt != null &&
        rtt < 250;
    _bad = poor ? _bad + 1 : 0;
    _good = good ? _good + 1 : 0;
    if (_bad >= 2) {
      quality = CallVideoQuality.low;
      _bad = _good = 0;
    } else if (_good >= 5 && quality != CallVideoQuality.high) {
      quality = CallVideoQuality.values[quality.index + 1];
      _bad = _good = 0;
    }
    return quality;
  }
}

/// getStats tuần tự, không chồng lời gọi native nếu một lượt trả về chậm.
class CallQualityMonitor {
  CallQualityMonitor({
    required this.read,
    required this.isCurrent,
    required this.onSample,
  });
  final Future<List<StatsReport>> Function() read;
  final bool Function() isCurrent;
  final Future<void> Function(CallConnectionQuality) onSample;
  final _clock = Stopwatch();
  final _accumulator = CallStatsAccumulator();
  Timer? _timer;
  bool _closed = false;
  void start() {
    if (_closed || _clock.isRunning) return;
    _clock.start();
    _timer = Timer(Duration.zero, _poll);
  }

  Future<void> _poll() async {
    if (_closed || !isCurrent()) return;
    try {
      final reports = await read();
      if (!_closed && isCurrent()) {
        await onSample(_accumulator.sample(reports, _clock.elapsed));
      }
    } catch (_) {
      // Stats/encoder không được làm gián đoạn phần thoại.
    } finally {
      if (!_closed && isCurrent()) {
        _timer = Timer(const Duration(seconds: 3), _poll);
      }
    }
  }

  void close() {
    _closed = true;
    _timer?.cancel();
    _clock.stop();
  }
}
