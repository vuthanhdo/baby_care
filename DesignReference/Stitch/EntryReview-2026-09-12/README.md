# Đối chiếu ba màn khởi đầu với Stitch

Nguồn: các export `ng_nh_p_b_kh_e`, `ng_k_b_kh_e`, `a_b_t_u_s_d_ng_t_o_h_s_b` (HTML và PNG trong thư mục Export).

- Đăng nhập: logo 80pt, tiêu đề 24pt, Google chuyển lên trên form với logo SVG đúng màu từ export; divider, card 16pt, trường 48pt, icon Material Symbols.
- Đăng ký: header quay về đăng nhập nằm cố định phía trên, card riêng có logo 64pt và badge Bước đầu tiên; Google và divider nằm trong card trước email/mật khẩu. Chuyển màn đặt lại vị trí cuộn, không che logo. Giữ trường nhập lại mật khẩu.
- Tạo bé: badge thương hiệu 32pt, tiêu đề 26pt nhấn xanh, card 20pt, avatar pastel, nhãn bắt buộc, nền ô nhập xám nhạt, nút giới tính riêng, ghi chú ngoài card, CTA có mũi tên. Đã sửa lỗi viền ô tên bị lặp.

Các khác biệt theo chức năng đang hỗ trợ: email thay cho số điện thoại; không hiển thị Apple/Face ID, tên bố mẹ, điều khoản chưa có nội dung . Màn tạo bé đã bổ sung nút chọn ảnh từ Photos, xem trước, bỏ ảnh để dùng chữ cái, và lưu avatar cùng hồ sơ qua provider hiện có. Luồng xác thực bằng link email, CAPTCHA đang tắt và tối đa 4 bé được giữ nguyên.

Kiểm thử gồm đăng nhập/đăng ký và ẩn-hiện mật khẩu; màn chờ link email; tạo bé → ghi nhiệt độ → tắt/mở app vẫn giữ dữ liệu. Ảnh trong thư mục là bản build thật trên iPhone 17 Simulator, iOS 26.5. Không phải cam kết trùng từng pixel hoặc kiểm chứng gửi email/Google OAuth thực tế.
