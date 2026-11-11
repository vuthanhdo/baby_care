# Kế hoạch chuyển backend từ Supabase cloud sang VPS Oracle (11/11/2026)

Quyết định của chủ dự án: chạy **Postgres và backend tự viết** trên VPS Oracle; tạm dùng tên miền **sslip.io** cho HTTPS; Claude thao tác VPS qua SSH trong Terminal panel.

**Đổi ngày 11/11/2026: bỏ dữ liệu cũ.** Database Supabase đầy đĩa và sập từ 04/11/2026 (xem mục 6). Chủ dự án chọn không nâng gói để cứu dữ liệu: VPS bắt đầu với database trống, người dùng tạo lại tài khoản. Trên máy người dùng vẫn còn bản cache của dữ liệu cloud.

## 1. Hiện trạng cần thay

App dùng Supabase ở 4 chỗ:

| Phần | Đang dùng | Ghi chú |
| --- | --- | --- |
| Đăng nhập | GoTrue: email/mật khẩu, xác nhận email bằng link, quên mật khẩu, Sign in with Apple (`signInWithIdToken`), Google (OAuth PKCE qua trình duyệt), refresh token | Callback `babycare://auth-callback`; email gửi qua Brevo SMTP |
| API | 21 RPC `babycare_*` (ghi dữ liệu, chia sẻ, consent, góp ý, bình chọn, xoá) và đọc 3 bảng (`families`, `media_assets`, `app_feedback`) | Logic nằm trong SQL: 14 migration, 41 hàm, có RLS và test PGlite |
| File | Storage, bucket `babycare-media` (ảnh bé) và `babycare-feedback` (ảnh góp ý) | Quyền đọc/ghi/xoá bằng policy trên `storage.objects` |
| Edge Function | `apple-token` (lưu và thu hồi token Apple khi xoá tài khoản) | Bắt buộc theo App Store 5.1.1(v) |

## 2. Kiến trúc trên VPS

```
iPhone ──HTTPS──▶ Caddy (Let's Encrypt, <ip>.sslip.io)
                     └─▶ babycare-api (TypeScript, Node 22)
                            ├─▶ Postgres 16 (schema + 41 hàm SQL giữ nguyên)
                            └─▶ /srv/babycare/files (ảnh), sao lưu ra Object Storage
```

- **Giữ nguyên lớp SQL.** Thêm migration "tương thích" tạo những gì SQL đang dựa vào Supabase: schema `auth` (bảng `auth.users`, hàm `auth.uid()` đọc claim `sub` của request), role `anon`/`authenticated`, schema `storage` (`storage.objects`, `storage.foldername()`). Nhờ vậy RLS, hàm `security definer` và test PGlite chạy y như cũ.
- **Backend tự viết, nói đúng giao thức mà app đang gọi.** Đường dẫn và định dạng JSON theo đúng phần con của GoTrue, PostgREST và Storage mà app dùng (`/auth/v1/*`, `/rest/v1/rpc/*`, `/storage/v1/object/*`, `/functions/v1/apple-token`). App chỉ cần đổi URL và key, thư viện `supabase-swift` vẫn dùng được. Không chạy phần mềm nào của Supabase trên VPS.
  - **Auth:** mật khẩu bcrypt (cùng định dạng hash với GoTrue). Access token JWT 1 giờ, refresh token xoay vòng lưu trong DB. Link xác nhận/đặt lại mật khẩu gửi qua Brevo SMTP. Kiểm identity token Apple bằng JWKS kèm nonce. Google dùng OAuth code + PKCE.
  - **RPC:** chỉ cho gọi danh sách hàm cho phép. Mỗi request chạy trong một transaction với `set local role authenticated` và claim của người dùng, đúng cách PostgREST làm, nên quyền giữ như hiện tại.
  - **File:** trước khi ghi/đọc/xoá, backend cho Postgres kiểm quyền theo policy cũ trên `storage.objects`, rồi mới đụng tới file trên đĩa.
- **Vận hành:** Docker Compose (postgres, api, caddy); tường lửa chỉ mở 22/80/443; sao lưu `pg_dump` và thư mục ảnh mỗi đêm ra Oracle Object Storage, giữ 14 ngày; log tập trung `journald`; cập nhật bảo mật tự động.

## 3. Các giai đoạn

