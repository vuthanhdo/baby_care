# Nội dung App Store Connect — Bé Khỏe (BabyCare)

App đã tạo trên App Store Connect (id 6824822487) với tên **Bé Khỏe – Baby Care Diary**, ngôn ngữ chính **English (U.K.)**. Mỗi mục dưới đây có bản tiếng Anh (dán vào localization English U.K.) và bản tiếng Việt (dán vào localization Vietnamese, thêm bằng nút English (U.K.) ▾ → Add Localization). Giới hạn ký tự ghi trong ngoặc, tất cả đã kiểm tra.
Screenshot: `screenshots/iphone-6.3/<en|vi>` cho khung iPhone (medium display), `screenshots/ipad-13/<en|vi>` cho khung iPad 13", `screenshots/iphone-duo/<en|vi>` cho iPhone Duo. Từ 1.1 upload bản có tiêu đề trong `screenshots/captioned/…`, sinh bằng `swift Tools/store_captions.swift` từ tiêu đề trong `captions.json` (đổi chữ ở đó rồi chạy lại). Ảnh bị khóa khi bản đang Waiting for Review; keyword và promotional text thì vẫn sửa được. Link chiến dịch cho từng kênh: `CAMPAIGNS.md`.

## 1. Thông tin chung (không theo ngôn ngữ)

| Mục | Giá trị |
| --- | --- |
| Bundle ID | `com.vuthanhdo.BabyCare` |
| SKU | `bekhoe-ios` |
| Primary language | English (U.K.) |
| Category | Primary: Health & Fitness · Secondary: Medical |
| Privacy Policy URL | https://vuthanhdo.github.io/baby_care/privacy.html |
| Support URL | https://vuthanhdo.github.io/baby_care/index.html |
| Marketing URL | (trống) |
| Copyright | 2026 Vu Thanh Do |
| Version | 1.2 (build 4); trước đó 1.0 (1), 1.0.1 (2), 1.1 (3) |
| Age rating | 4+ (trả lời None/No cho mọi câu; Medical/Treatment Information: None; không quảng cáo; từ 1.2 User-Generated Content = Yes vì bảng bình chọn tính năng, nội dung được duyệt trước) |
| Content rights | Does not contain, show, or access third-party content |
| Advertising Identifier (IDFA) | No |
| Export compliance | Đã khai `ITSAppUsesNonExemptEncryption = NO` (chỉ HTTPS) |
| Sign-in | Email/password, Sign in with Apple, Google |

## 2. English (U.K.) — localization chính

**Name (30):** `Bé Khỏe – Baby Care Diary`

**Subtitle (30):** `Fever, meds, feeds, vaccines`

**Promotional text (170):** 1.0.x: chưa điền. 1.1:
`New in 1.1: weather and what to dress your baby in, a 60-second breathing counter, follow-up visit reminders, growth reference curves and dark mode.`
1.2 (đổi ngay sau khi phát hành 1.2):
`New in 1.2: share your baby's diary with family or a nanny, send feedback with screenshots, and vote for the features you want next.`

**Keywords (100):** từ 1.1 (25/10/2026). Tên và subtitle đã được Apple đánh chỉ mục, nên không lặp lại baby/care/diary/fever/meds/feeds/vaccines:
`tracker,newborn,infant,toddler,feeding,breastfeeding,pumping,nap,sleep,diaper,temperature,growth,log`
1.0.x: `baby tracker,newborn,feeding,sleep,diaper,fever,medication,vaccine,growth,baby log,parenting,infant`

