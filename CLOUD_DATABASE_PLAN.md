# Kế hoạch database cloud cho BabyCare

Trạng thái: backend giai đoạn 1, Auth/provider giai đoạn 2 và outbox offline đơn giản đã triển khai trên Supabase Free (Singapore), project `cxlqvuqloaokzmaewvdy`. Schema, RLS, private bucket và RPC đã chạy; 34 kiểm tra SQL pass. App có email/password, Keychain session, SupabaseCareDataProvider và cache/outbox SwiftData theo account/family. Chưa import dữ liệu local hoặc upload ảnh cloud.
Đối chiếu dịch vụ ngày 09/09/2026. Giả định bản đầu phục vụ cá nhân/nhóm thử nghiệm nhỏ, có nhiều thiết bị; chuẩn bị cấu trúc gia đình để sau này chia sẻ cho người chăm sóc.

## 1. Chọn Supabase Free

Dùng PostgreSQL cho dữ liệu, Supabase Auth cho tài khoản, private Storage cho ảnh và API HTTPS/RPC cho iOS. PostgreSQL phù hợp với quan hệ bé → hoạt động/số đo/lịch nhắc và cho phép chuyển sang hosting PostgreSQL khác sau này. Có SDK Swift hỗ trợ tích hợp. [Swift SDK](https://supabase.com/docs/reference/swift/introduction)

Theo bảng giá hiện tại: Free có 500 MB database, 1 GB file storage, 5 GB egress và 5 GB cached egress, 50.000 người dùng hoạt động/tháng, tối đa 2 project active. Project có thể bị pause sau một tuần không hoạt động; không có automatic backup. Pro bắt đầu từ 25 USD/tháng. Các mức miễn phí không phải cam kết đủ tài nguyên cho mọi số lượng người dùng. [Bảng giá](https://supabase.com/pricing)

Không cần mua VPS, tên miền hoặc dựng server Node/PHP cho phiên bản này. App gọi API Supabase bằng session người dùng; không kết nối trực tiếp bằng mật khẩu PostgreSQL.

## 2. Phạm vi và kiến trúc đích

Giữ MVVM @Observable và các domain model độc lập. Thêm các thành phần:

- `SupabaseCareDataProvider`: mapping DTO, load dữ liệu và gọi mutation RPC.
- `AuthService` + `SessionViewModel`: đăng nhập, khôi phục session, đăng xuất, đổi tài khoản.
- `CareMediaProvider`: upload/download ảnh, cache file và quản lý trạng thái chờ upload.
- `SyncingCareDataProvider` + `SyncEngine`: giai đoạn sau, phối hợp SwiftData với cloud.
- SwiftData schema V2: cache theo tài khoản, metadata đồng bộ và outbox; có migration từ V1.

Ranh giới hiện có ở `CareDataProvider` giúp giữ các View chăm sóc khi thay backend. Tuy nhiên đăng nhập, quyền truy cập, media và trạng thái đồng bộ vẫn cần bổ sung; không thể hoàn thành cloud chỉ bằng đổi một dòng dependency.

Triển khai theo hai mốc rõ ràng:

1. **Cloud MVP:** đã có snapshot SwiftData theo tài khoản/gia đình và ghi qua RPC có operation ID.
2. **Offline sync đơn giản:** đã cho phép ghi local trước vào outbox bền vững, hiển thị “Đang chờ đồng bộ”, gửi tuần tự mỗi 10 giây và khi mở/tải lại app. Backend khử trùng theo operation ID; conflict được tải lại snapshot và rebase một lần.
3. **Offline sync nâng cao:** còn thiếu màn hình quản lý từng lỗi đồng bộ, backoff thích ứng, delta pull và kiểm thử nhiều thiết bị thật.

## 3. Schema đề xuất

| Bảng | Nội dung |
| --- | --- |
| `auth.users` | Tài khoản do Supabase Auth quản lý |
| `families` | Nhóm gia đình |
| `family_members` | Quan hệ user–family và role owner/caregiver/viewer |
| `babies` | Hồ sơ, ngày sinh, dị ứng, ghi chú; thuộc một family |
| `care_activities` | Các hoạt động hiện có, thời điểm, giá trị, đơn vị, ghi chú; thuộc baby |
| `body_measurements` | Cân nặng, chiều cao, vòng đầu và phương pháp đo |
| `baby_care_states` | Trạng thái đợt theo dõi và thời điểm bắt đầu giấc ngủ đang diễn ra |
| `medication_reminders` | Lịch nhắc, trạng thái bật/tắt và thuộc đợt theo dõi |
| `media_assets` | Metadata ảnh, object path, owner và liên kết hồ sơ/hoạt động |
| `mutation_receipts` | Operation ID và kết quả/version giúp retry không ghi trùng |
| `import_jobs` | Theo dõi import dữ liệu local theo tài khoản và lần import |

Giữ UUID đang có trên thiết bị. Thêm `created_at`, `updated_at` do server cấp, `version` cho kiểm tra concurrent update và `deleted_at` cho đồng bộ thao tác xóa. Index theo family/baby, thời điểm hoạt động và cursor đồng bộ. Dùng khóa ngoại để tránh record gắn nhầm gia đình.

`selectedBabyID`, cỡ chữ và các tùy chọn hiển thị là preference của thiết bị hoặc của từng user; không dùng một giá trị chung cho cả gia đình. Onboarding phụ thuộc quyền truy cập hồ sơ sau khi đăng nhập.

## 4. Đăng nhập và phân quyền

Đề xuất Sign in with Apple làm cách đăng nhập đầu tiên trên iOS; cần cấu hình capability và Apple provider của Supabase. Nếu chọn email/password thì bổ sung SMTP trước khi cho người dùng ngoài nhóm thử nghiệm đăng ký. SMTP mặc định Supabase chỉ gửi tới địa chỉ thuộc team, không phù hợp cho phát hành rộng. [Apple login](https://supabase.com/docs/guides/auth/social-login/auth-apple), [SMTP](https://supabase.com/docs/guides/auth/auth-smtp)

Thiết kế auth ngay từ đầu, triển khai UI mời người chăm sóc ở giai đoạn sau. Tạo family và membership owner qua transaction đã xác thực. User không được tự thêm mình vào family khác hoặc tự nâng role.

Bật RLS trên mọi bảng được API truy cập: user chỉ đọc/ghi trong family có membership phù hợp; viewer chỉ đọc. Storage cũng private và kiểm tra membership tương ứng. RPC phải kiểm tra user/role và không tạo đường bypass quyền. App chỉ chứa URL và publishable key; session lưu theo cấu hình Keychain, không nhúng secret/service-role key hoặc mật khẩu DB. [RLS](https://supabase.com/docs/guides/database/postgres/row-level-security), [Storage policies](https://supabase.com/docs/guides/storage/security/access-control)

Đăng xuất/đổi tài khoản phải tách cache, outbox, cursor và lịch thông báo theo account; hủy pending requests của session cũ để dữ liệu tài khoản trước không xuất hiện trong phiên mới. Xử lý quyền family bị thu hồi khi refresh.

## 5. API, ảnh và transaction

Định nghĩa DTO và envelope có `api_version`, `operation_id`, `baby_id`, expected record version và payload. Không coi JSON synthesized của enum Swift là contract API lâu dài.

RPC trong PostgreSQL xử lý nguyên tử các mutation liên quan: ghi nhiều hoạt động; lưu giấc ngủ và xóa timer đang chạy; ghi đã dùng thuốc và tắt đúng reminder. Validate lại phía server và lưu receipt trong cùng transaction. Khi request timeout, retry cùng operation ID hoặc tra receipt để biết có commit hay chưa. [Database functions](https://supabase.com/docs/guides/database/functions)

Ảnh đưa vào private Storage; database chỉ lưu object path và metadata. Mục tiêu ban đầu: resize cạnh dài khoảng 1.600 px, nén xuống khoảng 200–500 KB/ảnh và loại bỏ metadata vị trí khi upload. Điều chỉnh sau khi kiểm tra chất lượng trên ảnh thật. Tải thumbnail theo nhu cầu; không nhúng toàn bộ ảnh vào snapshot mỗi lần mở app.

Upload file và transaction database là hai thao tác riêng: giữ trạng thái pending, dùng object ID ổn định để retry, chỉ đánh dấu media ready khi upload hoàn tất và dọn object mồ côi. Không giả định chúng có thể rollback cùng một SQL transaction.

Đọc dữ liệu theo page; chuyển dần từ full snapshot sang delta/cursor khi số record tăng. Nếu MVP cần toàn bộ dữ liệu để giữ chart/report hiện tại, provider phải lấy đủ các page thay vì chỉ nhận page mặc định. Dùng revision/cursor nhất quán, tránh tải nhiều page ở các trạng thái dữ liệu khác nhau.

## 6. Chuyển dữ liệu SwiftData hiện có lên cloud

Sau đăng nhập lần đầu, cho người dùng chọn “Đưa dữ liệu trên máy lên tài khoản này”. Trước khi upload, hiển thị số bé, record, ảnh và tài khoản đích để xác nhận quyền sở hữu.

Giữ database local; tạo import job, upload dữ liệu theo batch với UUID cũ, checkpoint sau từng batch, resume khi gián đoạn. Record trùng UUID nhưng khác nội dung phải xử lý conflict, không ghi đè âm thầm. Ảnh có tiến độ riêng.

Chỉ đánh dấu hoàn tất sau khi đối chiếu ID, số lượng và media với server. Lỗi hoặc quota đầy không được xóa local. Việc import phải gắn với account/family cụ thể và có thể chạy lại mà không nhân đôi dữ liệu.

## 7. Đồng bộ offline

Phiên bản đơn giản hiện lưu snapshot + outbox trong cùng một record SwiftData theo account/family. Mỗi mutation có operation ID và được sync tuần tự; app retry định kỳ với khoảng cố định. Bản nâng cao sẽ tách trạng thái từng item, số lần thử/backoff và UI xử lý lỗi quyền/validation.

Sau push, pull thay đổi cloud bằng cursor có thứ tự ổn định và lưu cursor cùng các record đã áp dụng. Theo dõi tombstone để record đã xóa không xuất hiện lại. Server giữ version và reject update cũ; khi hai thiết bị sửa cùng bản ghi, đưa người dùng lựa chọn dữ liệu cần giữ. Không tự dùng đồng hồ client để ghi đè record sức khỏe.

Sync khi mở app, trở lại foreground, sau thao tác ghi và khi có kết nối. Realtime chỉ là tín hiệu yêu cầu refresh, không thay thế cursor/đối soát. iOS background sync là best effort, không cam kết cập nhật ngay khi app đã bị kill.

Lịch nhắc lưu cloud nhưng notification được đặt riêng trên mỗi thiết bị từ state đã nhận. Chưa bổ sung remote push ở MVP.

## 8. Thứ tự triển khai và nghiệm thu

| Giai đoạn | Đầu ra | Điều kiện hoàn tất |
| --- | --- | --- |
| 1. Backend | Project Free, SQL migrations, schema, RLS, private bucket, mutation RPC | Hai user khác family không đọc/ghi được dữ liệu nhau; batch lỗi rollback toàn bộ |
| 2. Auth + provider | Swift SDK, SessionViewModel, DTO, SupabaseCareDataProvider, cache theo account | Đăng nhập trên thiết bị thứ hai đọc được record đã lưu; logout/đổi account không lộ cache cũ |
| 3. Media + import | Nén/upload ảnh, import job và checkpoint | Đứt mạng giữa import rồi chạy lại không mất hoặc nhân đôi dữ liệu |
| 4. Cloud MVP | Luồng CRUD đầy đủ qua cloud, xử lý timeout/quota/auth hết hạn | Test tạo/sửa/xóa, sleep/reminder atomic, khôi phục dữ liệu trên cài đặt mới |
| 5. Offline sync | Outbox đơn giản đã có; sync status, conflict UI và delta pull nâng cao còn lại | Đã test ghi nhiều mutation offline, khôi phục journal và đồng bộ đúng một lần; cần nghiệm thu hai máy thật |
| 6. Thử nghiệm | TestFlight, quota dashboard, quy trình backup/restore | Khôi phục được cả SQL lẫn object ảnh từ backup thử nghiệm |

Outbox hiện đủ dùng thử cho dữ liệu không có ảnh. Trước khi phát hành rộng cần bổ sung UI xử lý item lỗi, backoff và kiểm thử xung đột trên hai thiết bị thật.

## 9. Vận hành gói miễn phí

Đặt ngưỡng theo dõi nội bộ ở 70% và 90% database, storage, egress. Ảnh thường chiếm ngân sách sớm: ví dụ giả định 3.000 ảnh × 300 KB ≈ 900 MB trước phần overhead/thumbnail; đây là ước tính lập kế hoạch, không phải giới hạn số bé được hỗ trợ.

Chuẩn bị script backup PostgreSQL và tải riêng object Storage về nơi riêng tư có mã hóa; kiểm thử restore. Lập lịch tự động là bước triển khai riêng sau khi chọn nơi chạy và nơi giữ backup. PDF không phải bản backup đầy đủ.

Chuyển lên gói trả phí khi quota thực tế hoặc yêu cầu hoạt động liên tục vượt khả năng Free. Chi phí email, tài khoản Apple Developer và nơi giữ backup (nếu cần) được tính riêng, không nằm trong cam kết hosting database 0 USD.

## 10. Thông tin cần có khi bắt đầu triển khai

- Tài khoản Supabase của chủ dự án và project Free; chọn region gần người dùng, ưu tiên Singapore nếu có sẵn.
- Project URL và publishable key để cấu hình ứng dụng. Secret chỉ đặt trong môi trường quản trị/server, không gửi vào source iOS.
- Xác nhận cách đăng nhập: đề xuất Apple; email/password cần cấu hình gửi email.
- Chọn family/tài khoản sở hữu dữ liệu local khi import; dữ liệu thử nghiệm phải tách khỏi dữ liệu thật.

Bước tiếp theo: giai đoạn 3, nén/upload ảnh và import dữ liệu SwiftData local có checkpoint. Cần một tài khoản email đã xác nhận để chạy kiểm thử end-to-end trên hai thiết bị.
