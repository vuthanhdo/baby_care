# BabyCare · SwiftUI

Giao diện iOS tiếng Việt chuyển từ [thiết kế Bé Khỏe trên Stitch](https://stitch.withgoogle.com/projects/4920262108660743872). Mở `BabyCare.xcodeproj`, chọn scheme **BabyCare**, chọn iPhone Simulator iOS 26.5 trở lên rồi Run. Đã kiểm tra bằng Xcode 27.0, iPhone 17 / iOS 26.5 (13/10/2026, 85/85 unit test đạt).

## Các màn hình

| Màn hình Stitch | File trong `BabyCare/Views` |
| --- | --- |
| A · Tạo hồ sơ bé | `Profile/OnboardingView.swift` |
| B · Ghi nhanh | `QuickLog/QuickLogView.swift` |
| C · Chọn hoạt động | `Activities/ActivityPickerView.swift` |
| D · Nhật ký | `Diary/DiaryView.swift` |
| E · Chi tiết hoạt động | `Activities/ActivityDetailView.swift` |
| F · Ghi nhiệt độ | `Activities/ActivityFormView.swift` |
| V · Ghi bằng giọng nói | `Activities/VoiceEntryView.swift` |
| S · Thống kê | `Insights/StatisticsView.swift` |
| I · Theo dõi ốm & lịch thuốc | `Insights/IllnessTrackingView.swift` |
| K · Cài đặt | `Profile/SettingsView.swift` |
| G · Nhập số đo | `Profile/MeasurementEntryView.swift` |
| P · Hồ sơ bé | `Profile/BabyProfileView.swift` |
| R · Chia sẻ báo cáo | `Insights/ShareReportView.swift` |
| W · Trang người nhận báo cáo | `Insights/ReportPreviewView.swift` — bản xem trước trong ứng dụng |

`ActivityFormView` có các biến thể thuốc, nhiệt độ, triệu chứng, đi khám, dị ứng, sữa, bữa ăn, nước, ngủ, tắm, thay tã và hoạt động khác. Các biến thể ngoài nhiệt độ dùng cấu trúc form F và danh mục trong bản xuất Stitch.

## Kiến trúc và lưu dữ liệu

Ứng dụng dùng MVVM với `@Observable` và luồng một chiều `View → Action → State → View`. `BabyCareViewModel` là chủ sở hữu duy nhất của shared State; View gửi Action và không sửa database model trực tiếp.

- `Domain/`: model thuần và các mutation đã validate.
- `Data/CareDataProvider.swift`: abstraction chung cho nguồn local và cloud.
- `Data/SwiftData/`: provider trên thiết bị, schema version và các entity có quan hệ cascade.
- `Data/Cloud/`: contract API v1, Supabase provider, mutation journal và SwiftData cache theo tài khoản/gia đình.
- `ViewModels/`: app ViewModel và form ViewModel dùng Observation, không dùng `ObservableObject`/`@Published`.
- `Services/`: notification side effect chạy sau khi dữ liệu đã commit.
- `AppDependencies.swift`: nơi chuyển giữa SwiftData, in-memory test hoặc Supabase provider.
- `DesignSystem/CareComponents.swift`: màu, card, nút, icon, header và hàng nhật ký dùng lại.
- `Assets.xcassets`: màu theo thiết kế và logo xuất từ Stitch và icon đã đóng gói, không phụ thuộc URL tạm khi chạy ứng dụng.

Người dùng có thể tiếp tục dùng SwiftData tại `Application Support/BabyCare/BabyCare.store`, hoặc đăng nhập email để dùng database Supabase. Phiên cloud nằm trong Keychain; mỗi account/family có SwiftData cache và outbox riêng. Khi offline, thay đổi xuất hiện ngay sau khi đã được ghi bền vững vào outbox; app thử đồng bộ lại mỗi 10 giây và khi mở lại/tải lại. File JSON của bản cũ vẫn được import đúng một lần vào kho local và giữ nguyên làm bản phục hồi. Xem [ARCHITECTURE.md](ARCHITECTURE.md) và [supabase/README.md](supabase/README.md).

Dùng `NavigationStack`, `TabView`, `Form`, sheet, PhotosPicker và Swift Charts. Font Be Vietnam Pro được đóng gói trong app, hỗ trợ tiếng Việt và Dynamic Type. Nền sáng, màu xanh #146C60 và các nhóm màu giữ theo Stitch. Thanh trạng thái và các control hệ thống dùng giao diện iOS thực tế; thanh tab ba mục là `CareBottomTabs` tự dựng theo Stitch, đặt bằng `safeAreaInset` nên không che nội dung. Các khung Stitch dài được chuyển thành nội dung cuộn, không đặt tọa độ tuyệt đối.

## Chạy và xem trước

Mỗi màn hình có `#Preview`. Dữ liệu mẫu chỉ dùng trong preview hoặc khi thêm launch argument **`-demo`** ở cấu hình Debug; dữ liệu mẫu không ghi vào bộ nhớ ứng dụng. **`-demo-full`** (hoặc build với `SWIFT_ACTIVE_COMPILATION_CONDITIONS='$(inherited) DEMO'` khi cài lên máy thật để xem thử) nạp bộ dữ liệu mẫu đầy đủ `CarePreviewData.showcase`: 3 bé (11 tháng đang theo dõi sốt, 3 tuổi đang ngủ trưa, sơ sinh 12 ngày), một tháng sinh hoạt, đợt ốm với thuốc và triệu chứng, lịch nhắc, lịch sử tăng trưởng, tiêm chủng theo lịch TCMR và ảnh đính kèm; bản build này vẫn gửi thông báo nhắc thuốc thật. Lần chạy bình thường khôi phục phiên hoặc mở đăng nhập; chế độ trên máy mở hồ sơ trống nếu chưa có dữ liệu. `-ui-testing` dùng provider tạm trong bộ nhớ; `-ui-testing-store <UUID>` dùng SwiftData riêng để kiểm thử khởi động lại app.

Đã nối các thao tác tạo/sửa hồ sơ, thêm bé và đổi bé, ghi/sửa/xóa hoạt động, tìm kiếm và lọc nhật ký, ghi số đo, ba chế độ thống kê, theo dõi ốm, lịch nhắc một lần và xuất/chia sẻ PDF cục bộ. Timer ngủ được giữ trong dữ liệu của từng bé. Theo dõi ốm hiển thị tổng quan đợt (`InsightData.episodeSummary`: đỉnh sốt, số lần đo, số liều, triệu chứng gần nhất), biểu đồ thân nhiệt theo đợt có vạch thuốc và nhật ký đợt nhóm theo ngày. Ghi liều từ lịch nhắc sẽ hỏi ngay mốc tiếp theo (+4/6/8/12 giờ tính từ lần vừa ghi, chọn giờ khác hoặc tạm dừng — bố mẹ chọn, app không mặc định); thẻ lịch nhắc hiện lần dùng gần nhất và nổi bật khi đã đến mốc. Lần ghi nhiệt độ đầu tiên trong 24 giờ khi chưa có đợt sẽ mời bắt đầu theo dõi ốm (có thể từ chối). Màn Ghi nhanh có thẻ tóm tắt hôm nay (cữ sữa, giấc ngủ, tã, thuốc khi đang theo dõi ốm hoặc bữa ăn) tính từ nhật ký đã lưu qua `InsightData.daySummary`. Nhắc thuốc chỉ dùng mốc người dùng nhập và xin quyền thông báo khi lưu lịch.

Email/mật khẩu, khôi phục phiên, chọn/tạo family, RPC CRUD, cache cloud và outbox offline đơn giản đã có. Supabase yêu cầu xác nhận email và redirect về app. Dữ liệu SwiftData cũ chưa tự nhập lên cloud; ảnh cloud và giao diện xử lý conflict nâng cao thuộc các giai đoạn tiếp theo. Giọng nói đã tích hợp Apple Speech tiếng Việt: xin quyền micrô/nhận dạng khi bắt đầu, cập nhật văn bản trực tiếp, dừng/nói tiếp và giữ nội dung khi lỗi. Kết quả cuối được phân tích theo các mẫu hoạt động hỗ trợ và tự lưu nếu đủ dữ liệu; câu không rõ báo lỗi. Xem `VOICE_INPUT.md` để biết mẫu câu và quy tắc thời gian. QR/link trực tuyến và lịch lặp tự động chưa có.

Các phân loại sốt, lời khuyên thuốc và percentile minh họa trong Stitch được thay bằng thông tin ghi nhận; ứng dụng không tự chẩn đoán hoặc tính liều. Dữ liệu mới bắt đầu trống, không đưa số đo hoặc liều mẫu vào form nhiệt độ mới.

## Kiểm tra

```sh
xcodebuild -project BabyCare.xcodeproj -scheme BabyCare \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath /tmp/BabyCareDerivedData CODE_SIGNING_ALLOWED=NO test
```

`AdaptiveLayoutUITests` kiểm tra tab, sheet và form ở cả portrait/landscape; chạy thêm với destination iPad mini để mô phỏng màn trong của iPhone Duo (regular width). Bộ test kiểm tra SwiftData qua nhiều lần mở database, transaction, migration JSON; đồng thời kiểm tra DTO cloud, tombstone, cache/outbox tách account/family, nhiều lệnh ghi offline theo thứ tự, thu hồi quyền, retry đúng operation ID và vô hiệu hóa response muộn sau đăng xuất. UI test kiểm tra tạo hồ sơ → ghi nhiệt độ → kill/mở lại app → dữ liệu vẫn còn, cùng ba tab dữ liệu mẫu. Project dùng filesystem synchronized groups nên Xcode tự nhận các Swift file và asset mới.


Nguồn tham chiếu hiện tại: `DesignReference/Stitch/Export` (HTML, PNG và DESIGN.md xuất ngày 09/09/2026). Xem `DesignReference/Stitch/IMPLEMENTATION.md` để đối chiếu màn hình và các điều chỉnh theo tính năng thực tế.
