# soullocket_app

> AI agents: read `AGENTS.md` before analyzing or modifying this repository.

> AI note (vi): Mọi AI phải đọc `AGENTS.md` ở thư mục gốc trước khi sửa code và phải tuân thủ tuyệt đối.

Ứng dụng Flutter của SoulLocket.

## Cấu hình môi trường

1. Tạo file `.env.local.json` từ `env.example.json`.
2. Điền đầy đủ các biến Firebase, reCAPTCHA, Gemini proxy, Google Maps và Telegram relay nếu có dùng.
3. Giá trị `FIREBASE_APP_ID` là biến theo nền tảng: web dùng Web App ID, còn Android hoặc iOS chỉ dùng App ID native khi app phải fallback sang khởi tạo Firebase từ env.
4. Không commit file env thật, `android/key.properties`, `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist` hoặc keystore thật vào repo.

Ví dụ:

```json
{
  "FIREBASE_API_KEY": "your-firebase-api-key",
  "FIREBASE_AUTH_DOMAIN": "your-project.firebaseapp.com",
  "FIREBASE_DATABASE_URL": "https://your-project-default-rtdb.firebaseio.com",
  "FIREBASE_PROJECT_ID": "your-project-id",
  "FIREBASE_STORAGE_BUCKET": "your-project.appspot.com",
  "FIREBASE_MESSAGING_SENDER_ID": "123456789000",
  "FIREBASE_APP_ID": "your-platform-specific-firebase-app-id",
  "FIREBASE_MEASUREMENT_ID": "G-XXXXXXXXXX",
  "RECAPTCHA_V3_SITE_KEY": "your-recaptcha-v3-site-key",
  "GEMINI_PROXY_URL": "https://your-secure-ai-proxy.example.com/generate",
  "GEMINI_MODEL": "gemini-1.5-flash",
  "GOOGLE_MAPS_API_KEY": "your-google-maps-api-key",
  "PURCHASE_VERIFY_URL": "https://us-central1-soullockket.cloudfunctions.net/verifyPurchase",
  "TELEGRAM_ALERTS_RELAY_URL": "https://us-central1-your-project.cloudfunctions.net/relayTelegramAlert"
}
```

Quy ước nên dùng:

- Build web: `FIREBASE_APP_ID` phải là Web App ID
- Build Android: nếu đã có `android/app/google-services.json`, app sẽ ưu tiên cấu hình native; nếu không có và phải fallback sang env thì `FIREBASE_APP_ID` phải là App ID Android
- Build iOS: nếu sau này có `ios/Runner/GoogleService-Info.plist`, app nên ưu tiên cấu hình native; nếu fallback sang env thì `FIREBASE_APP_ID` phải là App ID iOS

## Chạy ứng dụng

### Android

```bash
flutter run --dart-define-from-file=.env.local.json
```

### Web

```bash
flutter run -d chrome --web-port 8080 --dart-define-from-file=.env.local.json
```

## Tài liệu nhanh

- `docs/firebase_release_checklist.md`: checklist preflight/deploy Firebase Hosting.
- `docs/ios_release_checklist.md`: checklist phát hành iOS/TestFlight/App Store.
- `docs/app_review_notes.md`: mẫu note cho App Review.
- `docs/release_quickstart.md`: luồng chạy nhanh cho release owner.
- `docs/repo_hygiene_checklist.md`: checklist hygiene/artifact/secrets trong repo.

## Build release

Release phải dùng cùng nguồn cấu hình `dart-define` với runtime:

### Android release checklist

Trước khi build Android release, cần chuẩn bị đủ các file sau:

- `android/key.properties` tạo từ `android/key.properties.example`
- `android/app/upload-keystore.jks` đúng file ký upload
- `android/app/google-services.json` đúng app production nếu có dùng Firebase hoặc Google Sign-In
- `.env.local.json` có đủ `GOOGLE_MAPS_API_KEY` và bộ biến `FIREBASE_*` khi không dùng `google-services.json`

Nếu dùng Google Sign-In trên Android, nên ưu tiên cấu hình `android/app/google-services.json` đúng SHA-1 và SHA-256 production trong Firebase. Chỉ truyền `dart-define` là chưa đủ để thay thế hoàn toàn cấu hình native cho đăng nhập Google.

### Android APK

```bash
flutter build apk --release --dart-define-from-file=.env.local.json
```

### Android App Bundle

```bash
flutter build appbundle --release --dart-define-from-file=.env.local.json
```

### Web

```bash
flutter build web --release --dart-define-from-file=.env.local.json
```

### iOS qua GitHub Actions

Repo đã có workflow build iOS ký thật tại `.github/workflows/ios-ipa.yml`.
Workflow này chạy bằng `workflow_dispatch` để tránh tốn phút macOS không cần thiết.

Cần tạo các GitHub Secrets sau trước khi build:

- `IOS_TEAM_ID`
- `P12_BASE64`
- `P12_PASSWORD`
- `KEYCHAIN_PASSWORD`
- `RUNNER_PROVISIONING_PROFILE_BASE64`
- `WIDGET_PROVISIONING_PROFILE_BASE64`

