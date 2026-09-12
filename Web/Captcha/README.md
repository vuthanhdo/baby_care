# Bật CAPTCHA cho BabyCare

Ứng dụng đã có trường nhập lại mật khẩu và truyền token CAPTCHA tới Supabase. Chống spam trên server **chưa được bật** chỉ bằng thay đổi source này. `Configuration/Info.plist` có Boolean `AuthCaptchaEnabled`, mặc định **NO**: ẩn widget, bỏ yêu cầu token và không gửi token cho các luồng email. Kiểm tra nhập lại mật khẩu và OTP vẫn giữ nguyên. Code CAPTCHA không bị xóa.

Đặt **YES** để bật lại sau khi đã cấu hình `AuthCaptchaPageURL` và Supabase. Khi bật, đăng ký bị chặn nếu thiếu URL/token; đăng nhập, đặt lại mật khẩu và gửi lại OTP cũng yêu cầu token để tương thích bảo vệ Supabase. Cờ iOS không tắt bảo vệ trên server; khi dùng NO, Supabase CAPTCHA protection cũng phải đang tắt.

## Cấu hình lần đầu

1. Tạo tài khoản Cloudflare. Vào Workers & Pages, tạo Pages project bằng Direct Upload, tải thư mục chứa `index.html` lên để có hostname dạng `ten-ban-chon.pages.dev`. Chỉ upload trang CAPTCHA, không upload source iOS hoặc secret.
2. Trong Cloudflare → Turnstile → Add widget, đặt tên BabyCare, chọn Managed, thêm đúng hostname Pages ở bước 1. Lưu site key công khai và secret key riêng.
3. Thay `REPLACE_WITH_PUBLIC_TURNSTILE_SITE_KEY` trong `index.html` bằng site key. Upload lại trang lên Pages. Không đặt secret vào HTML hoặc app.
4. Trong `Configuration/Info.plist`, thêm String `AuthCaptchaPageURL` với URL HTTPS đầy đủ của trang vừa deploy (ví dụ `https://ten-ban-chon.pages.dev/`). Đặt `AuthCaptchaEnabled` thành YES rồi build app mới. Widget cũng xuất hiện ở đăng nhập, đặt lại mật khẩu và gửi lại OTP để tương thích bảo vệ của Supabase.
5. Trong Supabase project → Authentication → Bot and Abuse Protection (hoặc Project Settings → Authentication), bật CAPTCHA protection, chọn Cloudflare Turnstile, nhập **secret key trực tiếp tại dashboard**, Save. Phối hợp bật với bản app mới; các bản app cũ không gửi token có thể không đăng nhập được sau khi bật.
6. Kiểm thử bằng email thử nghiệm: mật khẩu không khớp phải bị chặn trước request; chưa giải CAPTCHA phải bị chặn; giải thành công → đăng ký → nhận OTP → xác minh. Kiểm tra thêm đăng nhập, gửi lại OTP và quên mật khẩu.
7. Xác nhận request đăng ký không có token bị Supabase từ chối, để chắc chắn không thể bỏ qua app và gọi API trực tiếp. Không dùng test keys trong production.

Token không lưu xuống máy/log. App tạo lại widget sau mỗi lần gửi; trang xóa token khi lỗi/hết hạn và làm mới sau 4 phút. Mất mạng có thể bấm “Tải lại xác minh”. Supabase là nơi xác minh token cuối cùng.

Tài liệu: [Supabase CAPTCHA](https://supabase.com/docs/guides/auth/auth-captcha), [Turnstile trong mobile WebView](https://developers.cloudflare.com/turnstile/get-started/mobile-implementation/).
