# Email templates

Mẫu HTML cho Supabase Auth → Authentication → Emails → Templates. Dán toàn bộ nội dung file vào ô Message body của từng loại và đặt Subject tương ứng:

| Template Supabase | File | Subject gợi ý |
| --- | --- | --- |
| Confirm sign up | `confirm-signup.html` | Xác nhận đăng ký Bé Khỏe |
| Reset password | `reset-password.html` | Đặt lại mật khẩu Bé Khỏe |
| Change email address | `change-email.html` | Xác nhận đổi email Bé Khỏe |

Các mẫu dùng `{{ .ConfirmationURL }}`; Supabase chuyển hướng về `babycare://auth-callback` (đã có trong Redirect URLs) nên link mở thẳng ứng dụng. `confirm-sign-up.html` là mẫu OTP cũ, không còn dùng.