**Description (4000):**
```
Bé Khỏe is a care diary for parents: log in seconds, see the whole picture, and have everything ready at the doctor's.

QUICK LOGGING
• Temperature, medicines, symptoms, doctor visits, allergies
• Milk feeds, meals, water
• Sleep (start and stop), baths, diaper changes
• Voice entry and up to 3 photos per entry
• A "Today" card with feeds, sleep hours, diapers and medicines

ILLNESS TRACKING
• Start an episode when your child has a fever: peak temperature, readings, doses, latest symptoms
• Temperature chart by the hour with every dose marked
• Medication reminders: log a dose and pick the next moment (+4, +6, +8, +12 hours or your own time)
• Episode diary grouped by day; end the episode whenever you want

STATISTICS AND REPORTS
• Today, 48 hours, 7 days or a custom range
• Milk, sleep and meals per day; weight and height charts
• Export a PDF report or a QR code for the doctor or grandparents

PROFILES AND VACCINATIONS
• Up to 4 children per family, switch with one tap
• Vaccination history with next doses and reminders
• Allergies, blood type and care notes

SHARE WITH THE FAMILY
• Invite grandparents, your partner or a nanny with a one-time code
• Caregivers can log, viewers can only look; change roles or remove members anytime
• Pull down to see what the family just logged

YOUR DATA
• Cloud sync; works offline and syncs when back online
• Delete a child profile or the whole account inside the app
• iPhone and iPad, Vietnamese and English

FEEDBACK
• Report a bug with screenshots or send an idea from the Feedback tab
• Vote for the features you want next

Bé Khỏe records what the family enters. It does not diagnose, prescribe or replace a doctor's advice. If a child shows serious symptoms, contact a healthcare provider.
```

**What's New (4000):** 1.0: `First release.` · 1.0.1:
```
• Optimised for iPhone Duo and iPad: on large displays the tabs move to the side and screens split into two columns that stay clear of the fold.
• The diary shows an entry's details right next to the list; fold or unfold iPhone Duo and you stay on the same entry.
• A clear message when you sign up with an email that already has an account.
• Minor layout and translation fixes.
```
1.1:
```
• Weather and what to dress your baby in when going out
• Growth charts with reference curves for boys and girls; pinch to zoom
• Breathing rate log with a 60-second counter and age-based references
• More detailed symptoms (Fever added; dry or wet cough…)
• Temperature: thermometer type, rectal site and the normal range for each site
• Doctor visits: diagnosis, advice and a follow-up date reminded 2 days ahead
• Allergies (name, severity, certainty) and medical history in the baby's profile
• Log a nap after your baby wakes up, with recommended sleep hours
• Photograph medicine with the camera; meals record food and amount
• Dark mode that follows your device, changeable in Settings
• Sync fixes and stability improvements
```
1.2:
```
• Family sharing: invite grandparents, your partner or a nanny with a one-time code, as a caregiver who can log or a viewer who can only look
• Switch between families, change roles or remove members; an invited caregiver can join right from the first screen
• Pull down to refresh and see what the family just logged
• New Feedback tab: report a bug with screenshots or send us an idea
• Vote on features: suggest one and vote for what we build next
• A clearer choice when starting illness tracking after a fever reading
• Fixes and stability improvements
```

## 3. Vietnamese — localization thêm

**Name (30):** `Bé Khỏe – Nhật ký chăm bé` (tên đầu tiên `Bé Khỏe: Nhật ký chăm sóc bé` bị báo trùng; nếu tên này cũng trùng, dùng `Nhật ký Bé Khỏe`)

**Subtitle (30):** `Sốt, thuốc, bú ngủ, tiêm chủng`

**Promotional text (170):** 1.0.x: chưa điền. 1.1:
`Mới ở bản 1.1: thời tiết và gợi ý trang phục cho bé, đếm nhịp thở 60 giây, nhắc lịch tái khám, biểu đồ tăng trưởng có đường chuẩn và giao diện tối.`
1.2 (đổi ngay sau khi phát hành 1.2):
`Mới ở bản 1.2: chia sẻ nhật ký của bé với người thân hoặc bảo mẫu, gửi góp ý kèm ảnh chụp màn hình và bình chọn tính năng bạn muốn có.`

**Keywords (100):** từ 1.1 (25/10/2026), không lặp từ đã có trong tên/subtitle (bé, khỏe, nhật ký, chăm, sốt, thuốc, bú, ngủ, tiêm chủng). Giới hạn tính theo ký tự, không theo byte:
`theo dõi,trẻ sơ sinh,ăn dặm,sữa mẹ,hút sữa,nhiệt độ,nhiệt kế,hạ sốt,tã,cân nặng,chiều cao,vắc xin`
1.0.x: `nhật ký bé,chăm sóc trẻ,sốt,nhiệt độ,thuốc,tiêm chủng,bú sữa,giấc ngủ,tã,tăng trưởng,baby tracker`

