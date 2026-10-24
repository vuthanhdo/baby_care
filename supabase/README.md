# BabyCare Supabase backend

Đã triển khai ngày 09/09/2026 trên project **BabyCare**, gói **Free**, region **Singapore (ap-southeast-1)**.

- Project ref: `cxlqvuqloaokzmaewvdy`
- Project URL: `https://cxlqvuqloaokzmaewvdy.supabase.co`
- [Dashboard](https://supabase.com/dashboard/project/cxlqvuqloaokzmaewvdy)
- [SQL Editor](https://supabase.com/dashboard/project/cxlqvuqloaokzmaewvdy/sql)

## Trạng thái

Backend có 10 bảng, RLS theo family, 3 public RPC và private bucket `babycare-media`. App iOS đã có đăng nhập email/mật khẩu, provider Supabase, SwiftData cache/outbox và upload ảnh. Google OAuth/OTP đã có code; chủ project đã xác nhận bật Google provider. Cần kiểm chứng Google login thực tế và cấu hình SMTP cho email. Xem [hướng dẫn thiết lập](AUTH_SETUP.md).

**Đã áp dụng 24/10/2026 (SQL Editor):** `202610240011_health_details.sql`: kind `breathing`, `p_api_version` cho `babycare_read_page`, cột `babies.medical_history` và `care_activities.follow_up_at`, allowlist mới của `babycare_private.babycare_apply` (vá tại chỗ từ định nghĩa đang chạy, vì bản trên server là thân hàm 0006 đã gộp dòng). Bản 1.0.x vẫn chạy bình thường. Trước khi có migration này, app 1.1 gặp server cũ sẽ bỏ thay đổi bị từ chối khỏi hàng đợi kèm thông báo thay vì kẹt mọi lần lưu sau.

Các file migration được áp dụng bằng SQL Editor, theo thứ tự tên file. Không chạy lại trên project này vì schema đã tồn tại. Chưa đăng ký vào lịch sử migration của Supabase CLI: khi chuyển sang CLI, link đúng project và dùng `supabase migration repair --status applied` cho từng version đã đối chiếu, trước khi dùng `db push` ([CLI migration repair](https://supabase.com/docs/reference/cli/supabase-migration-repair)). Một project mới rỗng có thể chạy cả bốn file theo thứ tự. Không chạy reset database để đồng bộ lịch sử.

## Quyền truy cập

| Vai trò | Đọc trong family | Ghi qua RPC | Upload ảnh đã đăng ký |
| --- | --- | --- | --- |
| Chưa đăng nhập | Không | Không | Không |
| owner | Có | Có | Có |
| caregiver | Có | Có | Có |
| viewer | Có | Không | Không |

Không cấp ghi trực tiếp vào bảng cho client. User không thể tự thêm membership hoặc nâng quyền. Chỉ có RPC tạo family mới và tạo owner cho chính người gọi. Mời/chuyển vai trò/xóa tài khoản là workflow của giai đoạn sau. Receipt và import job chỉ hiển thị cho user đã tạo, kể cả trong cùng family.

Hai hàm `babycare_create_family` và `babycare_apply` dùng `SECURITY DEFINER` có chủ đích: kiểm tra user/role, allowlist field, khóa family, quản lý version rồi mới ghi. Chúng có `search_path=''`, không cấp EXECUTE cho PUBLIC/anon. Security Advisor có thể hiển thị hai cảnh báo về authenticated có quyền gọi các hàm này; đây là quyền cần cho API, đã được kiểm thử. Hàm tự bật RLS do Supabase tạo đã bị thu hồi EXECUTE khỏi các role client.

## Contract v1 cho provider

Gọi qua Supabase SDK bằng publishable key và **session của user**. Không đưa database password, secret key hoặc service-role key vào app. Publishable key lấy từ Dashboard khi cấu hình Auth/provider; chưa lưu key trong repository.

### Tạo family

`babycare_create_family(p_id: UUID, p_name: String) → UUID`

Client tạo UUID một lần, retry cùng ID và tên. Server tạo family + owner membership trong cùng transaction. Các thông tin family/membership đọc trực tiếp qua SELECT có RLS.

### Ghi batch

`babycare_apply(p_operation_id, p_family_id, p_changes, p_api_version = 1) → JSON`

Ví dụ tạo hồ sơ và trạng thái ban đầu cùng một transaction:

```json
{
  "p_api_version": 1,
  "p_operation_id": "<UUID cố định cho lần ghi này>",
  "p_family_id": "<family UUID>",
  "p_changes": [
    {
      "entity": "babies",
      "id": "<baby UUID>",
      "expected_version": 0,
      "data": {"name": "Tên bé", "birth_date": "2025-01-01T00:00:00Z", "gender": "unspecified"}
    },
    {
      "entity": "baby_care_states",
      "id": "<cùng baby UUID>",
      "baby_id": "<cùng baby UUID>",
      "expected_version": 0,
      "data": {}
    }
  ]
}
```

- Tối đa 100 changes / 1 MiB mỗi batch. Tạo parent trước child. Không lặp entity + ID trong cùng batch.
- `expected_version=0` để tạo mới; cập nhật dùng version đã đọc. Trùng UUID không ghi đè sang family khác.
- `data` là patch: bỏ field = giữ nguyên; JSON `null` = xóa giá trị nullable (ví dụ timer ngủ). Server từ chối field ngoài allowlist, ID/family/version/timestamps do client chèn vào data.
- Child cần `baby_id`; `babies` và `import_jobs` không có trường này trong envelope.
- Xóa hoạt động/số đo/reminder/media bằng `deleted:true`, `data:{}` và expected version. Trả tombstone; không cho hồi sinh. Xóa baby/state/import chưa thuộc API v1.
- Kết quả chứa `api_version`, `operation_id`, `revision`, `records:[{entity,id,version}]`.
- Timeout: gửi lại **đúng operation ID + payload** để nhận receipt cũ. Không tạo operation ID mới chỉ vì chưa nhận được HTTP response.
- SQLSTATE `40001`: conflict phiên bản, operation ID hoặc snapshot; tải lại và xử lý, không tự ghi đè. `42501`: không có quyền. `22023`, lỗi constraint/cast: payload không hợp lệ.
- Lưu giấc ngủ: cùng batch tạo activity + cập nhật `baby_care_states.sleep_start_date=null`. Dùng thuốc: cùng batch tạo activity + tắt đúng reminder. Provider chịu trách nhiệm mapping action thành đầy đủ changes; RPC đảm bảo nguyên tử cho batch được gửi.
- `amount` reminder là số, ngày là ISO-8601 timestamptz. Provider cần parse/validate chuỗi UI. Không serialize trực tiếp enum Swift làm wire format.

### Đọc phân trang / delta

`babycare_read_page(p_family_id, p_entity, p_at_revision, p_since_revision=0, p_after_id=null, p_limit=200)`

1. Đọc `families.revision` làm revision cố định R.
2. Với từng entity trong 7 bảng dữ liệu, gọi page ở R, lần lượt dùng `next_after_id` cho tới null. Limit từ 1 đến 500; cursor sắp theo UUID.
3. Nếu bất kỳ page trả `40001`, bỏ kết quả tạm của **toàn bộ lần tải**, đọc revision mới và tải lại. Không publish snapshot từng phần.
4. Khi hoàn tất, lưu các record và cursor R cùng nhau. Delta tiếp theo đặt `p_since_revision=R`. Full load dùng 0. Giữ và áp dụng tombstone; lọc `deleted_at` khi hiển thị.

Đây là phân trang có kiểm tra snapshot phù hợp MVP. Chưa có retained event log, outbox hoặc engine offline sync. Một lần tải không bị ảnh hưởng bởi commit xảy ra sau khi đã nhận đủ page; lần pull kế tiếp nhận revision mới.

### Ảnh

1. Tạo `media_assets` trạng thái pending qua RPC, có MIME và byte count thật. Object path server sinh: `<family UUID>/<baby UUID>/<media UUID>`.
2. Upload vào bucket `babycare-media`, không overwrite. Giới hạn 5 MiB/file; JPEG, PNG, HEIC, WebP.
3. Gọi RPC patch status thành ready với version hiện tại. Server kiểm tra object tồn tại và metadata khớp.
4. Đọc bằng session được cấp quyền hoặc signed URL có hạn ngắn. Không tạo public URL. Khi activity bị xóa, các yêu cầu Storage mới bị chặn; signed URL đã phát hành còn hiệu lực đến khi hết hạn.

Upload file và SQL không chung transaction. Workflow dọn object pending/mồ côi và nén ảnh phía iOS chưa triển khai. Không xóa hàng trong `storage.objects` bằng SQL để dọn file; cần dùng Storage API qua backend quản trị ở giai đoạn media.

## Kiểm chứng triển khai

`tests/backend.sql` chạy trong SQL Editor dưới role quản trị, tạo fixture giả và chuyển qua các role để kiểm tra; cuối file ROLLBACK. Không dùng dữ liệu sức khỏe thật.

Kết quả trực tiếp ngày 09/09/2026: **34 checks, all_passed=true**. Bao gồm RLS giữa hai family, viewer/caregiver, quyền ghi trực tiếp, version/receipt, rollback batch, timer/reminder, tombstone, phân trang/delta, metadata upload, ẩn ảnh của activity đã xóa và bucket private. Sau lần test ban đầu đã xác nhận 0 family, 0 auth user, 0 file kiểm thử còn lại; mọi lần chạy đều rollback.

Security Advisor sau khi chạy lại: **0 errors, 2 warnings**, cả hai là quyền gọi authenticated đối với RPC SECURITY DEFINER đã giải thích ở trên. Kiểm tra cuối xác nhận quyền gọi `rls_auto_enable()` của anon/authenticated đều false và database vẫn có 0 family, 0 auth user.

Đây là kiểm thử SQL/role và policy helper, chưa phải kiểm thử HTTP Auth/Storage hoặc hai thiết bị iOS. Những kiểm thử end-to-end đó thuộc giai đoạn nối provider. Không chạy lại Xcode tests trong thay đổi này vì không sửa mã iOS.
