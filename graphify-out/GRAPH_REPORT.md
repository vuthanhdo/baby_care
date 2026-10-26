# Graph Report - BabyCare  (2026-10-26)

## Corpus Check
- 407 files · ~1,520,401 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 2343 nodes · 6153 edges · 125 communities (112 shown, 13 thin omitted)
- Extraction: 85% EXTRACTED · 15% INFERRED · 0% AMBIGUOUS · INFERRED: 901 edges (avg confidence: 0.83)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `c32afa22`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- CloudSnapshot
- CareWindowMetrics
- View
- BabyEntity
- MeasurementEntryView
- BabyCareViewModel
- CareDataMutation
- CloudMediaAsset
- XCUIApplication
- .text
- MedicationReminder
- CareStorageStatus
- AuthCaptchaView
- CareCard
- CareTheme
- ActivityKind
- LocalCareReminderService
- Kiến trúc BabyCare
- AppAppearance
- FakeCloudRemote
- SessionViewModel
- CloudError
- .daySummary
- VoiceInputViewModel
- ActivityFormViewModel
- ActivityFormView
- Date
- .body
- CareIcon
- Foundation
- Mode
- Sendable
- BabyCareSchemaMigrationPlan
- ActivityFormAction
- ReportSection
- Components
- .applying
- CareReviewPolicy
- CareAsyncButton
- VaccinationEntryView
- CareDatabase
- DiaryView
- import_stitch_icons.py
- generate.py
- Kế hoạch database cloud cho BabyCare
- BabyCare — Agent workflow
- CareWeatherCondition
- BabyCareAction
- SupabaseCareDataProvider
- CloudCacheState
- StatisticsView
- SwiftUI
- .avatar
- .body
- String
- Vaccination Tracking
- ConsentViewModel
- FamilySharingView
- Đối chiếu giao diện Stitch → SwiftUI
- Rà soát crash và bộ nhớ — 11/09/2026
- Rà soát UI BabyCare — 11/09/2026
- Nhập và tự lưu bằng giọng nói
- Bật CAPTCHA cho BabyCare
- EntryReview-2026-09-12/README.md
- CameraCaptureView
- String
- GrowthChartView
- CareDataError
- CareEntryDetails.swift
- GrowthMetric
- CareTab
- XCTest
- SwiftDataCareDataProvider
- WeatherViewModel
- CodingKeys
- SymptomChoice
- AppLanguage
- ActivityDetailView
- .episodeSummary
- ControlledProvider
- render
- GrowthStandard
- .number
- ShareReportView
- StoreScreenshotsUITests
- AdaptiveLayoutUITests
- CodingKeys
- CareWeather
- BodyMeasurement
- String
- WeatherCardView
- ConsentUITests
- BabyProfile
- ActivityGroup
- CareActivity
- CareFont
- Nội dung App Store Connect — Bé Khỏe (BabyCare)
- Quy trình phát hành Bé Khỏe lên App Store
- SignInView
- CareDemoMode
- ConsentUITestFixture
- InsightDateRangeView
- BabyCare consent flow
- Growth/generate.py
- .reveal
- .count
- LanguageUITests
- Hai người cùng chăm một bé – nghiên cứu (24/10/2026)
- .vaccination
- Trả lời App Review – Guideline 2.1 Information Needed (21/10/2026)
- index.ts
- run-pglite.mjs
- Link chiến dịch App Store
- StitchAssetTests
- LegacyArchive
- AppStore/README.md
- templates/README.md
- store_screenshots.sh
- store_screenshots_duo.sh
- CarePreviewData.swift
- AuthCaptchaView.swift
- BabyCareUITests
- Phase
- SharingUITestFixture
- .init

## God Nodes (most connected - your core abstractions)
1. `CareActivity` - 118 edges
2. `BabyCareViewModel` - 91 edges
3. `CareDatabase` - 89 edges
4. `SessionViewModel` - 78 edges
5. `CareFont` - 72 edges
6. `ActivityFormView` - 61 edges
7. `CareIcon` - 58 edges
8. `BabyProfile` - 56 edges
9. `SupabaseCareDataProvider` - 55 edges
10. `ActivityKind` - 49 edges

