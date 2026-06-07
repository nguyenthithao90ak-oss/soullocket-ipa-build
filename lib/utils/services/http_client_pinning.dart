import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' as http_io;
import '../app_error_mapper.dart';

/// SSL/TLS certificate public-key pinning for HTTP clients.
class PinnedHttpClient {
  PinnedHttpClient._({required this.pinnedSpkiFingerprints, this.timeoutSeconds = 30});

  static final PinnedHttpClient defaultInstance = PinnedHttpClient._(
    pinnedSpkiFingerprints: _defaultFingerprints,
  );

  factory PinnedHttpClient.withFingerprints(Set<String> fingerprints, {int timeoutSeconds = 30}) {
    return PinnedHttpClient._(
      pinnedSpkiFingerprints: fingerprints.map((f) => f.toUpperCase()).toSet(),
      timeoutSeconds: timeoutSeconds,
    );
  }

  static const Set<String> _defaultFingerprints = {
    '8Rw90Ej3Ttt8RRkrg+WYDS9n7IS03bk5C4p0BmU0vJ8=',
    'cGUXovM4MdUZcM1KcC7xOBfpIBi9Y+R1F/O6OM3N0mA=',
    'I9nJHIBQDf6AAYZVCjUZIzGAFQq7ZKKq6n16wM/YdY8=',
    'YCQcOOElQF2gUf/5Kew+PXhFWLGbBQO4P3jq4ytMX3c=',
  };

  final Set<String> pinnedSpkiFingerprints;
  final int timeoutSeconds;
  bool get isConfigured => pinnedSpkiFingerprints.isNotEmpty;

  Future<http.Response> get(Uri uri, {Map<String, String>? headers}) => _send('GET', uri, headers: headers);
  Future<http.Response> post(Uri uri, {Map<String, String>? headers, Object? body, Encoding? encoding}) =>
      _send('POST', uri, headers: headers, body: body, encoding: encoding);

  Future<http.Response> _send(String method, Uri uri, {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
    if (!isConfigured) throw StateError('SSL pinning is not configured.');
    final request = http.Request(method, uri);
    if (headers != null) request.headers.addAll(headers);
    if (body != null) request.bodyBytes = (encoding ?? utf8).encode(body.toString());
    final ioClient = _createIoClient();
    try {
      final streamedResponse = await ioClient.send(request).timeout(Duration(seconds: timeoutSeconds));
      return http.Response.fromStream(streamedResponse);
    } finally {
      ioClient.close();
    }
  }

  http.Client _createIoClient() {
    final securityContext = SecurityContext(withTrustedRoots: true);
    return http_io.IOClient(HttpClient(context: securityContext)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        final fingerprint = _spkiFingerprintOf(cert);
        if (fingerprint == null) { if (kDebugMode) debugPrint('[PinnedHttpClient] No SPKI for $host.'); return false; }
        final matched = pinnedSpkiFingerprints.contains(fingerprint);
        if (!matched && kDebugMode) debugPrint('[PinnedHttpClient] Pinning failed for $host: $fingerprint');
        return matched;
      });
  }

  String? _spkiFingerprintOf(X509Certificate cert) {
    try {
      final lines = const LineSplitter().convert(cert.pem);
      final derBytes = base64.decode(lines.where((l) => !l.startsWith('---')).join());
      final spki = _extractSpkiFromDer(derBytes);
      if (spki == null) return null;
      return base64.encode(sha256.convert(spki).bytes).toUpperCase();
    } catch (e) {
      if (kDebugMode) debugPrint('[PinnedHttpClient] Error: ${AppErrorMapper.resolve(e).message}');
      return null;
    }
  }

  Uint8List? _extractSpkiFromDer(Uint8List der) {
    try {
      final reader = _Asn1Reader(der);
      if (reader.readTag() != 0x30) return null;
      final certEnd = reader.offset + reader.readLength();
      if (certEnd > der.length) return null;
      if (reader.readTag() != 0x30) return null;
      final tbsEnd = reader.offset + reader.readLength();
      if (reader.offset < tbsEnd && der[reader.offset] == 0xA0) reader.skipTagged();
      for (int i = 0; i < 5 && reader.offset < tbsEnd; i++) reader.skipTlv();
      if (reader.offset >= tbsEnd || reader.readTag() != 0x30) return null;
      final spkiLen = reader.readLength();
      if (reader.offset + spkiLen > tbsEnd) return null;
      final spkiStart = reader.offset - 2 - _encodedLengthBytes(spkiLen);
      return der.sublist(spkiStart, reader.offset + spkiLen);
    } catch (_) { return null; }
  }

  int _encodedLengthBytes(int length) {
    if (length < 128) return 1;
    int numBytes = 1, tmp = length;
    while (tmp > 0) { tmp >>= 8; numBytes++; }
    return numBytes;
  }
}

class _Asn1Reader {
  final Uint8List _data;
  int offset;
  _Asn1Reader(this._data) : offset = 0;

  int readTag() { if (offset >= _data.length) throw 'end'; return _data[offset++] & 0xFF; }

  int readLength() {
    if (offset >= _data.length) throw 'end';
    final first = _data[offset++] & 0xFF;
    if (first < 0x80) return first;
    final numOctets = first & 0x7F;
    if (numOctets == 0 || numOctets > 4) throw 'bad length';
    int length = 0;
    for (int i = 0; i < numOctets; i++) { if (offset >= _data.length) throw 'end'; length = (length << 8) | (_data[offset++] & 0xFF); }
    return length;
  }

  void skipTlv() {
    if (offset >= _data.length) throw 'end';
    offset++;
    final len = _readLengthAt();
    offset += len;
    if (offset > _data.length) throw 'skip beyond data';
  }

  void skipTagged() {
    if (offset >= _data.length) throw 'end';
    offset++;
    final len = _readLengthAt();
    offset += len;
    if (offset > _data.length) throw 'skip beyond data';
  }

  int _readLengthAt() {
    final saved = offset;
    final first = _data[offset++] & 0xFF;
    if (first < 0x80) return first;
    final numOctets = first & 0x7F;
    if (numOctets == 0 || numOctets > 4) { offset = saved; throw 'bad length'; }
    int length = 0;
    for (int i = 0; i < numOctets; i++) { if (offset >= _data.length) { offset = saved; throw 'end'; } length = (length << 8) | (_data[offset++] & 0xFF); }
    return length;
  }
}