import 'purchase_service.dart';

/// Kho bí mật dùng đúng một nửa hạn mức kho ảnh Nhật ký/Kỷ niệm.
int secretVaultDailyBytes(VipAccessInfo plan) =>
    plan.dailyImageUploadLimitBytes ~/ 2;

int secretVaultTotalBytes(VipAccessInfo plan) =>
    (plan.totalMemoryStorageCapMb * 1024 * 1024) ~/ 2;

const int maxSecretVaultSelectionPerBatch = 10;
const int secretVaultPageSize = 60;