## Surprising Connections (you probably didn't know these)
- `.body` --calls--> `AppRootView`  [INFERRED]
  BabyCare/BabyCareApp.swift → BabyCare/Views/Profile/AccountView.swift
- `ControlledProvider` --implements--> `CareDataProvider`  [EXTRACTED]
  BabyCareTests/BabyCareTests.swift → BabyCare/Data/CareDataProvider.swift
- `SuspendedStatusProvider` --implements--> `CareDataProvider`  [EXTRACTED]
  BabyCareTests/RuntimeSafetyTests.swift → BabyCare/Data/CareDataProvider.swift
- `FakeCloudCache` --calls--> `CloudCacheState`  [EXTRACTED]
  BabyCareTests/CloudProviderTests.swift → BabyCare/Data/Cloud/CloudCache.swift
- `FakeCloudCache` --implements--> `CareCloudCache`  [EXTRACTED]
  BabyCareTests/CloudProviderTests.swift → BabyCare/Data/Cloud/CloudCache.swift

## Import Cycles
- None detected.

## Communities (125 total, 13 thin omitted)

### Community 0 - "CloudSnapshot"
Cohesion: 0.11
Nodes (24): PendingCloudWrite, CloudChange, CloudEnvelope, CloudMapping, CloudReceipt, CloudSnapshot, CloudValue, bool (+16 more)

### Community 1 - "CareWindowMetrics"
Cohesion: 0.07
Nodes (35): CareAdaptiveRoot, .body, CareColumnsLayout, CareColumnsPlan, .isSplit, CareWindowMetrics, .usesSideTabs, CareWindowProbe (+27 more)

### Community 2 - "View"
Cohesion: 0.07
Nodes (39): AttributedString, AuthenticationServices, AccountFeedback, .body, AccountLoadingErrorView, .body, CareAccountSection, NewPasswordView (+31 more)

### Community 3 - "BabyEntity"
Cohesion: 0.15
Nodes (14): ActivityEntity, ActivityFollowUpEntity, BabyDetailsEntity, BabyEntity, CareMetadataEntity, MeasurementEntity, ReminderEntity, Bool (+6 more)

### Community 4 - "MeasurementEntryView"
Cohesion: 0.38
Nodes (9): MeasurementEntryView, .headValue, .heightValue, .isValid, .weightValue, Binding, Bool, Double (+1 more)

### Community 5 - "BabyCareViewModel"
Cohesion: 0.07
Nodes (27): BabyCareState, BabyCareViewModel, .activities, .babies, .baby, .hasOnboarded, .illnessStartDate, .illnessTitle (+19 more)

### Community 6 - "CareDataMutation"
Cohesion: 0.12
Nodes (17): CareDataMutation, .babyID, createBaby, deleteActivity, deleteBaby, deleteReminder, deleteVaccination, endIllness (+9 more)

### Community 7 - "CloudMediaAsset"
Cohesion: 0.17
Nodes (13): CloudMediaAsset, CloudMediaPlan, CloudMediaPurpose, activity, avatar, CloudMediaSyncResult, CloudMediaUpload, SHA256.Digest (+5 more)

### Community 8 - "XCUIApplication"
Cohesion: 0.27
Nodes (5): StitchAppearanceTests, String, CGRect, XCUIApplication, .windowFrame

### Community 9 - ".text"
Cohesion: 0.10
Nodes (24): ContentView, .body, CareBabyHeaderView, .body, CareDateTimeField, .body, .body, .body (+16 more)

### Community 10 - "MedicationReminder"
Cohesion: 0.34
Nodes (3): MedicationReminder, BabyCareTests, URL

### Community 11 - "CareStorageStatus"
Cohesion: 0.10
Nodes (14): CareStorageStatus, cached, cacheWarning, cloud, device, .message, RuntimeSafetyTests, SuspendedStatusProvider (+6 more)

### Community 12 - "AuthCaptchaView"
Cohesion: 0.13
Nodes (14): AuthCaptchaView, Coordinator, Context, Coordinator, Error, Void, WKNavigation, WKNavigationAction (+6 more)

