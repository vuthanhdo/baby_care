# Hai người cùng chăm một bé – nghiên cứu (24/10/2026)

Chỉ là phân tích, chưa có code. Mục tiêu: bố/mẹ (hoặc ông bà, người giữ trẻ) cùng xem và cùng ghi cho một bé trên hai tài khoản khác nhau.

## Backend đã có gì

- Dữ liệu thuộc **family**, không thuộc user. Mọi bảng con mang `(baby_id, family_id)`, RLS kiểm tra thành viên qua `babycare_private.has_role` (`supabase/migrations/202609090001_babycare.sql`).
- `family_members.role` đã có `owner | caregiver | viewer`: đọc cho cả ba, ghi qua `babycare_apply` cho owner/caregiver, xoá bé/xoá ảnh chỉ owner. `supabase/tests/backend.sql` đã kiểm thử caregiver ghi được và viewer chỉ đọc.
- Nghĩa là nếu có một dòng `family_members` cho người thứ hai, họ đã đọc/ghi được ngay. Thiếu duy nhất là **cách thêm thành viên** (README backend ghi "mời… là giai đoạn sau").
- Xung đột: mỗi dòng có `expected_version`; client gặp 40001 thì tải lại và replay mutation một lần (`SupabaseCareDataProvider`).

## Những chỗ phải sửa trước khi mở tính năng

| Mức | Vấn đề | Chỗ trong code |
| --- | --- | --- |
| Nghiêm trọng | Xoá tài khoản xoá **mọi family do người đó tạo**, kể cả dữ liệu người kia đang dùng; client cũ còn xoá ảnh trong Storage trước khi gọi RPC | `202609160007_privacy_deletion.sql` (`families.created_by = u`), `SupabaseRemote.removeOwnedAccountMedia` |
| Cao | Không tự làm mới: app chỉ tải khi mở (`ContentView` `.task`), nút "Tải lại" đang bị comment, về foreground chỉ kiểm tra consent. Một người cho uống thuốc, người kia không thấy → nguy cơ **cho uống trùng liều** | `ContentView.swift`, `AccountView.swift` |
| Cao | Thành viên bị gỡ nhận 42501 → client xoá cache **và outbox chưa gửi** mà không báo | `SupabaseCareDataProvider` |
| Vừa | Giới hạn 4 bé đếm theo người tạo family, không theo thành viên | `202609110005_account_babies.sql` |
| Vừa | Mỗi lần tải là đọc toàn bộ và tải lại mọi ảnh; hai người cùng ghi làm tăng số lần phải đọc lại | `SupabaseRemote.fetch` |
| Thấp | Nhắc thuốc là local notification từng máy, chỉ đồng bộ khi máy đó tải lại | `CareReminderService` |

## Thiết kế đề xuất

Chia sẻ theo **family** (người được mời thấy mọi bé trong family), không chia theo từng bé, để giữ nguyên RLS hiện có.

1. Migration mới (chỉ thêm):
   - Bảng `family_invites` (mã băm, vai trò, hết hạn 48 giờ, dùng một lần, có thể thu hồi), không cấp quyền trực tiếp cho client.
   - RPC `babycare_create_invite` (chỉ owner), `babycare_accept_invite` (có giới hạn tần suất, trigger consent sẵn có vẫn áp dụng), `babycare_list_members`, `babycare_remove_member` (không được gỡ owner cuối), `babycare_leave_family`.
   - Viết lại `babycare_delete_account`: family còn thành viên khác thì chuyển `created_by` sang owner/caregiver lâu nhất, chỉ xoá membership của người xoá tài khoản.
   - Chặn xoá object Storage khi family còn thành viên khác (bảo vệ cả bản app 1.0.x còn đường xoá ảnh cũ).
2. App:
   - Hồ sơ bé → "Thành viên & chia sẻ" → "Mời người chăm sóc", chọn "Cùng chăm sóc (xem & ghi)" hoặc "Chỉ xem". Gửi mã/link `babycare://invite?code=…` bằng ShareLink.
   - Người nhận: "Nhập mã mời" → xem tên family/bé → "Tham gia" → app chuyển sang family đó (cần chọn family vì mỗi tài khoản đã có family riêng).
   - Tải lại khi app vào foreground và kéo để làm mới; so `families.revision` trước khi đọc toàn bộ, đọc delta và bỏ qua ảnh đã có.
   - Báo trước khi bỏ outbox của family không còn quyền.
3. Pháp lý: sửa mục 6 (xoá dữ liệu) của chính sách, nói rõ thành viên thấy email của nhau; tăng phiên bản `consent_requirements` (mọi người đồng ý lại). Câu "cha/mẹ, người giám hộ" trong consent cần mở rộng cho người chăm sóc. Mặc định mời với vai trò caregiver, vì owner có quyền xoá hẳn bé.

## Ước lượng

Khoảng 2,5–3 tuần: backend + test PGlite 3–4 ngày, app 6–9 ngày, thử với hai tài khoản + chính sách + App Review 2–3 ngày. Phải phát hành phần sửa xoá tài khoản và chặn xoá ảnh trên server **trước** khi mở lời mời.
