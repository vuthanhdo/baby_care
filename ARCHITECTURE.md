# Kiến trúc BabyCare

Ứng dụng dùng MVVM với Observation (`@Observable`) và luồng dữ liệu một chiều:

```mermaid
flowchart LR
    V[SwiftUI View] -->|send Action| VM[SessionViewModel / BabyCareViewModel]
    VM -->|apply Mutation| P[CareDataProvider]
    P -->|committed CareDatabase| VM
    VM -->|State thay đổi| V
    P --> SD[(SwiftData trên device)]
    P --> CP[SupabaseCareDataProvider]
    CP --> API[(Supabase Auth + RPC/RLS)]
    CP --> Cache[(SwiftData cache theo account/family)]
```

## Ranh giới các layer

- `Domain/`: các value model `Codable`, `Sendable`, không import SwiftData hoặc SwiftUI; `CareDataMutation` là tập thao tác ghi có kiểm tra dữ liệu.
- `Data/CareDataProvider.swift`: contract bất đồng bộ duy nhất mà ViewModel sử dụng. Một mutation phải thành công toàn bộ hoặc throw mà không công bố dữ liệu dở dang.
- `Data/SwiftData/`: implementation độc lập trên thiết bị. `ModelContext` và các class `@Model` được giữ kín trong actor; bên ngoài chỉ nhận `CareDatabase` dạng value.
- `Data/Cloud/`: DTO/wire contract v1, Supabase remote, mutation journal và SwiftData cache tách theo project/user/family. Cache chỉ phục vụ đọc offline; mọi thao tác ghi cloud phải được RPC xác nhận.
- `ViewModels/`: `@Observable`, sở hữu State và nhận Action. State chỉ đổi sau khi provider trả về snapshot đã commit.
- `Views/`: đọc State và gửi Action. State cục bộ như sheet, bộ lọc và text field draft vẫn thuộc View hoặc form ViewModel.
- `Services/`: side effect ngoài database. Notification được đối chiếu sau khi database commit thành công.
- `AppDependencies.swift`: composition root chọn provider thật, provider test hoặc dữ liệu preview.

## Lưu dữ liệu trên device

`SwiftDataCareDataProvider` mở file `Application Support/BabyCare/BabyCare.store`. Hồ sơ, hoạt động, số đo, đợt theo dõi, timer ngủ và lịch nhắc đều nằm trong SwiftData nên vẫn còn sau khi kill app và mở lại. Ảnh đại diện và ảnh đính kèm dùng external storage của SwiftData.

Phiên bản cũ lưu `Application Support/BabyCare/care-data.json`. Lần chạy đầu sau nâng cấp sẽ nhập file này vào SwiftData trong cùng transaction với migration marker. File JSON cũ được giữ nguyên làm bản phục hồi; dữ liệu lỗi không bị ghi đè.

## Cloud provider đã tích hợp

`SessionViewModel` khôi phục Supabase session từ Keychain, tách vòng đời provider theo account và family, hủy provider cũ khi đổi tài khoản. App dùng email/mật khẩu, xác nhận email và callback `babycare://auth-callback`.

`SupabaseCareDataProvider` chuyển mutation thành DTO rõ ràng rồi gọi RPC batch. Trước khi gọi mạng, provider lưu `operation_id`, envelope và state dự kiến vào cache; timeout sẽ retry đúng request để backend trả receipt cũ. Server reject version cũ. State UI chỉ cập nhật sau receipt. Nếu server đã commit nhưng cache local lỗi, UI vẫn nhận state đã lưu và hiển thị cảnh báo cache.

Cache nằm tại:

`Application Support/BabyCare/Cloud/cxlqvuqloaokzmaewvdy/<user UUID>/<family UUID>/Cache.store`

Khi RLS thu hồi quyền family, provider xóa cache của family đó trước khi báo lỗi. Đăng xuất vô hiệu hóa token lease, hủy network session và xóa dữ liệu đang hiển thị. Lịch thông báo được tạo lại từ snapshot của account/family hiện tại và gỡ khi rời phiên.

Ảnh cloud và import dữ liệu SwiftData cũ chưa thuộc giai đoạn này. Provider từ chối mutation có ảnh để tránh báo lưu thành công trong khi byte ảnh chưa được upload. Dữ liệu trên máy không tự được gửi lên khi đăng nhập.