**Description (4000):**
```
Bé Khỏe là cuốn nhật ký chăm sóc bé dành cho bố mẹ Việt: ghi trong vài giây, nhìn lại cả quá trình, và có sẵn mọi thứ khi đi khám.

GHI NHANH TRONG VÀI GIÂY
• Nhiệt độ, thuốc đã uống, triệu chứng, lần đi khám, dị ứng
• Cữ sữa, bữa ăn, nước uống
• Giấc ngủ (bấm bắt đầu, bấm kết thúc), tắm, thay tã
• Nhập bằng giọng nói tiếng Việt, đính kèm tối đa 3 ảnh mỗi lần ghi
• Thẻ "Hôm nay" tóm tắt cữ sữa, giờ ngủ, số lần thay tã và thuốc

THEO DÕI ĐỢT ỐM
• Bắt đầu một đợt theo dõi khi bé sốt: đỉnh sốt, số lần đo, số liều thuốc, triệu chứng gần nhất
• Biểu đồ thân nhiệt theo giờ, đánh dấu từng lần dùng thuốc
• Lịch nhắc thuốc: ghi liều vừa uống là app hỏi ngay mốc tiếp theo (+4, +6, +8, +12 giờ hoặc giờ bạn chọn)
• Nhật ký đợt ốm gom theo ngày, kết thúc đợt bất cứ lúc nào

THỐNG KÊ VÀ BÁO CÁO
• Thống kê theo hôm nay, 48 giờ, 7 ngày hoặc khoảng tùy chọn
• Lượng sữa, giờ ngủ, bữa ăn theo ngày; biểu đồ cân nặng và chiều cao
• Xuất báo cáo PDF hoặc mã QR để gửi bác sĩ, ông bà

HỒ SƠ VÀ TIÊM CHỦNG
• Tối đa 4 bé trong một gia đình, chuyển bé trong một chạm
• Lịch sử tiêm chủng với mũi tiếp theo và lời nhắc trước ngày hẹn
• Dị ứng, nhóm máu, thói quen chăm sóc

CHIA SẺ CÙNG GIA ĐÌNH
• Mời ông bà, bố mẹ hoặc bảo mẫu bằng mã dùng một lần
• Người cùng chăm sóc được ghi, người chỉ xem thì không; đổi vai trò hoặc gỡ thành viên bất cứ lúc nào
• Kéo xuống để thấy ngay những gì người nhà vừa ghi

DỮ LIỆU CỦA BẠN
• Đồng bộ cloud; hoạt động offline, tự đồng bộ khi có mạng
• Xóa hồ sơ bé hoặc toàn bộ tài khoản ngay trong app
• Hỗ trợ iPhone, iPad, tiếng Việt và tiếng Anh

GÓP Ý
• Báo lỗi kèm ảnh chụp màn hình hoặc gửi ý tưởng từ tab Góp ý
• Bình chọn tính năng bạn muốn có tiếp theo

Bé Khỏe chỉ ghi nhận thông tin do gia đình nhập, không chẩn đoán, không kê đơn và không thay thế tư vấn của bác sĩ. Khi bé có dấu hiệu nghiêm trọng, hãy liên hệ cơ sở y tế.
```

