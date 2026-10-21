# Trả lời App Review – Guideline 2.1 Information Needed (21/10/2026)

Apple yêu cầu 6 mục. Mục 1 (video quay trên máy thật) chỉ bạn làm được; mục 2–6 là text, dán nguyên phần "Reply" bên dưới vào Resolution Center và phần "Notes" vào App Review Information (đã cập nhật trên App Store Connect).

## A. Quay video (mục 1)

Chuẩn bị:

- iPhone 17 cập nhật iOS mới nhất. Đổi ngôn ngữ máy sang **English** (Settings → General → Language & Region) để reviewer đọc được; app tự theo ngôn ngữ máy.
- Cài bản đang review từ **TestFlight** (build 1.0 (1)), không dùng bản dev cài bằng cáp.
- Bật Screen Recording trong Control Center (Settings → Control Center → thêm Screen Recording). Không cần mic.
- Chuẩn bị một email mới để đăng ký trong video, ví dụ `thanhdo.vtb+applereview@gmail.com` (Gmail nhận được), và mở sẵn app Mail trên iPhone với hộp thư đó.

Kịch bản (3–5 phút, quay một mạch, không cắt):

1. Bắt đầu quay từ Home Screen → mở Bé Khỏe → màn hình đăng nhập.
2. **Đăng ký**: bấm "Sign up" → nhập email mới + mật khẩu → "Sign up & get started" → app báo kiểm tra email → sang Mail, mở thư "Confirm your signup" → bấm link → app tự mở lại và đã đăng nhập.
3. **Consent**: tick 3 ô → "Agree & Continue".
4. Tạo hồ sơ bé: tên, ngày sinh → Save.
5. Tab **Quick log**: ghi nhiệt độ 38.5 °C, một liều thuốc (chọn giờ nhắc tiếp theo), một cữ bú, bấm bắt đầu/kết thúc ngủ. Mở thẻ "Illness & medicine tracking" cho thấy biểu đồ và lịch nhắc thuốc.
6. Tab **Diary**: lướt qua danh sách. Tab **Statistics**: lướt, bấm "Share report (PDF / QR)" → xem preview → "Export PDF & share" → share sheet hiện ra → Cancel.
7. Avatar bé (góc trên) → Profile → nút Settings: mở "Privacy policy", "Consent status" rồi quay lại.
8. **Đăng xuất** (Profile → Settings/Account → Sign out) → **đăng nhập lại** bằng tài khoản vừa tạo (hoặc bằng Sign in with Apple để Apple thấy luồng này).
9. **Xoá tài khoản**: Profile → Settings → "Manage and delete data" → "Permanently delete account and all data" → xác nhận → app quay về màn hình đăng nhập. Xoá tài khoản vừa đăng ký, **không** xoá `thanhdo.vtb+review@gmail.com`.
10. Dừng quay.

Gửi video:

- Resolution Center: App Store Connect → app → **App Review** (cột trái) → submission bị từ chối → **Reply** → dán phần "Reply" bên dưới → đính kèm video (nếu quá giới hạn upload, tải video lên iCloud Drive/Google Drive, bật chia sẻ "Anyone with the link" và dán link vào reply).
- Không cần upload build mới; sau khi reply, Apple tiếp tục review build 1.0 (1).

## B. Reply (dán nguyên vào Resolution Center, giới hạn 4000 ký tự)