### Community 13 - "CareCard"
Cohesion: 0.14
Nodes (18): CareCard, CareSectionTitle, .body, .body, InsightMetricView, .body, Color, ReportPreviewView (+10 more)

### Community 14 - "CareTheme"
Cohesion: 0.07
Nodes (29): CareTheme, EntryFieldLabel, .body, EntryFormCard, .body, EntryInputStyle, CGFloat, Content (+21 more)

### Community 15 - "ActivityKind"
Cohesion: 0.07
Nodes (27): ActivityKind, allergy, .assetName, bath, breathing, .defaultUnit, diaper, doctor (+19 more)

### Community 16 - "LocalCareReminderService"
Cohesion: 0.08
Nodes (21): pending, CareNotification, CareNotificationCenter, CareReminderService, LocalCareReminderService, NoopCareReminderService, Bool, Never (+13 more)

### Community 17 - "Kiến trúc BabyCare"
Cohesion: 0.06
Nodes (30): App language, Chia sẻ gia đình (26/10/2026, bản 1.2), Cloud provider đã tích hợp, Giao diện sáng/tối (25/10/2026), iPhone Duo (cập nhật 23/10/2026, Xcode 27.1), Kiến trúc BabyCare, Lưu dữ liệu trên device, Ranh giới các layer (+22 more)

### Community 18 - "AppAppearance"
Cohesion: 0.14
Nodes (14): AppAppearance, dark, .id, .interfaceStyle, light, system, AppearancePicker, .body (+6 more)

### Community 19 - "FakeCloudRemote"
Cohesion: 0.24
Nodes (6): VaccinationRecord, CloudProviderTests, FakeCloudCache, FakeCloudRemote, Int, String

### Community 20 - "SessionViewModel"
Cohesion: 0.06
Nodes (34): CloudFamilySummary, Int, Phase, accountError, consent, content, signedOut, starting (+26 more)

### Community 21 - "CloudError"
Cohesion: 0.07
Nodes (31): CloudConfiguration, CloudError, accessDenied, busy, conflict, consentRequired, .errorDescription, offline (+23 more)

### Community 22 - ".daySummary"
Cohesion: 0.29
Nodes (6): InsightDaySummary, .isEmpty, Bool, InsightDaySummaryTests, .start, Double

### Community 23 - "VoiceInputViewModel"
Cohesion: 0.06
Nodes (32): AnyObject, AVFoundation, ParseError, .errorDescription, Calendar, String, VoiceActivityParser, AppleSpeechInputProvider (+24 more)

### Community 24 - "ActivityFormViewModel"
Cohesion: 0.11
Nodes (17): ActivityFormViewModel, .attachments, .date, .detail, .loadingPhotos, .note, .number, .numeric (+9 more)

### Community 25 - "ActivityFormView"
Cohesion: 0.08
Nodes (29): ActivityFormView, .amountRow, .attachments, .checkHint, .date, .detail, .dirty, .isEditing (+21 more)

### Community 26 - "Date"
Cohesion: 0.23
Nodes (9): Date, BabyData, .selectedBaby, ShowcaseBuilder, Bool, ClosedRange, Double, Int (+1 more)

### Community 27 - ".body"
Cohesion: 0.06
Nodes (38): CareColumns, CareImageProcessor, Bool, Data, Int, UIImage, BabyProfileView, .birthdayLabel (+30 more)

### Community 28 - "CareIcon"
Cohesion: 0.14
Nodes (22): CareActivityRow, .body, CareBadge, CareIcon, .body, CarePrimaryButton, .body, CGFloat (+14 more)

### Community 29 - "Foundation"
Cohesion: 0.07
Nodes (21): BabyCare, CloudCacheRecord, Data, CareQuote, CareQuotes, Int, String, UserDefaults (+13 more)

### Community 30 - "Mode"
Cohesion: 0.25
Nodes (8): Mode, .color, food, growth, .icon, .id, medical, Self

### Community 31 - "Sendable"
Cohesion: 0.10
Nodes (32): CareFamilyRole, .canWrite, caregiver, owner, .summary, .title, viewer, CareSharingRemote (+24 more)