**What's New (4000):** 1.0: `Phiên bản đầu tiên.` · 1.0.1:
```
• Tối ưu cho iPhone Duo và iPad: trên màn hình lớn, thanh tab chuyển sang cạnh trái và các màn chia hai cột, tránh nếp gấp.
• Nhật ký hiện chi tiết ngay bên cạnh danh sách; gập hoặc mở iPhone Duo vẫn giữ nguyên mục bạn đang xem.
• Báo rõ khi đăng ký bằng email đã có tài khoản.
• Sửa một số lỗi hiển thị và bản dịch.
```
1.1:
```
• Thời tiết và gợi ý trang phục cho bé khi ra ngoài
• Biểu đồ tăng trưởng có đường chuẩn cho bé trai, bé gái; phóng to được
• Ghi nhịp thở với bộ đếm 60 giây và mốc theo tuổi
• Triệu chứng chi tiết hơn (thêm Sốt, ho khan, ho có đờm…)
• Đo nhiệt độ: loại nhiệt kế, vị trí hậu môn, nhiệt độ bình thường từng vị trí
• Đi khám: chẩn đoán, lời dặn, lịch tái khám và nhắc trước 2 ngày
• Dị ứng (tên, mức độ, độ chắc chắn) và tiền sử bệnh lý trong hồ sơ bé
• Giấc ngủ ghi được sau khi bé dậy, kèm thời gian ngủ khuyến cáo
• Chụp ảnh thuốc bằng camera; bữa ăn ghi thực phẩm và số lượng
• Giao diện tối theo máy, đổi được trong Cài đặt
• Sửa lỗi đồng bộ và cải thiện độ ổn định
```
1.2:
```
• Chia sẻ gia đình: mời ông bà, bố mẹ hoặc bảo mẫu bằng mã dùng một lần, với vai trò cùng chăm sóc (được ghi) hoặc chỉ xem
• Chuyển qua lại giữa các gia đình, đổi vai trò, gỡ thành viên; người được mời tham gia ngay từ màn hình đầu tiên
• Kéo xuống để cập nhật những gì người nhà vừa ghi
• Tab Góp ý mới: báo lỗi kèm ảnh chụp màn hình hoặc gửi ý tưởng cho nhà phát triển
• Bình chọn tính năng: đề xuất và bình chọn tính năng bạn muốn có tiếp theo
• Hỏi rõ ràng hơn khi bắt đầu theo dõi đợt ốm sau lần đo sốt
• Sửa lỗi và cải thiện độ ổn định
```

## 4. App Privacy (privacy nutrition labels)

Chọn **Data Linked to You** cho từng loại, mục đích **App Functionality**, không dùng cho tracking, không dùng cho quảng cáo:

| Category | Data type | Ghi chú |
| --- | --- | --- |
| Contact Info | Email Address | Tài khoản đăng nhập |
| Health & Fitness | Health | Nhiệt độ, thuốc, triệu chứng, số đo của bé |
| User Content | Photos or Videos | Ảnh đính kèm, ảnh đại diện bé, ảnh chụp màn hình gửi kèm góp ý |
| User Content | Customer Support | Nội dung góp ý và báo lỗi (từ 1.2) |
| User Content | Other User Content | Nhật ký, hồ sơ bé, ghi chú, đề xuất tính năng và phiếu bình chọn |
| Identifiers | User ID | Supabase user id |
| Diagnostics | Other Diagnostic Data | Phiên bản app và iOS, kiểu máy, ngôn ngữ, chế độ lưu gửi kèm góp ý (từ 1.2) |

Không thu thập: vị trí, danh bạ, lịch sử duyệt web, dữ liệu tài chính, dữ liệu crash và hiệu năng. Từ 1.1, thẻ thời tiết gửi vị trí gần đúng tới Apple WeatherKit chỉ để lấy thời tiết tức thời và không lưu, nên không tính là thu thập theo định nghĩa của Apple; chính sách quyền riêng tư nêu rõ việc này. Ảnh chụp bằng camera thuộc mục Photos or Videos đã khai. Âm thanh nhập giọng nói do Apple Speech xử lý, không lưu. Khai báo khớp `BabyCare/PrivacyInfo.xcprivacy`.

## 5. Age rating questionnaire

Trả lời **None** cho Cartoon/Fantasy/Realistic Violence, Profanity, Mature/Suggestive Themes, Horror/Fear, Medical/Treatment Information, Alcohol/Tobacco/Drug, Sexual Content, Gambling, Contests; **No** cho Unrestricted Web Access, Gambling and Contests, Loot Boxes, Parental Controls, Age Assurance. Kết quả 4+.

Từ 1.2 (đổi lúc nộp duyệt, App Information → Age Ratings): **User-Generated Content = Yes** (bảng bình chọn tính năng: đề xuất của người dùng hiện cho mọi người sau khi được duyệt); Social Media, Messaging and Chat, Advertising vẫn **No**. Xem lại xếp hạng kết quả trước khi lưu.

