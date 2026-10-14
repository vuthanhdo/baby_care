# BabyCare — Agent workflow

Áp dụng cho toàn bộ repository này. Mọi yêu cầu thêm feature, sửa lỗi hoặc refactor phải tuân theo thứ tự:

```text
Feature requirement
        ↓
  Graphify graph
        ↓
Dependency / impact analysis
        ↓
Inspect đúng source cần thiết
        ↓
Implementation plan
        ↓
      Code
        ↓
      Tests
        ↓
Graphify impact/review
```

## 1. Feature requirement

- Xác định hành vi cần có, tiêu chí hoàn thành, phạm vi và các ràng buộc của người dùng.
- Nêu rõ giả định ảnh hưởng đến thiết kế. Chỉ hỏi khi thiếu thông tin thực sự ngăn cản tiến độ; không tự mở rộng phạm vi.
- Nếu người dùng chỉ yêu cầu phân tích hoặc kế hoạch, dừng ở mức đó; không sửa code.

## 2. Graphify graph

- Dùng skill Graphify và graph hiện có trước khi khám phá source.
- Đường dẫn tính từ repository root chứa file này:
  - `graphify-out/GRAPH_REPORT.md`
  - `graphify-out/graph.json`
- Đọc report trước, sau đó query graph theo các symbol và vocabulary thực tế để tìm điểm bắt đầu, các dependency và test liên quan.
- Kiểm tra độ mới của graph bằng metadata commit, HEAD và working-tree changes. Commit trùng nhau chưa chứng minh graph chứa thay đổi chưa commit.
- Không rebuild hoặc chạy full extraction chỉ để trả lời một câu hỏi. Nếu graph thiếu, cũ hoặc không đủ dữ liệu, nói rõ giới hạn và kiểm chứng bằng source có mục tiêu; không bịa relationship.
- Phân biệt `EXTRACTED`, `INFERRED` và `AMBIGUOUS`. Graph vô hướng và shortest path không tự chứng minh chiều gọi hay luồng thực thi.

## 3. Dependency / impact analysis

Trước khi sửa code, trình bày ngắn gọn:

- Component/model/pattern hiện có cần tái sử dụng.
- Luồng View → ViewModel → Domain / CareDataMutation → CareDataProvider; xác minh thứ tự thực tế vì reducer có thể chạy trong provider.
- Tác động tới SwiftData, Supabase, wire mapping, offline cache/outbox và migration nếu liên quan.
- Shared services, reminder, session/account/baby isolation và dependency có mức ảnh hưởng cao.
- Test hiện có cần mở rộng, rủi ro và phạm vi không cần thay đổi.

Điều chỉnh độ chi tiết theo thay đổi; không biến sửa nhỏ thành một đợt audit toàn bộ project.

## 4. Inspect đúng source cần thiết

- Từ kết quả graph, đọc đúng file/symbol cần xác minh; ưu tiên `rg` và đọc có giới hạn.
- Mở rộng kiểm tra khi source cho thấy dependency bị thiếu trong graph hoặc có mâu thuẫn.
- Xác minh call direction, invariants, transaction boundaries, serialization, migration và lifecycle trước khi dựa vào chúng để thiết kế.
- Gắn finding quan trọng với file và dòng source. Không coi graph hoặc tên test là bằng chứng test đang pass.

## 5. Implementation plan

- Trình bày kế hoạch trước khi code: hành vi sau thay đổi, file/component dự kiến sửa, thứ tự triển khai, migration/compatibility và cách kiểm thử.
- Chọn thay đổi kiến trúc nhỏ nhất đáp ứng đầy đủ requirement; tái sử dụng mutation/provider và service interfaces hiện có khi phù hợp.
- Không tạo repository, service hoặc ViewModel mới nếu chưa có lý do cụ thể.
- Kế hoạch không phải một cổng xin phép mặc định. Tiếp tục triển khai nếu người dùng đã yêu cầu implementation; chỉ chờ khi người dùng yêu cầu duyệt trước hoặc còn quyết định bắt buộc chưa rõ.

## 6. Code

- Chỉ sửa trong phạm vi kế hoạch và requirement; bảo toàn thay đổi đang có của người dùng.
- Nếu phát hiện tác động mới đáng kể, cập nhật impact analysis và kế hoạch trước khi mở rộng code.
- Giữ domain validation, ownership và atomic mutations ở đúng boundary; không đặt persistence hoặc notification side effects trong View.
- Khi thay đổi dữ liệu, xử lý tương thích store, Codable cache, outbox replay và cloud contract theo phạm vi thực tế.

## 7. Tests

- Chạy build và test phù hợp với thay đổi. Thêm hoặc sửa test cho hành vi mới, regression và failure modes thực sự có rủi ro.
- Với persistence/sync: kiểm tra migration, reopening, retry identity, offline durability, conflict và account/baby isolation khi bị ảnh hưởng.
- Với UI/service: kiểm tra validation, failed-save behavior, lifecycle và notification reconciliation khi liên quan.
- Không thêm test chỉ để lặp lại implementation hoặc cho thay đổi tài liệu đơn giản.
- Ghi rõ check đã chạy, kết quả và check chưa chạy cùng lý do; không tuyên bố pass nếu chưa kiểm chứng.

## 8. Graphify impact/review

- Sau implementation và tests, đối chiếu diff với các dependency và impact paths đã tìm bằng Graphify.
- Kiểm tra caller/consumer bị bỏ sót, mapping không đồng bộ, migration thiếu, shared-service lifecycle và test regression.
- Với code mới chưa có trong graph, review bằng source/diff và nêu rõ giới hạn của graph cũ.
- Khi cần đồng bộ graph và người dùng không cấm, ưu tiên incremental update theo skill Graphify; không mặc định full rebuild. Nếu không update, ghi rõ graph chưa phản ánh thay đổi mới.
- Nếu review dẫn đến sửa code, chạy lại các check liên quan rồi review lại phần thay đổi.
- Báo cáo cuối gồm: thay đổi, impacted components/dependency paths, validation đã thực hiện, rủi ro còn lại và trạng thái graph.

## Nguyên tắc chung

- Chỉ dẫn cụ thể của người dùng quyết định phạm vi công việc trong giới hạn các chỉ dẫn cấp cao hơn.
- Với yêu cầu read-only: không sửa code, không rebuild/update graph; chỉ query và kiểm chứng source cần thiết.
- Không tự commit, deploy hoặc thay đổi backend đang chạy chỉ vì workflow này có bước Code hoặc Tests.