### Community 32 - "BabyCareSchemaMigrationPlan"
Cohesion: 0.14
Nodes (16): BabyCareSchemaMigrationPlan, .schemas, .stages, BabyCareSchemaV1, .models, .versionIdentifier, BabyCareSchemaV2, .models (+8 more)

### Community 33 - "ActivityFormAction"
Cohesion: 0.10
Nodes (20): ActivityFormAction, adjust, allergy, attachments, date, detail, followUp, loadingPhotos (+12 more)

### Community 34 - "ReportSection"
Cohesion: 0.18
Nodes (11): ReportSection, .color, feeding, .group, growth, .icon, .id, medical (+3 more)

### Community 35 - "Components"
Cohesion: 0.08
Nodes (25): 1. Primary Bottom Action Button (Floating CTA), 2. Category Activity Chips (Pill Filter), 3. Bottom Tab Bar (3 Primary Tabs), 4. Baby Profile Header & Switcher Sheet, 5. Status Banners (Persistent Ongoing Trackers), 6. Toast Notification with Quick Undo, 7. Form Inputs & Steppers, Action & Feedback Token (+17 more)

### Community 36 - ".applying"
Cohesion: 0.23
Nodes (11): CodingKeys, activities, illnessStartDate, illnessTitle, isTrackingIllness, measurements, medicationReminders, profile (+3 more)

### Community 37 - "CareReviewPolicy"
Cohesion: 0.10
Nodes (19): CareAppStore, CareReviewPolicy, CareReviewTracker, Moment, illnessEnded, reportShared, Bool, Calendar (+11 more)

### Community 38 - "CareAsyncButton"
Cohesion: 0.11
Nodes (18): .title, .background, CareAsyncButton, .body, .body, .body, CareChoiceChips, .body (+10 more)

### Community 39 - "VaccinationEntryView"
Cohesion: 0.22
Nodes (10): Bool, UUID, VaccinationEntryView, .baby, .body, .dirty, VaccinationHistoryView, .baby (+2 more)

### Community 40 - "CareDatabase"
Cohesion: 0.12
Nodes (11): CareDataProvider, InMemoryCareDataProvider, Bool, String, Bool, CareDatabase, DelayedCloudLoad, .waiting (+3 more)

### Community 41 - "DiaryView"
Cohesion: 0.13
Nodes (13): DiaryActivityCardView, .body, DiaryView, .addButton, .detailPane, .filtered, .listWidth, .selectedActivity (+5 more)

### Community 44 - "Kế hoạch database cloud cho BabyCare"
Cohesion: 0.17
Nodes (11): 10. Thông tin cần có khi bắt đầu triển khai, 1. Chọn Supabase Free, 2. Phạm vi và kiến trúc đích, 3. Schema đề xuất, 4. Đăng nhập và phân quyền, 5. API, ảnh và transaction, 6. Chuyển dữ liệu SwiftData hiện có lên cloud, 7. Đồng bộ offline (+3 more)

### Community 45 - "BabyCare — Agent workflow"
Cohesion: 0.18
Nodes (10): 1. Feature requirement, 2. Graphify graph, 3. Dependency / impact analysis, 4. Inspect đúng source cần thiết, 5. Implementation plan, 6. Code, 7. Tests, 8. Graphify impact/review (+2 more)

### Community 46 - "CareWeatherCondition"
Cohesion: 0.05
Nodes (37): CareWeatherCondition, blizzard, blowingDust, blowingSnow, breezy, clear, cloudy, drizzle (+29 more)

### Community 47 - "BabyCareAction"
Cohesion: 0.40
Nodes (5): BabyCareAction, commit, dismissError, load, showMessage

### Community 48 - "SupabaseCareDataProvider"
Cohesion: 0.15
Nodes (12): CareCloudCache, SupabaseCareDataProvider, .visibleDatabase, Bool, Never, Set, String, Task (+4 more)

### Community 49 - "CloudCacheState"
Cohesion: 0.11
Nodes (12): CloudCacheState, .queuedWrites, ModelContainer, ModelContext, URL, UUID, SwiftDataCloudCache, MemoryCloudCache (+4 more)

