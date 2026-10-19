# Thiết lập xác thực BabyCare

Đăng ký email/mật khẩu hiện xác minh bằng link trong email mặc định Supabase. Google provider đã được chủ project bật.

## 1. Google OAuth

1. Mở Google Cloud Console, chọn/tạo project dành cho BabyCare. Trong Google Auth Platform, khai báo Branding, email hỗ trợ và Audience phù hợp. Khi ở chế độ Testing, thêm email thử nghiệm vào Test users.
2. Tạo OAuth client loại **Web application** (app dùng Supabase làm trung gian qua trình duyệt hệ thống). Đặt tên `BabyCare Supabase`.
3. Authorized redirect URI phải đúng:

   `https://cxlqvuqloaokzmaewvdy.supabase.co/auth/v1/callback`

4. Trong [Supabase Google provider](https://supabase.com/dashboard/project/cxlqvuqloaokzmaewvdy/auth/providers?provider=Google), nhập Client ID và Client Secret từ Google rồi bật provider. Giữ Skip nonce checks và Allow users without an email ở trạng thái tắt.
5. Trong [URL Configuration](https://supabase.com/dashboard/project/cxlqvuqloaokzmaewvdy/auth/url-configuration), thêm `babycare://auth-callback` vào Redirect URLs nếu chưa có. App đã đăng ký URL scheme này.
6. Trên iPhone/Simulator chọn “Tiếp tục với Google”, chọn tài khoản và xác nhận quay lại app. Kill app rồi mở lại để kiểm tra session.

Client Secret chỉ nằm trong Supabase Dashboard; không đưa vào source iOS hoặc chat. Google login tự xác minh email qua Google, không yêu cầu nhập thêm OTP đăng ký của Supabase.

Tài liệu: https://supabase.com/docs/guides/auth/social-login/auth-google

## 1b. Sign in with Apple

App dùng nút Apple native (`SignInWithAppleButton`), gửi identity token kèm nonce cho Supabase qua `signInWithIdToken`; không đi qua trình duyệt nên không cần Services ID hay secret key cho luồng iOS.

1. Cần tài khoản **Apple Developer Program trả phí**: Personal Team (Apple ID miễn phí) không cấp được capability này và cũng không nộp được App Store. Project ký bằng team `K8CNPV49X7` (Vu Thanh Do, Individual); entitlement `Configuration/BabyCare.entitlements` gắn cho cả Debug và Release, Xcode tự đăng ký capability cho App ID khi build với automatic signing.
2. Trong [Supabase Apple provider](https://supabase.com/dashboard/project/cxlqvuqloaokzmaewvdy/auth/providers?provider=Apple), bật provider và thêm `com.vuthanhdo.BabyCare` vào **Authorized Client IDs**. Secret key chỉ cần nếu sau này bật đăng nhập Apple trên web.
3. Thử trên máy thật (simulator thường không hoàn tất xác thực Apple): bấm "Continue with Apple", chọn ẩn email hay không, kiểm tra tài khoản xuất hiện trong Authentication → Users với provider `apple`.
4. **Thu hồi token khi xóa tài khoản** (App Store 5.1.1(v)): Edge Function `apple-token` (`supabase/functions/apple-token/index.ts`, deploy 19/10/2026, verify JWT) nhận `{"action":"link","code":…}` ngay sau khi đăng nhập Apple để đổi authorization code lấy refresh token và lưu vào `public.apple_tokens` (migration 0009, chỉ service role đọc/ghi), và `{"action":"revoke"}` trước khi app gọi `babycare_delete_account`. Cần 4 secret trong Edge Functions → Secrets: `APPLE_TEAM_ID` = `K8CNPV49X7`, `APPLE_CLIENT_ID` = `com.vuthanhdo.BabyCare`, `APPLE_KEY_ID` và `APPLE_PRIVATE_KEY` (nội dung file .p8 của key "Sign in with Apple" tạo ở Apple Developer → Keys, đổi xuống dòng thành `\n` nếu dashboard chỉ nhận một dòng). Thiếu secret thì hàm trả lỗi 500 và app bỏ qua (đăng nhập, xóa tài khoản vẫn chạy), nhưng token Apple không được thu hồi.

## 2. Xác minh đăng ký bằng liên kết email

- Giữ **Confirm email** bật và dùng template **Confirm sign up** mặc định có liên kết xác thực.
- Trong URL Configuration → Redirect URLs, cho phép `babycare://auth-callback`.
- App gọi signUp với callback trên, hiển thị màn kiểm tra email và nút gửi lại email xác thực. Không còn ô nhập OTP.
- Khi bấm link trên thiết bị cài app, callback được SDK xử lý để tạo phiên và chuyển vào ứng dụng.
- Nếu xác minh trên thiết bị khác, quay lại chọn “Đã xác minh? Đăng nhập” và nhập email/mật khẩu.
- Kiểm tra link mới, link hết hạn, gửi lại, kill/mở app khi đang chờ xác minh. Không gửi email thử nghiệm tự động trong đợt sửa UI.

`templates/confirm-sign-up.html` là mẫu OTP của phương án cũ, hiện **không triển khai**. Email mặc định vẫn chịu giới hạn dịch vụ Supabase; trước khi phát hành cần cấu hình dịch vụ gửi mail phù hợp.

## 3. Storage

Bucket `babycare-media` đã có trong project: private, 5 MiB/file, JPEG/PNG/HEIC/WebP, RLS theo gia đình. Không cần bật public hoặc tạo service-role key cho app.

App nén ảnh activity thành JPEG cạnh tối đa 1600 point, avatar 400 point, rồi kiểm tra dung lượng. Outbox giữ bytes trong SwiftData cho tới khi cả bản ghi và ảnh được xác nhận. Upload theo metadata pending → Storage object → metadata ready. Khi mở lại app, yêu cầu cũ được thử lại với cùng ID. Chọn lại ảnh đã gỡ sẽ dùng ID mới để không hồi sinh tombstone.

Gỡ ảnh ẩn metadata và quyền đọc; file vật lý vẫn còn trong bucket. Chưa có tác vụ backend dọn file mồ côi. Đây là đồng bộ đơn giản; chưa có xử lý merge ảnh đồng thời giữa nhiều thiết bị. Cần kiểm tra upload/download thật bằng tài khoản đã đăng nhập trước khi phát hành.

Kiểm tra thủ công: đổi avatar → tải lại → kill/mở app; tạo activity 3 ảnh → sửa/gỡ → chọn lại; ghi có ảnh khi offline → kill app → mở lại online; đăng nhập tài khoản khác gia đình để kiểm tra không đọc được ảnh.