Nen them cac secret sau neu app production cua ban khac gia tri mac dinh:

- `IOS_BUNDLE_ID`
- `IOS_WIDGET_BUNDLE_ID`
- `IOS_RUNNER_TESTS_BUNDLE_ID`
- `IOS_APP_GROUP_ID`
- `IOS_ASSOCIATED_DOMAIN_WEB`
- `IOS_ASSOCIATED_DOMAIN_AUTH`
- `ENV_LOCAL_JSON_BASE64`

Ghi chu:

- `ENV_LOCAL_JSON_BASE64` la noi dung base64 cua file `.env.local.json`
- workflow se tu sinh file `ios/Flutter/AppConfig.local.xcconfig` cho CI
- workflow sẽ import cert + 2 provisioning profile, sau đó xuất `IPA` đã ký
- app hiện có `Widget Extension`, nên profile cho `Runner` và `SoulLocketWidget` phải đúng bundle id
- workflow mới cho phép override `build_name` và `build_number` khi cần đồng bộ với App Store Connect

Những mục iOS vẫn cần kiểm tra thủ công trên Apple Developer / Firebase:

- URL scheme cho Google Sign-In tren `Info.plist`
- APNs / Push Notifications capability neu muon push iOS hoat dong that
- App Groups va Associated Domains phai duoc tao dung tren Apple Developer
- xem them tai lieu submit iOS tai `docs/ios_release_checklist.md` va `docs/app_review_notes.md`

## Deploy host

Quick start trước khi deploy:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\release_smoke_check.ps1
```

Nếu muốn check luôn thư mục build/public của hosting target:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\release_smoke_check.ps1 -CheckBuildOutput
```

Hosting web dùng biến môi trường ở bước build, không đọc env runtime sau khi đã upload file tĩnh. Vì vậy mỗi lần deploy host phải build bằng đúng file `.env.local.json`.

Flutter web của dự án đang chạy bằng CanvasKit trong `web/flutter_bootstrap.js`, nên ảnh từ Firebase Storage cần bucket CORS đúng thì mới render ổn định trên web.

Trước khi deploy lần đầu hoặc khi token Firebase hết hạn, hãy đăng nhập lại:

```powershell
firebase login --reauth
```

### Xác thực env trước khi deploy

```powershell
powershell -ExecutionPolicy Bypass -File .\DEPLOY_HOSTING.ps1 -ValidateOnly
```

### Build và deploy Firebase Hosting

```powershell
powershell -ExecutionPolicy Bypass -File .\DEPLOY_HOSTING.ps1
```

Script sẽ:
- đọc `.env.local.json`
- kiểm tra các biến bắt buộc cho web hosting
- build `flutter build web --release --dart-define-from-file=.env.local.json`
- deploy lên Firebase Hosting bằng `FIREBASE_PROJECT_ID` trong env file

Nếu muốn ghi đè project deploy:

```powershell
powershell -ExecutionPolicy Bypass -File .\DEPLOY_HOSTING.ps1 -ProjectId your-firebase-project-id
```

Nếu build Android release mà thiếu `GOOGLE_MAPS_API_KEY`, hoặc thiếu bộ biến Firebase trong lúc cũng không có `android/app/google-services.json`, quá trình build sẽ dừng sớm để tránh tạo gói release lỗi cấu hình.

### Áp dụng CORS cho Firebase Storage

File `firebase-storage-cors.json` đã có sẵn cấu hình cho phép web đọc ảnh bằng `GET`, `HEAD`, `OPTIONS`. Cấu hình mặc định dùng `origin: ["*"]` để tránh lỗi ảnh không hiện trên nhiều domain web khác nhau. Nếu muốn siết chặt hơn, hãy sửa lại danh sách origin trước khi áp dụng.

Xem trước bucket và payload CORS:

```powershell
powershell -ExecutionPolicy Bypass -File .\APPLY_STORAGE_CORS.ps1 -DryRun
```

Áp dụng thật với service account có quyền cập nhật bucket metadata:

```powershell
powershell -ExecutionPolicy Bypass -File .\APPLY_STORAGE_CORS.ps1 -KeyFile C:\path\to\storage-admin.json
```

Hoặc chạy trực tiếp qua npm:

```bash
npm run storage:cors -- --env-file=.env.local.json --key-file=C:/path/to/storage-admin.json
```

Script sẽ tự lấy `FIREBASE_STORAGE_BUCKET` từ `.env.local.json` nếu không truyền `--bucket`. Sau khi áp dụng CORS, build lại web và deploy hosting để kiểm tra ảnh đã hiển thị đầy đủ.

## Telegram alerts

Hệ thống có thể gửi cảnh báo Telegram cho report và sự kiện bảo mật qua relay phía server. Client không còn giữ `TELEGRAM_BOT_TOKEN` hoặc `TELEGRAM_CHAT_ID` trong bundle. Nếu không cấu hình `TELEGRAM_ALERTS_RELAY_URL`, phần cảnh báo sẽ tự bỏ qua và không làm app crash.