### Community 50 - "StatisticsView"
Cohesion: 0.20
Nodes (11): StatisticsView, .activities, .columns, .growth, .growthHistory, .interval, .medicalOverview, .medicines (+3 more)

### Community 51 - "SwiftUI"
Cohesion: 0.19
Nodes (6): AVFAudio, Charts, CoreImage.CIFilterBuiltins, PhotosUI, SwiftUI, UIKit

### Community 52 - ".avatar"
Cohesion: 0.61
Nodes (5): CarePreviewImages, CGFloat, CGSize, Data, String

### Community 53 - ".body"
Cohesion: 0.29
Nodes (4): .body, AuthValidation, String, AuthValidationTests

### Community 54 - "String"
Cohesion: 0.17
Nodes (14): CareInviteCode, Status, alreadyMember, expired, familyFull, invalid, joined, rateLimited (+6 more)

### Community 55 - "Vaccination Tracking"
Cohesion: 0.33
Nodes (5): Dependency / impact review, Deployment and compatibility, Login load regression (2026-09-13), Vaccination Tracking, Validation completed

### Community 56 - "ConsentViewModel"
Cohesion: 0.12
Nodes (22): Transport, Consent, ConsentRecord, ConsentRemote, ConsentStatus, .isCurrent, ConsentVersions, ConsentViewModel (+14 more)

### Community 57 - "FamilySharingView"
Cohesion: 0.17
Nodes (12): FamilySharingView, .body, .isOwner, InviteCodeSheet, InviteSheetItem, .id, JoinFamilySheet, .body (+4 more)

### Community 58 - "Đối chiếu giao diện Stitch → SwiftUI"
Cohesion: 0.40
Nodes (4): Các thay đổi, Kiểm tra, Điều chỉnh có chủ đích, Đối chiếu giao diện Stitch → SwiftUI

### Community 59 - "Rà soát crash và bộ nhớ — 11/09/2026"
Cohesion: 0.40
Nodes (4): Giới hạn, Kiểm chứng, Rà soát crash và bộ nhớ — 11/09/2026, Đã sửa

### Community 60 - "Rà soát UI BabyCare — 11/09/2026"
Cohesion: 0.50
Nodes (3): Kiểm chứng, Nguyên nhân và sửa đổi, Rà soát UI BabyCare — 11/09/2026

### Community 61 - "Nhập và tự lưu bằng giọng nói"
Cohesion: 0.50
Nodes (3): Các cách nói được hỗ trợ, Kiến trúc và kiểm tra, Nhập và tự lưu bằng giọng nói

### Community 64 - "CameraCaptureView"
Cohesion: 0.14
Nodes (14): Any, CameraCaptureView, .isAvailable, Coordinator, Bool, Context, Coordinator, UIImage (+6 more)

### Community 65 - "String"
Cohesion: 0.22
Nodes (7): AuthAction, resetPassword, signIn, signUp, Error, String, .appleButton

### Community 66 - "GrowthChartView"
Cohesion: 0.12
Nodes (20): Accessory, GrowthChartView, .chart, .curves, .points, .selected, .span, .visible (+12 more)

### Community 67 - "CareDataError"
Cohesion: 0.20
Nodes (9): CareDataError, babyNotFound, conflict, corruptData, .errorDescription, Double, String, .numericValue (+1 more)

### Community 68 - "CareEntryDetails.swift"
Cohesion: 0.10
Nodes (20): Band, BreathingReference, DoctorFollowUp, DoctorVisit, Row, SleepRecommendation, Calendar, ClosedRange (+12 more)

### Community 69 - "GrowthMetric"
Cohesion: 0.16
Nodes (13): CurvePoint, .id, GrowthLMS, GrowthMetric, height, .id, .unit, weight (+5 more)

### Community 70 - "CareTab"
Cohesion: 0.18
Nodes (14): Axis, CareBottomTabs, .body, .tabs, CareTab, diary, quick, statistics (+6 more)

### Community 71 - "XCTest"
Cohesion: 0.12
Nodes (5): BabyCareUITestsLaunchTests, MedicationFlowUITests, VaccinationUITests, XCTest, XCTestCase