```
Hello App Review team,

Thank you for the review. The requested information is below; the same details are now in the Notes field of App Review Information.

1. Screen recording
Attached, recorded on an iPhone 17 running the latest iOS. It starts from launching the app and shows: email registration with the confirmation email, the consent screen, creating a child profile, logging temperature/medicine/feeding/sleep, the illness & medicine tracking card with reminders, the Diary and Statistics tabs, PDF report export, sign out, sign in (including Sign in with Apple) and account deletion (Profile > Settings > Manage and delete data > Permanently delete account and all data).
The app has no paid content, no in-app purchases and no user-generated content that is shared between users or made public, so reporting/blocking mechanisms do not apply.

2. Purpose and audience
Bé Khỏe is a private care diary for parents and caregivers of babies and young children (mainly Vietnamese families; UI in Vietnamese and English). During a fever or illness parents need to remember when the temperature was last taken, which medicine was given and when the next dose is allowed, and later show this history to a doctor. The app records what the family enters (temperature, medicines, symptoms, feeds, sleep, diapers, growth, vaccinations), shows a timeline, charts and statistics, reminds the next medication time the parent chose, and exports a PDF report. It does not diagnose, prescribe, calculate doses or give medical advice. Data belongs to the signed-in account; there are no social features, public profiles, chat or feeds.

3. Setup and access
- Demo account: the email/password in Sign-In Information (thanhdo.vtb+review@gmail.com); it already contains a child profile with sample entries. Sign in with Apple and Google are also available. New accounts can be created with any email; the confirmation link opens the app via babycare://auth-callback.
- First sign-in asks to accept three consent checkboxes (terms/privacy, child health data, cloud sync).
- Main features: "Quick log" tab (temperature, medicine, feeding, sleep, diaper, symptoms, voice entry, photos; illness & medicine tracking with reminders), "Diary" tab (timeline by day), "Statistics" tab (ranges, growth charts, "Share report (PDF / QR)"), avatar > child profiles (up to 4), vaccinations, Settings.
- Account deletion: Profile > Settings > Manage and delete data > Permanently delete account and all data (deletes all cloud data, revokes the Sign in with Apple token server-side).
- Optional permissions (microphone/speech, photos, notifications) are not required.

4. External services
Supabase (authentication, PostgreSQL database, storage for photos, one Edge Function that revokes the Sign in with Apple token on account deletion); Sign in with Apple; Google OAuth via Supabase Auth; Brevo SMTP relay for confirmation/reset emails; Apple Speech framework (Vietnamese, on-device when supported) for voice entry; GitHub Pages for the privacy policy and support pages (https://vuthanhdo.github.io/baby_care/). No analytics or advertising SDKs, no payment processors, no AI services, no third-party content providers.

5. Regional differences
None. The app works identically in all regions; only the UI language follows the device language (Vietnamese or English).

6. Regulated industry / third-party material
The app is not a medical device and provides no diagnosis, treatment recommendations or dose calculations; it only stores information entered by the parent, and every report carries a notice that it does not replace medical advice. It contains no protected third-party material; all text, icons and screenshots are our own.

Thank you,
Vu Thanh Do
```

## C. Notes (App Review Information → Notes; đã dán trên App Store Connect)

```
Bé Khỏe is a private care diary for parents of babies and young children (Vietnamese and English UI). It stores what the family enters (temperature, medicines, symptoms, feeds, sleep, diapers, growth, vaccinations), shows timeline/charts/statistics, reminds the medication time the parent chose and exports a PDF report for the doctor. It does not diagnose, prescribe or calculate doses. No social features, no public or shared user content, no paid content, no IAP.

ACCESS: use the demo account above (one child profile with sample entries is already created). Sign in with Apple and Google are also available. New accounts: sign up with any email; the confirmation link opens the app via babycare://auth-callback. First sign-in shows three consent checkboxes (terms/privacy, child health data, cloud sync) that must be accepted before editing data.

MAIN FEATURES: "Quick log" tab (temperature, medicine, feeding, sleep, diaper, symptoms, voice entry, photos; "Illness & medicine tracking" card with temperature chart and medication reminders), "Diary" tab (timeline by day), "Statistics" tab (ranges, growth charts, "Share report (PDF / QR)"), avatar → child profiles (up to 4), vaccinations, Settings.
ACCOUNT DELETION: Profile → Settings → Manage and delete data → Permanently delete account and all data (deletes all cloud data and revokes the Sign in with Apple token server-side).
Optional permissions (mic/speech, photos, notifications) are not required.

EXTERNAL SERVICES: Supabase (auth, PostgreSQL, storage for photos, one Edge Function for Apple token revocation); Sign in with Apple; Google OAuth via Supabase; Brevo SMTP for confirmation/reset emails; Apple Speech framework (Vietnamese, on-device when supported); GitHub Pages for privacy/support pages. No analytics, ads, payments, AI or third-party content.

REGIONS: identical in all regions; UI language follows the device (vi/en).
REGULATION: not a medical device, no diagnosis or treatment advice; reports carry a "does not replace medical advice" notice. No protected third-party material.

A screen recording of the full flow (launch, registration + email confirmation, consent, logging, reports, sign in with Apple, account deletion) was provided in the Resolution Center reply.
```
