# Thiết lập Google và xác minh OTP cho BabyCare

Trạng thái ngày 11/09/2026: code iOS đã tích hợp Google OAuth và xác minh đăng ký bằng email OTP. Google provider chưa được bật; chủ project chưa có OAuth credentials hoặc SMTP. Mẫu email bên dưới chưa được triển khai. Không xem việc build/test app thành công là xác nhận đăng nhập Google hay gửi email thật hoạt động.

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

## 2. SMTP và OTP khi đăng ký email/mật khẩu

1. Chuẩn bị dịch vụ SMTP và địa chỉ người gửi được dịch vụ xác minh. Nếu nhà cung cấp yêu cầu domain, chủ domain cần cấu hình DNS theo hướng dẫn của họ. Chưa lựa chọn hoặc đăng ký dịch vụ trả phí cho project.
2. Trong [SMTP Settings](https://supabase.com/dashboard/project/cxlqvuqloaokzmaewvdy/auth/smtp), nhập Host, Port, Username, Password, Sender email và Sender name `Bé Khỏe` từ dịch vụ SMTP. Không dùng mật khẩu đăng nhập Gmail thông thường.
3. Giữ **Confirm email** bật trong Authentication → Sign In / Providers.
4. Trong Emails → Confirm sign up, đặt subject `Mã xác minh đăng ký Bé Khỏe` và copy nội dung file `templates/confirm-sign-up.html`. Biến `{{ .Token }}` sẽ được Supabase thay bằng mã xác minh. Cấu hình OTP length là 6 để khớp app.
5. Đăng ký một email thử nghiệm do bạn kiểm soát. Kiểm tra mã sai/hết hạn báo lỗi, mã đúng tạo session, gửi lại mã, và kill app khi đang ở bước nhập mã rồi mở lại.

Dashboard hiện yêu cầu custom SMTP để chỉnh email template. SMTP mặc định của Supabase chỉ phục vụ thử nghiệm với các địa chỉ thuộc team project; không đủ cho người dùng thông thường. Khi SMTP/template chưa cấu hình xong, email mặc định có thể vẫn chứa link xác minh; app vẫn nhận callback từ link đó.

Tài liệu: https://supabase.com/docs/guides/auth/auth-smtp và https://supabase.com/docs/guides/auth/auth-email-templates

## 3. Storage

Bucket `babycare-media` đã có trong project: private, 5 MiB/file, JPEG/PNG/HEIC/WebP, RLS theo gia đình. Không cần bật public hoặc tạo service-role key cho app.

App nén ảnh activity thành JPEG cạnh tối đa 1600 point, avatar 400 point, rồi kiểm tra dung lượng. Outbox giữ bytes trong SwiftData cho tới khi cả bản ghi và ảnh được xác nhận. Upload theo metadata pending → Storage object → metadata ready. Khi mở lại app, yêu cầu cũ được thử lại với cùng ID. Chọn lại ảnh đã gỡ sẽ dùng ID mới để không hồi sinh tombstone.

Gỡ ảnh ẩn metadata và quyền đọc; file vật lý vẫn còn trong bucket. Chưa có tác vụ backend dọn file mồ côi. Đây là đồng bộ đơn giản; chưa có xử lý merge ảnh đồng thời giữa nhiều thiết bị. Cần kiểm tra upload/download thật bằng tài khoản đã đăng nhập trước khi phát hành.

Kiểm tra thủ công: đổi avatar → tải lại → kill/mở app; tạo activity 3 ảnh → sửa/gỡ → chọn lại; ghi có ảnh khi offline → kill app → mở lại online; đăng nhập tài khoản khác gia đình để kiểm tra không đọc được ảnh.