### Community 72 - "SwiftDataCareDataProvider"
Cohesion: 0.24
Nodes (8): CarePersistenceConfiguration, .device, ModelContainer, ModelContext, Self, URL, SwiftDataCareDataProvider, Schema

### Community 73 - "WeatherViewModel"
Cohesion: 0.12
Nodes (19): AppleWeatherSource, CareLocationSource, CareLocationStatus, authorized, denied, notDetermined, CareWeatherAttribution, CareWeatherSource (+11 more)

### Community 74 - "CodingKeys"
Cohesion: 0.12
Nodes (17): CodingKeys, code, createdBy, email, expiresAt, familyID, id, invites (+9 more)

### Community 75 - "SymptomChoice"
Cohesion: 0.27
Nodes (5): SymptomCatalog, SymptomChoice, .token, .symptomFields, Collection

### Community 76 - "AppLanguage"
Cohesion: 0.07
Nodes (24): App, BabyCareApp, .body, .ageDescription, Int, String, VoicePhraseNormalizer, AppLanguage (+16 more)

### Community 77 - "ActivityDetailView"
Cohesion: 0.22
Nodes (10): ActivityDetailContent, .current, .repeatedEntry, ActivityDetailView, .body, Void, InsightActivityRow, .body (+2 more)

### Community 78 - ".episodeSummary"
Cohesion: 0.19
Nodes (8): .summary, InsightEpisodeSummary, .symptomNames, Calendar, Int, InsightEpisodeSummaryTests, .start, Double

### Community 79 - "ControlledProvider"
Cohesion: 0.21
Nodes (8): ControlledProvider, .isWaiting, RecordingReminderService, Bool, CheckedContinuation, Never, String, Void

### Community 80 - "render"
Cohesion: 0.22
Nodes (12): AppKit, CoreText, NSAttributedString, NSBitmapImageRep, NSColor, NSImage, NSSize, drawCentered() (+4 more)

### Community 81 - "GrowthStandard"
Cohesion: 0.11
Nodes (20): GrowthStandard, cdc, .id, .shortTitle, .title, Line, .id, p15 (+12 more)

### Community 82 - ".number"
Cohesion: 0.32
Nodes (6): .valid, InsightData, Double, .nutritionMetrics, Color, DateInterval

### Community 83 - "ShareReportView"
Cohesion: 0.27
Nodes (6): ShareReportView, .body, .canPreview, .columns, .exportControl, Int

### Community 84 - "StoreScreenshotsUITests"
Cohesion: 0.29
Nodes (4): StoreScreenshotsUITests, Bool, CGFloat, String

### Community 85 - "AdaptiveLayoutUITests"
Cohesion: 0.35
Nodes (5): sleep, AdaptiveLayoutUITests, Bool, String, XCUIElement

### Community 86 - "CodingKeys"
Cohesion: 0.20
Nodes (10): CodingKeys, allergies, avatarData, birthDate, bloodType, gender, healthNotes, id (+2 more)

### Community 87 - "CareWeather"
Cohesion: 0.12
Nodes (15): CareWeather, OutfitAdvice, OutfitItem, Double, Int, String, Phase, denied (+7 more)

### Community 88 - "BodyMeasurement"
Cohesion: 0.22
Nodes (6): BodyMeasurement, Double, MeasurementHistoryView, .body, .sorted, .hasChanges

### Community 89 - "String"
Cohesion: 0.15
Nodes (13): AllergyNote, .displayText, .line, .trimmed, MealEntry, String, .displayName, TemperatureDetail (+5 more)

### Community 90 - "WeatherCardView"
Cohesion: 0.36
Nodes (6): Double, String, Void, WeatherCardView, .attributionRow, .body

### Community 91 - "ConsentUITests"
Cohesion: 0.42
Nodes (3): ConsentUITests, Bool, XCUIElement

### Community 92 - "BabyProfile"
Cohesion: 0.25
Nodes (8): BabyProfile, .initial, Data, Decoder, EditableAllergy, ProfileHealthEditorView, .body, BabyLimitTests

### Community 93 - "ActivityGroup"
Cohesion: 0.13
Nodes (15): .color, ActivityGroup, .assetName, feeding, .id, medical, routine, .title (+7 more)

