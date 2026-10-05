# Ảnh Google Play — SoulLocket

Bộ ảnh trang Google Play, thiết kế mới hoàn toàn:

- **Không dùng sticker có sẵn trong app.** Nền, sợi chỉ nhịp tim, trái tim viền và ngôi sao lấp lánh đều là vector vẽ mới trong `src/`.
- **Giữ nguyên icon 512** (`icons/icon-512.png`).
- **Nội dung màn hình là ảnh chụp thật của app**, đặt vào `src/shots/`. Không vẽ lại hay giả lập giao diện.
- Màu và font theo đúng app: hồng berry `#E65372`, cam đào `#F4A37A`, nền kem `#FFF8F0`, chữ `#3B2830` (`lib/core/sl_theme.dart`), font Be Vietnam Pro (`assets/fonts`).

## Kết quả xuất ra (`google_play/`)

| File | Kích thước | Dùng cho |
|---|---|---|
| `feature_graphic_1024x500.png` | 1024×500 | Ảnh nổi bật (Feature graphic) |
| `phone/01_dem_ngay_yeu.png` … `phone/08_bao_mat_rieng_tu.png` | 1080×1920 | Ảnh chụp màn hình điện thoại |

## Danh sách ảnh cần chụp (`src/shots/`)

Chụp trên điện thoại thật hoặc bản web, dọc, càng nét càng tốt (tối thiểu 1080 px chiều ngang). Đặt tên đúng số, đuôi `.png` hoặc `.jpg`.

| File | Màn hình cần chụp | Tiêu đề trên ảnh |
|---|---|---|
| `01` | Tab **Nhà** — bộ đếm ngày yêu, ảnh đại diện hai bạn | Đếm từng ngày ta yêu nhau |
| `02` | Tab **Nhật ký** — danh sách kỷ niệm có ảnh | Cất giữ mọi khoảnh khắc |
| `03` | Màn hình **chat** giữa hai bạn (có tin nhắn thoại càng tốt) | Thế giới nhỏ chỉ hai ta |
| `04` | **Bản đồ** — khoảng cách hai bạn | Dù xa vẫn thấy gần nhau |
| `05` | **Lịch chung** hoặc **Sự kiện & Kỷ niệm** | Không quên ngày đặc biệt |
| `06` | Màn hình chính điện thoại có **widget SoulLocket** | Tình yêu trên màn hình chính |
| `07` | Tab **Tiện ích** — lưới tiện ích | Hơn 20 tiện ích cho cặp đôi |
| `08` | **Kho Ảnh Mật** hoặc màn hình khoá PIN | Riêng tư tuyệt đối |

Mẹo cho ảnh đẹp:

- Dùng tài khoản mẫu có dữ liệu đẹp (tên, ảnh đại diện, vài kỷ niệm có ảnh). Không để lộ email, số điện thoại hay thông tin cá nhân thật.
- Thanh trạng thái gọn: pin đầy, không có thông báo, giờ dễ đọc.
- Ảnh feature graphic dùng lại `01` và `02`.

## Xuất ảnh

```bash
node store_assets/src/render.js            # xuất tất cả
node store_assets/src/render.js 01 feature # chỉ xuất ảnh có tên chứa "01" hoặc "feature"
```

Cần Node 18+ và Playwright (`npm i -g playwright`, rồi `npx playwright install chromium`).

## Chỉnh nội dung

Mọi chữ, bố cục và màu của từng ảnh nằm trong mảng `SLIDES` ở `src/index.html`:

- `h`, `p`, `tag`: tiêu đề, dòng phụ, nhãn.
- `device`: vị trí và tỉ lệ điện thoại.
- `float`: thẻ nổi cạnh điện thoại.
- `zoom` (tuỳ chọn): phóng to một vùng của chính ảnh chụp, `rect: [x, y, w, h]` theo tỉ lệ 0–1 của ảnh gốc, ví dụ `zoom: { rect: [0.1, 0.15, 0.8, 0.3], left: 560, top: 1100, w: 460, h: 300 }`.
