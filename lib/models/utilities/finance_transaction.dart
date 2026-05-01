// lib/models/utilities/finance_transaction.dart
class FinanceTransaction {
  final String id;
  final double amount;
  final String description;
  final String payerId; // 'U1' or 'U2' or split
  final String categoryId;
  final String type; // 'income' (nạp quỹ) or 'expense' (tiêu xài)
  final int timestamp;
  final String? receiptUrl; // Link ảnh hóa đơn (nếu có)

  FinanceTransaction({
    required this.id,
    required this.amount,
    required this.description,
    required this.payerId,
    required this.categoryId,
    required this.type,
    required this.timestamp,
    this.receiptUrl,
  });

  factory FinanceTransaction.fromMap(String id, Map<dynamic, dynamic> map) {
    return FinanceTransaction(
      id: id,
      amount: (map['amount'] ?? 0).toDouble(),
      description: map['desc'] ?? '',
      payerId: map['payerId'] ?? 'U1',
      categoryId: map['categoryId'] ?? 'general',
      type: map['type'] ?? 'expense',
      timestamp: map['ts'] ?? 0,
      receiptUrl: map['receiptUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'desc': description,
      'payerId': payerId,
      'categoryId': categoryId,
      'type': type,
      'ts': timestamp,
      if (receiptUrl != null) 'receiptUrl': receiptUrl,
    };
  }
}
