# Rà soát crash và bộ nhớ — 11/09/2026

Phạm vi: source ứng dụng SwiftUI, ViewModel, domain/parser, SwiftData, cloud/cache/media, speech, reminder và các điểm tích hợp UI. Rà soát tĩnh vòng đời tác vụ/closure, chỉ mục, chuyển kiểu số, khoảng ngày, giải mã ảnh và trạng thái qua các điểm `await`.

## Đã sửa

| Vấn đề | Sửa đổi |
| --- | --- |
| SessionViewModel giữ chính nó trong suốt vòng lặp auth không kết thúc | Chỉ giữ `self` trong từng sự kiện; hủy listener khi owner được giải phóng. Test weak reference xác nhận owner được giải phóng khi stream vẫn mở. |
| Kết quả `status()` hoặc notification trở về sau khi deactivate có thể khôi phục state cũ | Kiểm tra phiên còn hoạt động sau các điểm await, trước khi publish state/thông báo. |
| Double cloud quá lớn, NaN, infinity hoặc số thập phân chuyển sang Int gây trap | Dùng chuyển đổi chính xác có kiểm tra; dữ liệu sai trả lỗi corruptData. Kiểm tra giới hạn dung lượng ảnh và ID cloud trùng. |
| Dictionary với ID cache trùng có thể gây precondition failure | Kiểm tra trùng trước khi tạo dictionary so sánh media. |
| Closure hàng ảnh truy cập chỉ mục mảng đã thay đổi | Render từ snapshot phần tử; kiểm tra chỉ mục và nội dung trước khi xóa. |
| Giải mã ảnh camera toàn kích thước và renderer phụ thuộc scale màn hình gây đỉnh RAM cao | ImageIO downsampling; ảnh hoạt động tối đa 1600 pixel, avatar 400 × 400 pixel; thumbnail hiển thị có giới hạn. Không chỉnh dữ liệu ảnh đã lưu. |
| Tác vụ chọn ảnh có thể cập nhật sau khi rời màn hình hoặc đổi ảnh | Dùng task theo selection và kiểm tra cancellation; chặn lưu hồ sơ khi đang xử lý ảnh. |
| Số không hữu hạn đi vào biểu đồ/tổng thống kê | Lọc số không hữu hạn; bỏ tổng bị tràn và thời lượng ngủ không hợp lệ. |
| Thời lượng ngủ chuyển Int có thể trap với ngày bất thường | Chuyển đổi có kiểm tra, báo lỗi nếu không biểu diễn được. |
| Khoảng DatePicker đảo chiều khi ngày sinh ở tương lai so với đồng hồ thiết bị | Bảo vệ cận dưới của khoảng ngày; bỏ force unwrap phép tính ngày trong parser. |
| Tài nguyên tác vụ/network sống lâu hơn owner | Hủy toast/retry task và invalidate URLSession khi owner được giải phóng. |

## Kiểm chứng

- Build iOS Simulator thành công.
- Toàn bộ unit test thành công; bản chạy Address Sanitizer có 51 test, 62 lượt chạy bao gồm tham số, 0 thất bại.
- Các test hồi quy bao gồm SwiftData mở lại từ đĩa, migration, tách dữ liệu từng bé/tài khoản, lưu nguyên tử, đồng bộ offline/retry, đính kèm ảnh và phân tích/lưu giọng nói.
- UI test tạo bé → ghi nhiệt độ → xem nhật ký → tắt/mở lại app thành công; dữ liệu vẫn còn. Kết quả: `/tmp/BabyCareRuntimeSafetyUI.xcresult`.
- Kết quả Address Sanitizer: `/tmp/BabyCareRuntimeSafetyASan.xcresult`.

## Giới hạn

Đây là rà soát source và chạy test trên Simulator, chưa phải đo Instruments Leaks/Allocations trên iPhone thật hoặc kiểm thử micro/PhotosPicker với mọi thiết bị. Address Sanitizer kiểm tra truy cập bộ nhớ, không chứng minh ứng dụng hoàn toàn không có retain cycle.

Cloud hiện vẫn tải toàn bộ dữ liệu/ảnh vào snapshot và giữ snapshot trong hàng đợi offline. Với lịch sử rất lớn, mức RAM và dung lượng cache có thể cao; downsampling giảm RAM giải mã/hiển thị nhưng không thay thế phân trang và lưu ảnh theo file. Chưa thay hợp đồng lưu/sync trong đợt rà soát này để giữ nguyên hành vi nghiệp vụ.
