# Quy trình phát hành Bé Khỏe lên App Store

Áp dụng cho bản 1.0 (build 1), team `K8CNPV49X7`, bundle `com.vuthanhdo.BabyCare`. Nội dung dán vào App Store Connect lấy từ `LISTING.md`; ảnh từ `screenshots/`.

## A. Trước khi archive

1. Google Cloud → OAuth consent screen → **Publish app** (Production); nếu không, đăng nhập Google chỉ chạy cho test user.
2. Tài khoản test cho App Review: xác nhận email `thanhdo.vtb+bekhoe-test@gmail.com`, đặt mật khẩu qua "Quên mật khẩu?" trong app, tạo một hồ sơ bé và vài bản ghi; điền vào Notes.
3. Kiểm tra `MARKETING_VERSION` và `CURRENT_PROJECT_VERSION` trong Xcode → target BabyCare → General. Mỗi lần upload lại cùng phiên bản phải tăng build number. Lịch sử: 1.0 (1) nộp 20/10/2026, được duyệt và phát hành; 1.0.1 (2) upload 23/10/2026 (iPhone Duo/iPad, sửa đăng ký bằng email đã tồn tại), kèm ảnh iPad mới và ảnh iPhone Duo. 1.1 (3) upload và nộp duyệt 25/10/2026, phát hành thủ công, ảnh chụp lại toàn bộ (thời tiết, nhịp thở, tái khám, dị ứng/tiền sử bệnh, biểu đồ chuẩn CDC, dark mode); cần migration Supabase 0011 (đã chạy) và WeatherKit trong App Services của App ID (đã bật).
4. Chạy test: `xcodebuild -project BabyCare.xcodeproj -scheme BabyCare -destination 'platform=iOS Simulator,name=iPhone 17' test`.
5. Push `develop`, gắn tag `git tag v1.0 && git push origin v1.0`. Tùy chọn: merge `develop` vào `main`.
6. Thu hồi token GitHub đang nằm trong remote URL: `git remote set-url origin https://github.com/vuthanhdo/baby_care.git` rồi revoke token trên GitHub → Settings → Developer settings.

## B. Tạo app trên App Store Connect

7. appstoreconnect.apple.com → My Apps → **+** → New App: Platforms iOS; Name `Bé Khỏe: Nhật ký chăm sóc bé`; Primary Language Vietnamese; Bundle ID `com.vuthanhdo.BabyCare` (đã có trong Identifiers nhờ automatic signing); SKU `bekhoe-ios`; User Access Full Access.
8. **App Information**: Category Primary Health & Fitness, Secondary Medical; Content Rights: không chứa nội dung bên thứ ba; Age Rating → trả lời None cho mọi mục → 4+; Privacy Policy URL `https://vuthanhdo.github.io/baby_care/privacy.html`.
9. **App Privacy** → Get started: thu thập dữ liệu Yes → chọn Email Address, Health, Photos or Videos, Other User Content, User ID; mỗi loại: Linked to the user, không Tracking, mục đích App Functionality → Publish.
10. **Pricing and Availability**: Free; tất cả quốc gia (hoặc chọn Việt Nam trước); mục "Designed for iPad apps on Mac/Apple Vision" đã tắt từ build settings.
11. **Version 1.0** (iOS App): tab **App Previews and Screenshots** → khung *iPhone with Dynamic Island (medium display)* nhận `iphone-6.3/vi` (1206 × 2622), khung *iPad 13" display* nhận `ipad-13/vi` (2064 × 2752); bộ `iphone-6.9` chỉ dùng được qua "View All Sizes in Media Manager"; Promotional Text, Description, Keywords, Support URL `https://vuthanhdo.github.io/baby_care/index.html`, Marketing URL trống, Copyright `2026 Vu Thanh Do`. Thêm localization **English** (nút Vietnamese ▾ → Add) và dán nội dung EN + ảnh `iphone-6.9/en`, `ipad-13/en`.
12. **App Review Information**: Sign-in required ✓ với email/mật khẩu test; Contact: tên, số điện thoại, email; Notes: dán từ `LISTING.md`. Version Release: Manually release (để tự bấm phát hành sau khi duyệt).

## C. Archive và upload từ Xcode

13. Xcode → scheme BabyCare, destination **Any iOS Device (arm64)**; Product → **Archive** (cấu hình Release; cờ DEMO không bật). Nếu báo lỗi signing, Signing & Capabilities → Team Vu Thanh Do, Automatically manage signing.
14. Organizer → chọn archive → **Distribute App** → App Store Connect → Upload → giữ mặc định (Upload symbols, Manage version and build number) → Upload. Xcode gửi email khi build xử lý xong (10–30 phút).
15. **TestFlight**: tab TestFlight → build 1.0 (1) → Internal Testing → thêm chính bạn → cài qua app TestFlight trên iPhone → thử đăng ký email, đăng nhập Apple, Google, ghi dữ liệu, xóa tài khoản bằng tài khoản phụ. Export compliance đã khai trong Info.plist nên không hỏi lại.

## D. Nộp duyệt

16. Version 1.0 → Build → **Add Build** → chọn 1.0 (1). Advertising Identifier: No.
17. **Add for Review** → **Submit to App Review**. Thời gian thường 24–48 giờ; theo dõi trạng thái và email từ App Review. Nếu bị từ chối, đọc lý do trong Resolution Center, sửa, tăng build number, upload lại, trả lời trong Resolution Center.
18. Được duyệt (Pending Developer Release) → **Release this version**. Có thể bật Phased Release để phát hành dần trong 7 ngày.

## E. Sau khi lên store

19. Xcode → Organizer → Crashes, và App Store Connect → Analytics để theo dõi.
20. Bản cập nhật: sửa code → tăng `CURRENT_PROJECT_VERSION` (và `MARKETING_VERSION` nếu đổi phiên bản) → test → archive → TestFlight → tạo version mới trên App Store Connect với "What's New" → submit.

## Lý do từ chối hay gặp và trạng thái của app

| Guideline | Trạng thái |
| --- | --- |
| 4.8 Sign in with Apple khi có Google | Đã có |
| 5.1.1(v) Xóa tài khoản trong app, thu hồi token Apple | Đã có |
| 5.1.2 Privacy labels khớp dữ liệu thực tế | Khai theo `LISTING.md` và `PrivacyInfo.xcprivacy` |
| 2.1 App hoàn chỉnh, reviewer đăng nhập được | Cần tài khoản test hoạt động, email xác nhận gửi qua Brevo |
| 1.4.1 Ứng dụng y tế | Có tuyên bố không chẩn đoán trong app, mô tả và chính sách |
| 2.3 Screenshot phản ánh đúng app | Ảnh chụp từ app thật với dữ liệu mẫu |
