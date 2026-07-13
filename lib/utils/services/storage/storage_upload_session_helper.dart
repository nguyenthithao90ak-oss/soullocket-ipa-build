import 'package:cloud_functions/cloud_functions.dart';

import 'storage_upload_session_parser.dart';

typedef StorageCallableInvoker = Future<HttpsCallableResult<dynamic>> Function(
  String name,
  Map<String, dynamic> payload,
);

class StorageUploadSessionHelper {
  const StorageUploadSessionHelper();

  Future<Map<String, dynamic>> createUploadSession({
    required StorageCallableInvoker invokeCallable,
    required String functionName,
    required Map<String, dynamic> payload,
    required String label,
    bool requireSessionId = false,
  }) async {
    final response = await invokeCallable(functionName, payload);
    return parseUploadSessionResponse(
      response.data,
      label: label,
      requireSessionId: requireSessionId,
    );
  }
}
