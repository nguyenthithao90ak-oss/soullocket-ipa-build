import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../infrastructure/cloudflare_data_service.dart';

/// Thu/chi có trần 100 bản ghi: tải đủ một lần, không cộng tổng từ trang thiếu.
class FinanceD1Client {
  FinanceD1Client({
    CloudflareDataService? transport,
    String? Function()? currentUid,
  }) : _transport = transport ?? CloudflareDataService(),
       _currentUid =
           currentUid ?? (() => FirebaseAuth.instance.currentUser?.uid);
  final CloudflareDataService _transport;
  final String? Function() _currentUid;
  static final _id = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

  Future<Map<String, dynamic>> list(String houseId) async {
    final response = await _transport.readPage(
      houseId: houseId,
      resource: 'finance-ledger',
      parameters: {'limit': '100'},
    );
    final rows = response['data'];
    if (rows is! List || rows.length > 100 || response['complete'] != true) {
      throw const FormatException('Incomplete finance ledger');
    }
    final records = <String, dynamic>{};
    var income = 0, expense = 0;
    for (final row in rows) {
      if (row is! Map ||
          row['id'] is! String ||
          !_id.hasMatch(row['id'] as String) ||
          records.containsKey(row['id']) ||
          row['record'] is! Map) {
        throw const FormatException('Invalid finance ledger');
      }
      final record = Map<String, dynamic>.from(row['record'] as Map);
      final amount = record['amount'];
      if (amount is! int ||
          amount <= 0 ||
          amount > 9000000000000 ||
          (record['type'] != 'in' && record['type'] != 'out') ||
          record['ts'] is! int ||
          record['from'] is! String ||
          record['note'] is! String ||
          record['category'] is! String ||
          record['time'] is! String ||
          record['currency'] is! String ||
          record['timezone'] is! String ||
          record['date'] is! String) {
        throw const FormatException('Invalid finance record');
      }
      records[row['id'] as String] = record;
      if (record['type'] == 'in') {
        income += amount;
      } else {
        expense += amount;
      }
    }
    if (records.values.map((row) => (row as Map)['currency']).toSet().length >
        1) {
      throw const FormatException(
        'Mixed finance currencies require reconciliation',
      );
    }
    final totals = response['totals'];
    if (totals is! Map ||
        totals['income'] != income ||
        totals['expense'] != expense) {
      throw const FormatException('Invalid finance totals');
    }
    return records;
  }

  Future<void> create(String houseId, String id, Map<String, dynamic> record) =>
      _command(houseId, {'action': 'create', 'id': id, 'record': record});
  Future<void> delete(String houseId, String id) =>
      _command(houseId, {'action': 'delete', 'id': id});

  Future<void> _command(String houseId, Map<String, dynamic> body) async {
    final id = body['id'];
    if (id is! String || !_id.hasMatch(id)) {
      throw ArgumentError('Invalid finance id');
    }
    final uid = _currentUid();
    if (uid == null) throw FirebaseAuthException(code: 'user-token-expired');
    final key = sha256
        .convert(utf8.encode(jsonEncode([uid, houseId, body])))
        .toString();
    final result = await _transport.write(
      houseId: houseId,
      resource: 'finance-ledger',
      body: body,
      idempotencyKey: key,
    );
    if (result['id'] != id ||
        (body['action'] == 'delete' && result['deleted'] != true)) {
      throw const FormatException('Invalid finance write receipt');
    }
  }

  void dispose() => _transport.dispose();
}
