# SoulLocket sticker packs

Các atlas PNG có alpha thật, được chia theo lưới đều và dùng qua
`SoulLocketStickerCatalog` trong
`lib/widgets/soullocket_animated_sticker.dart`.

- `motion_couple_atlas_v1.png`: 3 cột × 3 hàng, chín sticker đôi.
- `heart_atlas_v1.png`: 4 cột × 3 hàng, mười hai sticker trái tim.
- `soul_merge_joy_atlas_v1.png`: 3 × 3, sticker vui và ăn mừng.
- `soul_merge_love_atlas_v1.png`: 3 × 3, sticker yêu thương.
- `soul_merge_comfort_atlas_v1.png`: 3 × 3, sticker buồn và an ủi.
- `soul_merge_playful_atlas_v1.png`: 3 × 3, sticker quậy và hoạt động chung.
- `soul_merge_mascot_v2.png`: hình đôi mèo–thỏ ôm tim, dùng chung ở Home,
  avatar header và điểm chạm Soul Merge qua `SoulMergeMascot`.
- `manifest.json`: định danh ổn định cho từng ô trong atlas.

UI nên lưu URI dạng `soullocket://sticker/<id>` thay vì đường dẫn file. Nhờ
vậy có thể thay atlas ở phiên bản sau mà không làm hỏng dữ liệu sticker đã lưu.
Chuyển động được dựng bằng Flutter, không phụ thuộc GIF và tự tắt khi hệ điều
hành bật chế độ giảm chuyển động.

Mascot v2 được tạo bằng công cụ ImageGen tích hợp. Prompt và nguồn gốc nằm
trong `soul_merge_mascot_v2.prompt.md`. Ảnh có nền alpha, được giải mã tối đa
512 px ở UI để tránh dùng quá nhiều bộ nhớ cho nút nhỏ.
