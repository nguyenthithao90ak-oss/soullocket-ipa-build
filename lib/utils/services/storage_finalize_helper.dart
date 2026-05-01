import 'package:cloud_functions/cloud_functions.dart';

import 'storage_upload_session_parser.dart';

typedef StorageFinalizeInvoker = Future<HttpsCallableResult<dynamic>> Function(
  String name,
  Map<String, dynamic> payload,
);

class StorageFinalizeHelper {
  const StorageFinalizeHelper();

  Future<Map<String, dynamic>> finalizeUpload({
    required StorageFinalizeInvoker invokeCallable,
    required String functionName,
    required Map<String, dynamic> payload,
    required String label,
  }) async {
    final response = await invokeCallable(functionName, payload);
    return parseFinalizeResponse(
      response.data,
      label: label,
    );
  }

  Future<Map<String, dynamic>> invokeMapResult({
    required StorageFinalizeInvoker invokeCallable,
    required String functionName,
    required Map<String, dynamic> payload,
    required String invalidResponseMessage,
  }) async {
    final response = await invokeCallable(functionName, payload);
    final data = response.data;
    if (data is! Map) {
      throw Exception(invalidResponseMessage);
    }
    return Map<String, dynamic>.from(data);
  }
}