## 6. App Review Information

**Sign-in required**: bật; email và mật khẩu lấy từ `review-account.local.txt` (tài khoản `thanhdo.vtb+review@gmail.com`, đã xác nhận, có 1 hồ sơ bé và vài bản ghi).

**Contact**: họ tên, số điện thoại, email của bạn.

**Notes 1.2 (EN, dán nguyên; bản 1.1 nằm trong lịch sử git):**
```
Bé Khỏe is a private care diary for parents of babies and young children. It stores what the family enters (temperature, medicines, symptoms, feeds, sleep, diapers, growth, vaccinations), shows timeline/charts/statistics, reminds the medication time the parent chose and exports a PDF report for the doctor. It does not diagnose, prescribe or calculate doses. No ads, paid content or IAP.

ACCESS: use the demo account above (one child profile with sample entries is already created). Sign in with Apple and Google are also available. New accounts: sign up with any email; the confirmation link opens the app via babycare://auth-callback. First sign-in shows three consent checkboxes (terms/privacy, child health data, cloud sync) that must be accepted before editing data.

MAIN FEATURES: tabs "Quick log" (temperature, medicine, feeds, sleep, diapers, symptoms, doctor visits, weather, illness tracking with medication reminders), "Diary", "Statistics" (CDC 2000 growth charts, "Share report (PDF / QR)") and "Feedback"; avatar → child profiles and vaccinations; gear icon → Settings.

NEW IN 1.2
1. FAMILY SHARING (Settings → Account → Family & sharing): the owner invites a "Caregiver" (can log) or a "View only" member with an 8-character code that works once and expires after 48 hours. Members see the family's baby profiles and each other's email address; the owner can change roles or remove members, and anyone can leave. The invited person enters the code under "Join another family" on the same screen, or on the first-run screen. Sharing stays inside the invited family; nothing is public. To try it, sign up a second account and enter a code created with the demo account.
2. FEEDBACK tab → "Send feedback": a bug report, suggestion or question with up to 3 screenshots, sent privately to the developer. The app/iOS version and device model sent with it are shown before sending; we reply by email only if the user ticks "Allow a reply by email".
3. FEEDBACK tab → "Vote on features": users suggest a feature (short title, optional details) and vote for published suggestions, one vote each; tapping again removes the vote.

USER-GENERATED CONTENT (Guideline 1.2): feature suggestions are the only content a user can show to others.
- Filtering: every new suggestion stays "Under review" and is visible only to its author until the developer approves it.
- No identities: authors and voters are never shown; there are no profiles, comments or messages, so users cannot see, contact or target each other.
- Reporting: long-press a published suggestion → "Report inappropriate content". Reports are reviewed within 24 hours: the content is removed and the offending account is suspended, which is how abusive users are blocked.
- Terms of Use section 5 forbids objectionable content and personal details; at most 5 suggestions per account per day.

ACCOUNT DELETION: Settings → Manage and delete data → Permanently delete account and all data. It deletes the account's cloud data, photos, feedback, suggestions and votes and revokes the Sign in with Apple token server-side; a family that still has other members passes to its longest-standing member.
Permissions (mic, photos, camera, location, notifications) are optional; approximate location is asked only for "Show weather", sent to Apple WeatherKit and not stored.

EXTERNAL SERVICES: Supabase (auth, PostgreSQL, private storage for photos and feedback screenshots, one Edge Function for Apple token revocation); Sign in with Apple; Google OAuth via Supabase; Brevo SMTP for confirmation/reset emails; Apple Speech; Apple WeatherKit; GitHub Pages for privacy/support pages. No analytics, ads, payments, AI or third-party content.

REGIONS: identical in all regions; UI language follows the device (vi/en).
REGULATION: not a medical device, no diagnosis or treatment advice; reports carry a "does not replace medical advice" notice. No protected third-party material.
```

**Attachment**: video quay trên máy thật (xem `REVIEW_REPLY.md`); Apple yêu cầu từ lần review đầu (21/10/2026).

**Version release**: Manually release this version.
