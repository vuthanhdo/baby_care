# Đối chiếu giao diện Stitch → SwiftUI

Nguồn thiết kế cho lần cập nhật này: [iOS SwiftUI Design System](https://stitch.withgoogle.com/projects/4920262108660743872). Bản xuất HTML/PNG và DESIGN.md lấy trực tiếp từ Stitch ngày 09/09/2026 nằm trong `Export/`. Không dùng node ID hoặc liên kết thiết kế cũ.

## Các thay đổi

| Màn hình | Cập nhật trong ứng dụng |
| --- | --- |
| Splash | Logo Bé Khỏe gốc, tên/slogan và trạng thái đang tải thật |
| Đăng nhập / Đăng ký | Logo, nền sáng, thẻ thông tin, input có viền, hiện/ẩn mật khẩu, CTA teal; dùng email/mật khẩu đã được chọn |
| A – Bắt đầu | Logo, tiêu đề, thẻ hồ sơ, avatar chữ cái, tên/ngày sinh/giới tính và CTA |
| B – Ghi nhanh | Header gọn, thẻ theo dõi ốm, lịch nhắc gần nhất từ dữ liệu thật, thẻ tóm tắt hôm nay (sữa, ngủ, tã, thuốc/bữa ăn; 13/10/2026), nhóm hoạt động và danh sách gần đây gom chung |
| C – Chọn hoạt động | Ba nhóm trong sheet, các hàng có icon và mô tả, vùng nhập giọng nói |
| D – Nhật ký | Bộ lọc và thẻ màu theo nhóm; tìm kiếm mở phạm vi toàn bộ, xóa từ khóa khôi phục phạm vi |
| E – Chi tiết | Thẻ số liệu, ghi chú/ảnh, biểu đồ và các nút sửa/ghi tương tự/xóa |
| F – Ghi hoạt động | Form thẻ trắng, số nhiệt độ lớn, chọn vị trí đo, sheet ngày giờ, vùng chi tiết mở rộng, CTA lưu |
| G – Số đo | Thẻ cân nặng/chiều cao, bước tăng giảm, phương pháp đo, sheet ngày giờ, CTA lưu |
| P – Hồ sơ | Avatar, thông tin bé, số đo mới nhất, lưu ý sức khỏe và danh sách bé trong các thẻ |
| S – Thống kê | Typography, bộ lọc, thẻ số liệu và biểu đồ nhất quán; giữ ba chế độ và dữ liệu thật |
| I – Theo dõi ốm | Thẻ đợt theo dõi, lịch thuốc và nhật ký; dùng cùng typography và button |
| V – Giọng nói | Typography, vùng microphone/nội dung và các thẻ xem lại; ghi rõ trạng thái tính năng |
| R / W – Báo cáo | Typography/thẻ, lựa chọn nội dung, logo ở bản xem trước, PDF từ snapshot |
| K – Cài đặt | Typography, logo mục giới thiệu; chuyển tài khoản/gia đình từ thanh đầu app vào đây |

`StitchStyle.swift` chứa font Be Vietnam Pro, style nút 56pt, ô nhập, logo, splash và bộ chọn ngày giờ. Font được đóng gói cùng giấy phép OFL, không cần tải mạng khi chạy app. Màu, lề 20pt, card 16pt và nhóm màu theo DESIGN.md.

## Điều chỉnh có chủ đích

- Giữ điều hướng, tab bar, bàn phím, lịch, sheet và quyền truy cập native iOS; kích thước thích ứng và Dynamic Type thay cho tọa độ của trang HTML.
- Email/mật khẩu là phương thức đã tích hợp. Không dựng nút Apple/Google/Face ID giả hoặc đăng nhập bằng điện thoại chưa có backend.
- Giá trị mới để trống; số liệu, đợt ốm và lịch thuốc lấy từ tài khoản/bé đang chọn. Không đưa dữ liệu mẫu vào database thật.
- Nội dung về chẩn đoán, liều thuốc, percentile WHO, HIPAA hoặc mã hóa đầu cuối trong mockup không được biến thành khẳng định trong ứng dụng.
- Sau cập nhật UI, nhập giọng nói đã được nối Apple Speech tiếng Việt (10/09/2026), có bộ phân tích mẫu câu và tự lưu khi đủ dữ liệu; câu không rõ báo lỗi (xem `VOICE_INPUT.md`). Liên kết QR, ảnh cloud và nhập dữ liệu máy lên cloud vẫn có giới hạn như trước.
- MVVM/@Observable và các data provider SwiftData/Supabase giữ nguyên. Các thao tác chỉ báo thành công sau khi lưu.

## Kiểm tra

Bộ XCTest gồm test database/cloud, kiểm tra lưu rồi kill/mở lại app, kiểm tra đăng nhập/đăng ký không gửi dữ liệu lên server, và điều hướng đến các màn Stitch. Kết quả ngày 10/09/2026: **31/31 test pass**, không có test lỗi hoặc bỏ qua, trên iPhone 17 / iOS 26.5. Xem [bộ ảnh Simulator](Verification/index.html). Kết quả XCTest: `/tmp/BabyCareStitchFinal.xcresult`.
