/// Central Services Barrel Export
/// Tập trung quản lý và xuất các Service theo kiến trúc mô-đun:
/// - Core Services (Đăng nhập, Kết nối mạng, Trạng thái online, Cơ sở dữ liệu)
/// - Infrastructure Services (Quảng cáo AdMob, Cloudflare R2, Thông báo, Telemetry)
/// - Feature Services (Love Insights, Bói bài Tarot, Ghép đôi, Âm nhạc, House)
library;

// ── CORE SERVICES ──────────────────────────────────────────────────────────
export 'core/auth_service.dart';
export 'core/connectivity_service.dart';
export 'core/presence_service.dart';
export 'core/background_tracking_service.dart';

// ── INFRASTRUCTURE SERVICES ────────────────────────────────────────────────
export 'infrastructure/admob_service.dart';
export 'infrastructure/cloudflare_r2_service.dart';
export 'infrastructure/storage_service.dart';

// ── FEATURE SERVICES ───────────────────────────────────────────────────────
export 'features/love_insight_service.dart';
export 'features/tarot_reading_service.dart';
