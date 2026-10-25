# Link chiến dịch App Store

Mỗi kênh dùng một link riêng để App Store Connect tách được lượt xem trang và lượt tải theo kênh. Link có dạng:

```
https://apps.apple.com/app/apple-store/id6824822487?pt=129617549&ct=<chiến dịch>&mt=8
```

- `pt=129617549`: provider token của tài khoản developer (lấy từ App Analytics → Campaigns → Generate a Campaign Link).
- `ct`: tên chiến dịch, tối đa 40 ký tự, chỉ dùng chữ thường, số và gạch ngang.
- `mt=8`: loại nội dung là app.

Không cần tạo trước trong App Store Connect: chỉ cần đổi `ct`. Thêm kênh mới vào bảng dưới để cả nhà dùng cùng một tên.

| Kênh | `ct` | Link |
|---|---|---|
| Trang hỗ trợ GitHub Pages (`docs/index.html`) | `web` | https://apps.apple.com/app/apple-store/id6824822487?pt=129617549&ct=web&mt=8 |
| Bài đăng Facebook (trang/cá nhân) | `facebook` | https://apps.apple.com/app/apple-store/id6824822487?pt=129617549&ct=facebook&mt=8 |
| Nhóm Facebook mẹ bỉm | `fb-group` | https://apps.apple.com/app/apple-store/id6824822487?pt=129617549&ct=fb-group&mt=8 |
| TikTok / Reels (link ở bio) | `tiktok` | https://apps.apple.com/app/apple-store/id6824822487?pt=129617549&ct=tiktok&mt=8 |
| Zalo | `zalo` | https://apps.apple.com/app/apple-store/id6824822487?pt=129617549&ct=zalo&mt=8 |
| Webtretho | `webtretho` | https://apps.apple.com/app/apple-store/id6824822487?pt=129617549&ct=webtretho&mt=8 |
| Phòng khám / bác sĩ nhi (QR `campaigns/qr-clinic.png`) | `clinic` | https://apps.apple.com/app/apple-store/id6824822487?pt=129617549&ct=clinic&mt=8 |
| Tờ rơi, poster (QR `campaigns/qr-flyer.png`) | `flyer` | https://apps.apple.com/app/apple-store/id6824822487?pt=129617549&ct=flyer&mt=8 |
| Dành sẵn: báo cáo PDF gửi bác sĩ | `pdf-report` | https://apps.apple.com/app/apple-store/id6824822487?pt=129617549&ct=pdf-report&mt=8 |
| Dành sẵn: mời người chăm bé trong app | `invite` | https://apps.apple.com/app/apple-store/id6824822487?pt=129617549&ct=invite&mt=8 |

QR trong `campaigns/` là PNG 1200 px, mức sửa lỗi M; in cỡ tối thiểu 2 cm. Sinh lại bằng `CIQRCodeGenerator` nếu đổi link.

## Đọc số liệu

- App Store Connect → app → **Analytics → Acquisition → Campaigns**: lượt xem trang, lượt tải, sessions theo từng `ct`. Một chiến dịch chỉ hiện khi có ít nhất 5 Apple Account tải qua link đó.
- **Acquisition → Sources**: tách App Store Search, Browse, Web Referrer, App Referrer. Search tăng sau khi đổi keyword; Web/App Referrer tăng nhờ các link trên.
- Ngày tính theo UTC; số liệu thường trễ 1–2 ngày. Retention và crash chỉ tính người dùng đồng ý chia sẻ dữ liệu với nhà phát triển.
- App không có SDK analytics (khai "không thu thập" trong App Privacy), nên mọi số liệu lấy từ App Store Connect.

## Mốc so sánh

| Ngày (UTC) | Hiển thị | Xem trang | Tải mới | Chuyển đổi | Ghi chú |
|---|---|---|---|---|---|
| 24/10/2026 | 43 | 27 | 5 | 38,9 % | trước khi đổi keyword và ảnh có tiêu đề |