### Community 94 - "CareActivity"
Cohesion: 0.16
Nodes (12): CareActivity, ClosedRange, TemperatureChartView, .domain, .doses, .points, .selected, .selectedDose (+4 more)

### Community 95 - "CareFont"
Cohesion: 0.10
Nodes (24): CareFont, .breathingFields, .doctorFields, .medicineFields, .temperatureSiteFields, BreathingCounter, .body, Int (+16 more)

### Community 96 - "Nội dung App Store Connect — Bé Khỏe (BabyCare)"
Cohesion: 0.25
Nodes (7): 1. Thông tin chung (không theo ngôn ngữ), 2. English (U.K.) — localization chính, 3. Vietnamese — localization thêm, 4. App Privacy (privacy nutrition labels), 5. Age rating questionnaire, 6. App Review Information, Nội dung App Store Connect — Bé Khỏe (BabyCare)

### Community 97 - "Quy trình phát hành Bé Khỏe lên App Store"
Cohesion: 0.25
Nodes (7): A. Trước khi archive, B. Tạo app trên App Store Connect, C. Archive và upload từ Xcode, D. Nộp duyệt, E. Sau khi lên store, Lý do từ chối hay gặp và trạng thái của app, Quy trình phát hành Bé Khỏe lên App Store

### Community 98 - "SignInView"
Cohesion: 0.24
Nodes (9): Field, confirmation, email, password, SignInView, .captchaSection, .emailDivider, Set (+1 more)

### Community 99 - "CareDemoMode"
Cohesion: 0.25
Nodes (7): AppDependencies, CareDemoMode, .dataset, .hidesDemoBadge, .isActive, .isFullBuild, Bool

### Community 100 - "ConsentUITestFixture"
Cohesion: 0.29
Nodes (6): ConsentUITestFixture, .enabled, AsyncStream, AuthChangeEvent, Bool, Session

### Community 101 - "InsightDateRangeView"
Cohesion: 0.22
Nodes (7): InsightDateRangeView, .body, DateInterval, Void, Bool, DateInterval, Set

### Community 102 - "BabyCare consent flow"
Cohesion: 0.29
Nodes (6): BabyCare consent flow, Deployment and rollback, Known operational limits, Quyết định 14/10/2026: không gate theo phiên bản phía client, Runtime contract, Versions and existing users

### Community 103 - "Growth/generate.py"
Cohesion: 0.48
Nodes (6): cdc(), main(), Generate BabyCare/Domain/GrowthReferenceData.swift from the official growth…, swift_rows(), who_daily(), who_monthly()

### Community 104 - ".reveal"
Cohesion: 0.29
Nodes (4): FamilySharingUITests, CGFloat, Int, XCUIElement

### Community 105 - ".count"
Cohesion: 0.29
Nodes (6): Int, .sleepSummary, .body, UUID, VoiceEntryView, .body

### Community 107 - "Hai người cùng chăm một bé – nghiên cứu (24/10/2026)"
Cohesion: 0.33
Nodes (5): Backend đã có gì, Hai người cùng chăm một bé – nghiên cứu (24/10/2026), Những chỗ phải sửa trước khi mở tính năng, Thiết kế đề xuất, Ước lượng

### Community 108 - ".vaccination"
Cohesion: 0.39
Nodes (3): invalidInput, CareValidation, .valid

### Community 109 - "Trả lời App Review – Guideline 2.1 Information Needed (21/10/2026)"
Cohesion: 0.40
Nodes (4): A. Quay video (mục 1), B. Reply (dán nguyên vào Resolution Center, giới hạn 4000 ký tự), C. Notes (App Review Information → Notes; đã dán trên App Store Connect), Trả lời App Review – Guideline 2.1 Information Needed (21/10/2026)

### Community 111 - "run-pglite.mjs"
Cohesion: 0.40
Nodes (4): db, { PGlite }, require, root

### Community 112 - "Link chiến dịch App Store"
Cohesion: 0.50
Nodes (3): Link chiến dịch App Store, Mốc so sánh, Đọc số liệu

