# SoulLocket sticker packs

Hai atlas PNG có alpha thật, được chia theo lưới đều và dùng qua
`SoulLocketStickerCatalog` trong
`lib/widgets/soullocket_animated_sticker.dart`.

- `motion_couple_atlas_v1.png`: 3 cột × 3 hàng, chín sticker đôi.
- `heart_atlas_v1.png`: 4 cột × 3 hàng, mười hai sticker trái tim.
- `manifest.json`: định danh ổn định cho từng ô trong atlas.

UI nên lưu URI dạng `soullocket://sticker/<id>` thay vì đường dẫn file. Nhờ
vậy có thể thay atlas ở phiên bản sau mà không làm hỏng dữ liệu sticker đã lưu.
Chuyển động được dựng bằng Flutter, không phụ thuộc GIF và tự tắt khi hệ điều
hành bật chế độ giảm chuyển động.
