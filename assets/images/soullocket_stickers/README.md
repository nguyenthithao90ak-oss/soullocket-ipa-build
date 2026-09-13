# SoulLocket sticker packs

Các atlas PNG là tư liệu gốc; bản WebP đã tối ưu vẫn được giữ trong gói ứng
dụng để tương thích. Bộ mặc định hiện tại dùng nét vẽ chuyển động trực tiếp
qua `LivingStickerPainter`, không còn phóng to hoặc lắc nguyên ô atlas.
Ngoại lệ theo lựa chọn ngày 09/09: Tâm sự/Nhật ký và khay Tín hiệu yêu thương
Home dùng lại gấu/thỏ trên atlas gốc, qua `OriginalSticker`. Texture không
thay đổi; lưới chỉ chuyển động ở các vùng mắt/tai/tay/tim đã định nghĩa.
`SoulLocketStickerCatalog` trong `lib/widgets/soullocket_animated_sticker.dart`
vẫn giữ nguyên 78 URI cũ và bổ sung 9 URI nhóm Dỗi.

- `motion_couple_atlas_v1.png`: 3 cột × 3 hàng, chín sticker đôi.
- `heart_atlas_v1.png`: 4 cột × 3 hàng, mười hai sticker trái tim.
- `soul_merge_joy_atlas_v1.png`: 3 × 3, sticker vui và ăn mừng.
- `soul_merge_love_atlas_v1.png`: 3 × 3, sticker yêu thương.
- `soul_merge_comfort_atlas_v1.png`: 3 × 3, sticker buồn và an ủi.
- `soul_merge_playful_atlas_v1.png`: 3 × 3, sticker quậy và hoạt động chung.
- `soul_merge_mascot_v2.png` / `.webp`: bản hình đôi mèo–thỏ ôm tim cũ,
  giữ lại làm tư liệu; icon Soul Merge hiện tại không còn dùng ảnh này.
- `manifest.json`: định danh các ô atlas cũ, không phải danh sách hoạt ảnh mới.

Các bộ mới được khai báo tại `lib/widgets/living_sticker_scene.dart` và
`lib/widgets/living_sticker_packs.dart`: 87 sticker thuộc 9 nhóm, cùng 27 icon
tiện ích, 24 sticker mốc kỷ niệm và 6 hình Home. Chat trực tiếp, Soul Merge,
thư viện và trình tùy chỉnh Home dùng chung các nhóm này. Các ảnh người dùng
tải lên, đường dẫn ảnh cũ đã lưu và GIF/Lottie cũ không bị ghi đè.

Thư viện có ba ngăn: **Bộ mới**, **Gốc đang dùng** và **Kho cũ**. Ngăn gốc
đang dùng phản ánh mặc định ở Nhật ký/Home, không phải lịch sử gửi cá nhân.
Kho cũ gồm 64 bản gốc atlas còn lại và các PNG/WebP/GIF đã đóng gói. Có thể
mở kho từ nút hình hộp trong trình tùy chỉnh Home, chọn lại và lưu sticker.
Ảnh nguồn chưa đóng gói vẫn ở nguyên thư mục cũ; xem kiểm kê tại
`docs/sticker_asset_inventory_2026-09-09.json`. Không xóa hoặc chuyển ảnh nguồn.

Chạy `test/widgets/living_sticker_visual_test.dart` với
`--dart-define=EXPORT_LIVING_STICKERS=true` để xuất GIF xem trước và bảng mẫu
vào `build/visual_checks/`. `living_sticker_behavior_test.dart` kiểm tra luồng
hiển thị dùng chung trên Android và Chrome. Không thêm package hay asset mới
vào `pubspec.yaml`.

UI nên lưu URI dạng `soullocket://sticker/<id>` thay vì đường dẫn file. Nhờ
vậy có thể thay atlas ở phiên bản sau mà không làm hỏng dữ liệu sticker đã lưu.
URI `soullocket://original-sticker/<id>` chọn riêng bản gốc của atlas;
`soullocket://original-asset/assets/...` chọn ảnh gốc đã đóng gói. Không dùng
renderer bộ mới để ghi đè hai loại tham chiếu này.
Chuyển động được dựng bằng Flutter, không phụ thuộc GIF và tự tắt khi hệ điều
hành bật chế độ giảm chuyển động.

Mascot v2 được tạo bằng công cụ ImageGen tích hợp. Prompt và nguồn gốc nằm
trong `soul_merge_mascot_v2.prompt.md`.

Icon Soul Merge hiện tại dùng `SoulMergeMascot` và `SoulMergeMascotPainter`
trong `lib/widgets/`, vẽ trực tiếp bằng Flutter Canvas. Mắt chớp, tai thỏ
cử động, tay ôm và tim đập độc lập; thân và khung không rung hay phóng to.
Cả Home, avatar header và điểm chạm trong Soul Merge dùng chung icon này.
Hoạt ảnh tự dừng khi ẩn màn hình, đưa ứng dụng xuống nền hoặc bật giảm
chuyển động. Không cần tải hay giải mã thêm ảnh động.

Kiểm thử hình ảnh và chuyển động nằm ở
`test/widgets/soul_merge_mascot_visual_test.dart`. Thêm
`--dart-define=EXPORT_SOUL_MERGE_PREVIEW=true` khi chạy test để xuất vòng lặp
Flutter thật ra `build/visual_checks/soul_merge_icon_motion.gif`.
