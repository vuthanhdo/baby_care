# App Store assets

- `LISTING.md`: tên, phụ đề, mô tả, từ khóa, privacy labels, age rating, ghi chú review (VI + EN).
- `screenshots/` (không commit): tạo bằng `Tools/store_screenshots.sh <udid> <thư-mục> <vi|en>` từ bộ dữ liệu mẫu `-demo-full`, thanh trạng thái 9:41.

| Khung trên App Store Connect (10/2026) | Thư mục | Simulator | Kích thước |
| --- | --- | --- | --- |
| iPhone with Dynamic Island (medium display) — bắt buộc | `iphone-6.3` | iPhone 17 | 1206 × 2622 |
| iPad 13" display — bắt buộc vì app hỗ trợ iPad | `ipad-13` | iPad Pro 13-inch (từ 1.0.1: thanh tab dọc, hai cột) | 2064 × 2752 |
| iPhone 6.9" (chỉ qua "View All Sizes in Media Manager", tùy chọn) | `iphone-6.9` | iPhone 17 Pro Max | 1320 × 2868 |
| iPhone Duo (tùy chọn tới 04/2027, có thì product page hiện huy hiệu Duo) | `iphone-duo` | iPhone Duo **đang mở** trong Device Hub, chạy `Tools/store_screenshots_duo.sh <udid> <vi\|en>` | 2853 × 2007 (màn trong ngang); slot cũng nhận 2007 × 2853, 1398 × 2034, 2034 × 1398 |

Kéo ảnh vào tab **App Previews and Screenshots** (không phải tab "Header and Search Results", khung Header chỉ nhận 5244 × 2950).

Thứ tự ảnh: 01 Ghi nhanh · 02 Theo dõi ốm · 03 Biểu đồ đợt ốm · 04 Thống kê · 05 Tăng trưởng · 06 Nhật ký · 07 Hồ sơ · 08 Tiêm chủng. App Store Connect nhận tối đa 10 ảnh mỗi kích thước; có thể bỏ 03 hoặc 06 nếu muốn ngắn gọn.

Trên màn rộng (iPad, Duo mở) ảnh Nhật ký chọn sẵn một mục nhiệt độ để khung chi tiết có biểu đồ. XCUITest chụp màn trong của Duo ra ảnh đen, nên `store_screenshots_duo.sh` để UI test điều khiển app (`STORE_HOST_CAPTURE=1`) và tự chụp bằng `simctl io screenshot --display`.