| # | Việc | Kết quả kiểm chứng |
| --- | --- | --- |
| 0 | Khảo sát VPS (OS, CPU ARM/x86, RAM, đĩa), cập nhật hệ thống, tạo user deploy, tường lửa OS, Docker, Caddy; mở cổng 80/443 trong Security List của VCN (chủ dự án làm trên Oracle Console) | `https://<ip>.sslip.io` trả trang trạng thái qua HTTPS |
| 1 | Postgres 16, migration tương thích và 14 migration hiện có; chạy bộ test SQL trên Postgres thật | 5 bộ test SQL đều qua |
| 2 | Viết `babycare-api` (auth, rpc, storage, apple-token) kèm test API tự động; `supabase-swift` gọi thử từ unit test | Test API và test tích hợp qua |
| 3 | ~~Diễn tập chuyển dữ liệu từ Supabase~~: **bỏ** ngày 11/11/2026 vì không chuyển dữ liệu cũ | — |
| 4 | App 1.4: URL/key backend để trong cấu hình; thêm kiểm tra "phiên bản tối thiểu" để sau này bắt cập nhật được; chạy toàn bộ test và thử trên TestFlight | Mọi luồng chạy trên VPS |
| 5 | Cắt chuyển: phát hành bản app trỏ sang VPS, tạo lại tài khoản cho App Review; Supabase đã sập nên không cần khoá ghi. Sau đó tạm dừng project Supabase | Người dùng tải bản mới, đăng ký và ghi được |

**Tiến độ.** Giai đoạn 0 xong ngày 11/11/2026 (`server/scripts/bootstrap.sh`):
- Hệ thống đã cập nhật, tự cài bản vá bảo mật; có fail2ban, Docker 29.9 + compose 5.7, swap 4 GB.
- Nginx mặc định đã tắt; Caddy 2.8.4 chạy trong Docker.
- `https://158-178-232-52.sslip.io/healthz` trả `ok`, chứng chỉ Let's Encrypt hết hạn 09/02/2027 (Caddy tự gia hạn), HTTP tự chuyển sang HTTPS.
- Security List của VCN đã mở sẵn 80/443.

Giai đoạn 1 xong ngày 11/11/2026:
- Postgres 17.6 (cùng bản chính với Supabase, 17.6) chạy trong Docker, không mở cổng ra ngoài.
- Migration tương thích `server/db/000_platform.sql` cùng 14 migration của app đã áp vào database `babycare`; theo dõi trong `babycare_platform.schema_migrations`.
- `server/scripts/test-sql.sh` dựng một database tạm từ đầu và chạy 5 bộ test SQL: 161 kiểm tra đều qua.
- Triển khai: `server/scripts/deploy.sh` (chạy trên Mac).

Giai đoạn 2 xong phần lõi ngày 11/11/2026: `server/api` (TypeScript chạy thẳng trên Node 24, Hono, postgres.js, jose, bcryptjs, nodemailer) chạy sau Caddy.
- **Auth (PKCE):**
  - Đăng ký kèm link xác nhận, gửi lại email, đăng nhập mật khẩu.
  - Refresh token xoay vòng, cho dùng lại trong 10 giây để chịu được lần gửi lại của SDK.
  - Quên mật khẩu, link quay về app có thêm `type=recovery`. Đổi mật khẩu, đăng xuất theo phạm vi.
  - Đăng nhập Apple bằng `id_token`, Google qua `/authorize` → `/callback`.
- **REST:** cổng gọi mọi hàm `babycare_*` (đọc chữ ký từ catalog) và đọc 3 bảng. Lỗi theo đúng định dạng PostgREST.
- **Storage:** upload multipart, tải về nguyên byte, xoá. Quyền do chính policy trên `storage.objects` quyết định.
- **`apple-token`:** đã chuyển từ Edge Function sang backend.
- **Kiểm chứng:** 24 test API qua trên PGlite (máy Mac) và trên Postgres 17 thật (`server/scripts/test-api.sh`). Đi qua HTTPS: `/healthz`, kiểm `apikey`, chuyển hướng link email lỗi về app.
- Đặc tả giao thức `supabase-swift` 2.55.1 mà backend bám theo: `server/api/PROTOCOL.md`.

Còn thiếu: bí mật SMTP Brevo, Google OAuth client, khoá Apple trong `.env`, do chủ dự án tự điền; thử bằng chính app (giai đoạn 4).

Giai đoạn 4 đang làm (11/11/2026). App giữ số phiên bản 1.3 và lên build 6; bản 1.3 (5) đã được duyệt nhưng bị huỷ phát hành (Developer Rejected).
- **Đã có trong code:**
  - App trỏ sang `https://158-178-232-52.sslip.io`; bỏ phiên đăng nhập Supabase cũ.
  - Khôi phục dữ liệu từ cache cũ trên máy, ở màn tạo hồ sơ bé và trong Cài đặt.
  - Bỏ write vẫn xung đột sau khi rebase; thử lại giãn dần tới 5 phút.
  - Đọc `type=recovery` để mở màn đặt mật khẩu mới.
  - 309 unit test qua. Chi tiết trong `ARCHITECTURE.md`.
