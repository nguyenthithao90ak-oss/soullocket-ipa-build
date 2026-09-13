# Sticker gốc đã tách nền — 2026-09-12

36 mẫu trong 4 atlas 3 × 3. Nền trắng/hồng/caro đã đổi thành alpha thật.
Giữ nguyên kích thước 1254 × 1254, vị trí từng ô, RGB của nhân vật và
viền cắt trắng theo đường bao của bộ gấu/thỏ. Viền này không phải khối nền.

| Bộ | File dùng khi tích hợp |
| --- | --- |
| Nhật ký / Giận, Tức, Quậy ở Home | `diary_mood_atlas_v2_transparent.webp` |
| Soul Merge — An ủi | `soul_merge_comfort_atlas_v2_transparent.webp` |
| Soul Merge — Yêu thương | `soul_merge_love_atlas_v2_transparent.webp` |
| Soul Merge — Tinh nghịch | `soul_merge_playful_atlas_v2_transparent.webp` |

PNG là bản chỉnh có alpha, WebP mã hóa lossless từ cùng dữ liệu.
Các PNG/WebP v1 ở thư mục gốc không bị sửa hoặc xóa.
`manifest.json` ghi nguồn, SHA-256, kích thước, số pixel và trạng thái tích hợp.

## Trạng thái tích hợp

**Đã gắn vào app sau khi người dùng khôi phục Git `95b6ffa5` và yêu cầu
bổ sung phần còn thiếu.** Catalog và `OriginalSticker` đã trở lại đầy đủ.
Chỉ khai báo 4 WebP cụ thể trong `pubspec.yaml`, không đóng gói PNG nguồn
và không khai báo cả thư mục. Version/dependency giữ nguyên `4.0.0+118`.
Giữ toàn bộ ID, số hàng/cột, lựa chọn đã lưu và thông số chuyển động cũ.
Không đổi bộ nét vẽ mới. Kho cũ vẫn giữ 78 bản gốc atlas và các GIF/PNG khác.

## Tái tạo và kiểm tra

Từ thư mục gốc dự án, dùng `sharp` đã có sẵn; không thêm dependency Flutter:

```text
node scripts/images/remove-sticker-backgrounds.cjs
node --test scripts/images/sticker-transparency.test.cjs
```

Script chỉ tràn mặt nạ từ nền bên ngoài và các khe kín đã kiểm tra bằng mắt.
Không xóa hàng loạt màu trắng trong nhân vật; không vẽ lại tranh bằng AI.
SHA nguồn được khóa để dừng nếu ảnh đầu vào khác bản đã duyệt.
Ảnh xem thử trên nền sáng/tối và báo cáo nằm trong
`build/visual_checks/sticker_transparency/`.

Test Flutter độc lập: `test/assets/sticker_transparency_test.dart`.
Test này kiểm tra giải mã và vẽ 36 ô trên hai nền. Test bundle còn xác nhận
catalog thực sự dùng các WebP có alpha; test `OriginalSticker` xác nhận
chuyển động cục bộ, vòng lặp, giảm chuyển động và góc ảnh luôn trong suốt.

Kết quả ngày 12/09 sau tích hợp: 32 test Flutter sticker/asset/Home đạt,
bao gồm 4 test render độc lập. Lần chạy song song bị hết RAM máy; chạy lại
với `--concurrency=1` đạt. Xem báo cáo kiểm chứng khôi phục trong `docs/`.
