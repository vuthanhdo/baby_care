# Nhập và tự lưu bằng giọng nói

Vào **Nói để ghi → Bắt đầu ghi âm**, cho phép Nhận dạng giọng nói và Micrô, nói tiếng Việt rồi bấm **Dừng và xử lý**. Khi Speech trả kết quả cuối thành công, ứng dụng phân tích toàn bộ câu và gọi `BabyCareAction.commit(.saveActivities(...))` qua provider SwiftData/Supabase đang dùng. Kết quả từng phần, lỗi nhận dạng và timeout không tự lưu.

Câu hợp lệ tự lưu cho bé đang được hiển thị; màn hình liệt kê các hoạt động vừa lưu. Câu không rõ/thiếu dữ liệu báo lỗi và giữ văn bản; có thể sửa rồi bấm **Phân tích và lưu**. Mỗi lần ghi âm mới thay thế nội dung nhận dạng cũ, tránh lưu lại câu trước. Âm thanh có thể được gửi tới Apple khi thiết bị không hỗ trợ nhận dạng tại máy; không lưu file âm thanh và không gửi âm thanh đến Supabase.

## Các cách nói được hỗ trợ

| Câu | Dữ liệu |
| --- | --- |
| Bé uống 120 ml sữa | Sữa, 120 ml; chưa rõ loại sữa |
| Bé uống nước 30 ml | Nước, 30 ml |
| Bé bú mẹ 15 phút | Sữa, bú mẹ, 15 phút |
| Bé đo nhiệt độ 37,5 độ ở nách | Nhiệt độ, 37,5 °C, nách |
| Bé uống thuốc [tên thuốc] [lượng] ml | Tên và lượng thực tế đã nói; hỗ trợ ml/mg/viên/giọt, không suy luận liều |
| Bé ngủ 30 phút | Ghi nhận hiện tại, thời lượng 30 phút |
| Bé tắm xong | Tắm |
| Bé thay tã ướt | Thay tã, ướt |

Không cần đọc đúng nguyên văn bảng trên. Bộ chuẩn hóa cũng hiểu các biến thể như:

- `Mẹ vừa cho bé uống một trăm hai mươi ml sữa nhé`
- `Con em uống sữa hết 150ml`
- `Bé bú được chín mươi ml` hoặc `Em bé bú mẹ được mười phút`
- `Đo nách được ba mươi bảy phẩy năm độ`
- `Con mình ngủ được một giờ rưỡi` hoặc `Bé ngủ nửa tiếng`
- `Thay bỉm cho bé xong`
- `Ghi giúp mình bé uống nước ba mươi ml nha`

Có thể thêm `sáng nay bảy giờ rưỡi`, `hồi 7h30 sáng`, `lúc 14:30`, `mười phút trước` hoặc `cách đây 10 phút`. Không nói thời gian thì mọi hoạt động đều dùng hiện tại. Giấc ngủ trong trường hợp này mang nhãn “Thời điểm ghi nhận”, không tự suy ra giờ bắt đầu/kết thúc. Nếu nói giờ cho giấc ngủ thì đó là giờ bắt đầu; kết thúc không được ở tương lai. Không tự đổi giờ tương lai thành hôm qua.

Tách nhiều hoạt động bằng `rồi`, `sau đó`, `tiếp đó`, `và`, dấu chấm, dấu chấm phẩy hoặc xuống dòng. Phân tích toàn bộ trước khi ghi theo lô: chỉ một câu lỗi cũng không lưu phần còn lại. Hoạt động ngoài nhóm hỗ trợ, câu phủ định/dự định, số không dương, thiếu đơn vị, thời gian không rõ hoặc nhiều cách hiểu đều báo lỗi. Hỗ trợ chữ số và số tiếng Việt thường dùng, gồm số hàng trăm, `phẩy`, `nửa tiếng` và `giờ rưỡi`.

## Kiến trúc và kiểm tra

- `SpeechInputProvider` tách dịch vụ nhận dạng khỏi `VoiceInputViewModel` dùng `@Observable`.
- `VoiceActivityParser` dùng các mẫu khớp toàn câu, không đoán dựa trên một từ khóa. Nhận dạng đúng ngữ pháp không đảm bảo Speech nghe đúng mọi từ; các bản ghi vẫn sửa được trong Nhật ký.
- Khi Speech có confidence khác 0 nhưng dưới 0,5 ở bất kỳ từ nào trong kết quả cuối, ứng dụng yêu cầu sửa/nói lại. Confidence không được cung cấp (0) không được xem như bảo chứng chính xác.
- Mỗi lượt nghe giới hạn 55 giây, chờ kết quả cuối tối đa 3 giây sau dừng; lỗi/timeout giữ văn bản nhưng không tự lưu.
- Callback trễ/đúp bị bỏ qua. Nút lưu khóa trong lúc ghi; retry cùng nội dung/bé dùng lại cùng UUID. Chỉ xóa văn bản và báo thành công sau khi provider xác nhận lưu.
- Test bao gồm phân tích từng loại, thời gian, phủ định/thiếu dữ liệu, không lưu một phần, callback final/error/đúp, retry ổn định UUID và action lưu vào SwiftData rồi mở lại database.
- Cần nghiệm thu tiếng nói và micrô trên iPhone thật. Test tự động mô phỏng kết quả Speech, không xác nhận chất lượng âm thanh thực.

Tham khảo: [Apple SFSpeechRecognizer](https://developer.apple.com/documentation/speech/sfspeechrecognizer).