- **Đã thử trên simulator với VPS (11/11/2026, tài khoản App Review):**
  - Đăng nhập, đồng ý quyền riêng tư, tự tạo gia đình.
  - Khôi phục "Bé Sóc" từ cache cũ: 6 lần ghi; server có 16 hoạt động, 3 số đo, 1 lịch nhắc, 1 ảnh, khớp với cache. Khôi phục lần hai không tạo bản trùng và dọn sạch cache cũ.
  - Ghi nhanh một cữ sữa; mở lại app vẫn đăng nhập và tải từ VPS. Log API không có lỗi.
- **Còn lại:**
  - Chủ dự án điền SMTP, Google, Apple vào `.env`.
  - Commit; archive và upload 1.3 (6); gắn vào phiên bản 1.3 (đang Developer Rejected) và nộp duyệt.
  - Push `develop` để chính sách quyền riêng tư mới lên GitHub Pages trước khi bản mới phát hành.
  - Sau khi bản mới ổn định: xoá project Supabase cũ, như chính sách đã cam kết (hỏi chủ dự án trước).

## 4. Rủi ro và cách xử lý

- **App cũ (1.2, 1.3) gắn cứng địa chỉ Supabase**, nên đã hỏng từ 04/11/2026. Chỉ bản app mới chạy được.
- **Đổi IP thì đổi tên miền sslip.io**, và app đã phát hành sẽ trỏ sai. Trước bước 5 nên có tên miền riêng, ví dụ `api.<tenmien>`; chỉ cần đổi một dòng cấu hình rồi ra bản app.
- **Một VPS là một điểm hỏng.** Có sao lưu mỗi đêm và hướng dẫn khôi phục đã diễn tập; theo dõi uptime từ bên ngoài.
- **Bí mật** (mật khẩu DB, khoá ký JWT, SMTP Brevo, Google Client Secret, khoá Apple `.p8`) chỉ nằm trong file `.env` quyền 600 trên VPS. Khoá ngẫu nhiên được sinh ngay trên VPS. Bí mật của Brevo/Google/Apple do chủ dự án tự dán vào; Claude không đọc hay in ra.
- **Chi phí:** VPS Oracle (Always Free nếu là Ampere A1) và Object Storage miễn phí tới 20 GB.

## 5. Ngoài phạm vi đợt này

Realtime (app không dùng), bảng điều khiển quản trị (vẫn duyệt đề xuất/góp ý bằng SQL), chạy nhiều máy chủ.

## 6. Sự cố Supabase 02–04/11/2026

- **Hiện tượng.** Từ khoảng 10:00 ngày 04/11/2026 (giờ Việt Nam), database Supabase hết chỗ trên đĩa ("No space left on device") và khởi động lại liên tục. REST trả 503 `PGRST002`, Auth trả 503: không ai đăng nhập hay đồng bộ được. Log Postgres dừng ngày 10/11.
- **Nguyên nhân.** 21:06 ngày 02/11, một lần ghi `babycare_apply` cũ phiên bản (bản ghi đã bị sửa hoặc xoá ở nơi khác) gặp lỗi `Version conflict or deleted record`. Lỗi này dùng SQLSTATE `40001` (serialization_failure). PostgREST coi mã đó là lỗi tạm thời và **chạy lại giao dịch không ngừng**: một kết nối ghi khoảng 28,8 triệu lần thử trong 24 giờ.
  - Request bị treo tới khi gateway trả 504; app gửi lại sau mỗi lần hết giờ, nên có thêm 2 kết nối lặp như vậy (tổng 3).
  - Mỗi lần thử ghi log lỗi kèm câu SQL dài và tốn một transaction ID. Log và WAL lấp đầy đĩa gói Free trong khoảng 1,5 ngày.
  - Bằng chứng: `query_logs` của project, 3 session `6ae898e3.2055e6`, `6ae89902.2055fb` và `6ae8991c.2055ff`, `session_line_num` lên tới khoảng 28,8 triệu.
- **Trên VPS:**
  - Backend tự viết (postgres.js) không tự chạy lại giao dịch. Test `a stale write answers 409 with code 40001 at once` giữ điều đó.
  - Log Docker có giới hạn kích thước. Có sao lưu mỗi đêm, và cảnh báo khi đĩa dùng từ 80% (`server/README.md`).
- **Phía app (giai đoạn 4).** Xung đột còn nguyên sau khi rebase nghĩa là lần ghi đầu hàng đợi không bao giờ qua, và chặn mọi lần ghi sau nó. Cần báo cho người dùng và bỏ lần ghi đó, như cách đang xử lý lỗi `rejected`.