### Community 114 - "LegacyArchive"
Cohesion: 0.36
Nodes (6): LegacyArchive, LegacyJSONMigration, LegacySnapshot, Bool, String, URL

### Community 119 - "CarePreviewData.swift"
Cohesion: 0.38
Nodes (4): CarePreviewData, SeededGenerator, RandomNumberGenerator, UInt64

### Community 120 - "AuthCaptchaView.swift"
Cohesion: 0.29
Nodes (6): AuthCaptchaConfiguration, .isEnabled, .pageURL, Bool, URL, WebKit

### Community 122 - "Phase"
Cohesion: 0.40
Nodes (5): Phase, failed, idle, loading, ready

### Community 123 - "SharingUITestFixture"
Cohesion: 0.50
Nodes (3): SharingUITestFixture, .enabled, Bool

## Knowledge Gaps
- **449 isolated node(s):** `.isFullBuild`, `.isActive`, `.hidesDemoBadge`, `.enabled`, `StoreKit` (+444 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 719 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **13 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `ActivityKind` connect `ActivityKind` to `CloudSnapshot`, `ActivityFormAction`, `.text`, `.count`, `GrowthStandard`, `.number`, `StitchAssetTests`, `AdaptiveLayoutUITests`, `String`, `ActivityFormViewModel`, `ActivityFormView`, `ActivityGroup`, `CareActivity`, `Sendable`?**
  _High betweenness centrality (0.087) - this node is a cross-community bridge._
- **Why does `Date` connect `Date` to `CloudSnapshot`, `BabyEntity`, `BabyCareViewModel`, `CareDataMutation`, `.text`, `CareCard`, `LocalCareReminderService`, `FakeCloudRemote`, `.daySummary`, `VoiceInputViewModel`, `ActivityFormViewModel`, `ActivityFormView`, `.body`, `CareIcon`, `Sendable`, `ActivityFormAction`, `CareReviewPolicy`, `CareAsyncButton`, `ConsentViewModel`, `GrowthChartView`, `CareEntryDetails.swift`, `WeatherViewModel`, `AppLanguage`, `.episodeSummary`, `CareWeather`, `CareActivity`, `CareFont`, `InsightDateRangeView`, `.vaccination`, `LegacyArchive`?**
  _High betweenness centrality (0.086) - this node is a cross-community bridge._
- **Why does `CareActivity` connect `CareActivity` to `CloudSnapshot`, `BabyEntity`, `BabyCareViewModel`, `CareDataMutation`, `MedicationReminder`, `CareCard`, `ActivityKind`, `FakeCloudRemote`, `.daySummary`, `VoiceInputViewModel`, `ActivityFormViewModel`, `ActivityFormView`, `Date`, `CareIcon`, `Sendable`, `ActivityFormAction`, `CareReviewPolicy`, `DiaryView`, `CloudCacheState`, `StatisticsView`, `String`, `CareDataError`, `SwiftDataCareDataProvider`, `ActivityDetailView`, `.episodeSummary`, `.number`, `BodyMeasurement`, `String`, `BabyProfile`, `ActivityGroup`, `CareFont`, `LegacyArchive`?**
  _High betweenness centrality (0.082) - this node is a cross-community bridge._
- **Are the 54 inferred relationships involving `CareActivity` (e.g. with `.decode()` and `.read()`) actually correct?**
  _`CareActivity` has 54 INFERRED edges - model-reasoned connections that need verification._
- **Are the 46 inferred relationships involving `BabyCareViewModel` (e.g. with `.makeSession()` and `.makeSession()`) actually correct?**
  _`BabyCareViewModel` has 46 INFERRED edges - model-reasoned connections that need verification._
- **Are the 12 inferred relationships involving `CareDatabase` (e.g. with `.preserveUnavailableVaccinations()` and `.fourBabiesCanSwitchAndRetryButCannotAddFifth()`) actually correct?**
  _`CareDatabase` has 12 INFERRED edges - model-reasoned connections that need verification._
- **What connects `.isFullBuild`, `.isActive`, `.hidesDemoBadge` to the rest of the system?**
  _449 weakly-connected nodes found - possible documentation gaps or missing edges._