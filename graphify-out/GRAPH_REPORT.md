# Graph Report - BabyCare  (2026-11-01)

## Corpus Check
- 435 files · ~1,537,209 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 2651 nodes · 6878 edges · 139 communities (122 shown, 17 thin omitted)
- Extraction: 86% EXTRACTED · 14% INFERRED · 0% AMBIGUOUS · INFERRED: 960 edges (avg confidence: 0.83)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `6fdc04b8`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- CloudSnapshot
- CareColumnsLayout
- .body
- MedicationReminder
- BodyMeasurement
- BabyCareViewModel
- CareDataMutation
- Sendable
- .reveal
- NextDoseView
- BabyCareTests
- CareStorageStatus
- CameraCaptureView
- View
- .text
- ActivityKind
- LocalCareReminderService
- Kiến trúc BabyCare
- AppAppearance
- FakeCloudRemote
- SessionViewModel
- CloudError
- LogActivityKind
- VoiceInputViewModel
- ActivityFormViewModel
- ActivityFormView
- Date
- .body
- CareActivity
- Foundation
- GrowthStandard
- Equatable
- .seedV1
- .plan
- ReportSection
- Components
- .applying
- CareReviewPolicy
- CarePrimaryButton
- .count
- SupabaseSharingRemote
- .create
- import_stitch_icons.py
- generate.py
- Kế hoạch database cloud cho BabyCare
- BabyCare — Agent workflow
- CareWeatherCondition
- GrowthChartView
- SupabaseCareDataProvider
- RevisionRemote
- .normalize
- SupabaseRemote
- SwiftDataCloudCache
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
- CareDatabase
- WidgetText
- GrowthMetric
- QuickLogError
- TemperatureDetail
- CloudFamilySummary
- CareTab
- XCTest
- SwiftDataCareDataProvider
- CareWeatherService.swift
- CodingKeys
- SymptomChoice
- AppLanguage
- WeatherViewModel
- .send
- ControlledProvider
- render
- DataManagementView
- BabyData
- CareFeatureStatus
- StoreScreenshotsUITests
- AdaptiveLayoutUITests
- Status
- CareWeather
- QuickLogWidget.swift
- CareWindowMetrics
- SwiftUI
- ConsentUITests
- String
- ProbeView
- String
- CareFont
- Nội dung App Store Connect — Bé Khỏe (BabyCare)
- Quy trình phát hành Bé Khỏe lên App Store
- BabyProfile
- CareDemoMode
- AppRootView
- QuickLogSnapshot
- BabyCare consent flow
- Growth/generate.py
- FamilySharingUITests
- IllnessOfferUITests
- LanguageUITests
- Hai người cùng chăm một bé – nghiên cứu (24/10/2026)
- XCUIApplication
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
- .send
- .weather
- Phase
- Phase
- CareFeedbackDraft
- Phase
- FeedbackUITests
- HealthDetailsTests
- CareWrapLayout
- QuickLogAction
- LogDiaperIntent
- CodingKeys
- .open
- CareFeedbackKind
- .make
- CareWidgetPublisher
- .avatar
- CareAdaptiveLayout.swift
- CarePreviewData.swift
- .perform

## God Nodes (most connected - your core abstractions)
1. `CareActivity` - 128 edges
2. `CareDatabase` - 97 edges
3. `BabyCareViewModel` - 96 edges
4. `SessionViewModel` - 88 edges
5. `CareFont` - 78 edges
6. `CareIcon` - 62 edges
7. `ActivityFormView` - 61 edges
8. `BabyProfile` - 58 edges
9. `SupabaseCareDataProvider` - 55 edges
10. `XCUIApplication` - 51 edges

## Surprising Connections (you probably didn't know these)
- `.body` --calls--> `AppRootView`  [INFERRED]
  BabyCare/BabyCareApp.swift → BabyCare/Views/Profile/AccountView.swift
- `ControlledProvider` --implements--> `CareDataProvider`  [EXTRACTED]
  BabyCareTests/BabyCareTests.swift → BabyCare/Data/CareDataProvider.swift
- `DelayedCloudLoad` --implements--> `CareDataProvider`  [EXTRACTED]
  BabyCareTests/CloudProviderTests.swift → BabyCare/Data/CareDataProvider.swift
- `SuspendedStatusProvider` --implements--> `CareDataProvider`  [EXTRACTED]
  BabyCareTests/RuntimeSafetyTests.swift → BabyCare/Data/CareDataProvider.swift
- `CancellingProvider` --implements--> `CareDataProvider`  [EXTRACTED]
  BabyCareTests/SharedCareTests.swift → BabyCare/Data/CareDataProvider.swift

## Import Cycles
- None detected.

## Communities (139 total, 17 thin omitted)

### Community 0 - "CloudSnapshot"
Cohesion: 0.12
Nodes (24): PendingCloudWrite, CloudChange, CloudEnvelope, CloudMapping, CloudReceipt, CloudSnapshot, CloudValue, bool (+16 more)

### Community 1 - "CareColumnsLayout"
Cohesion: 0.28
Nodes (10): .body, CareColumnsLayout, CareColumnsPlan, .isSplit, Binding, Bool, CGFloat, ClosedRange (+2 more)

### Community 2 - ".body"
Cohesion: 0.08
Nodes (31): AttributedString, AVFAudio, ConsentStatusView, .body, LegalDocument, .id, privacy, terms (+23 more)

### Community 3 - "MedicationReminder"
Cohesion: 0.15
Nodes (15): ActivityEntity, ActivityFollowUpEntity, BabyDetailsEntity, BabyEntity, CareMetadataEntity, MeasurementEntity, ReminderEntity, Bool (+7 more)

### Community 4 - "BodyMeasurement"
Cohesion: 0.16
Nodes (15): BodyMeasurement, Double, MeasurementHistoryView, .body, .sorted, MeasurementEntryView, .hasChanges, .headValue (+7 more)

### Community 5 - "BabyCareViewModel"
Cohesion: 0.08
Nodes (27): BabyCareState, BabyCareViewModel, .activities, .babies, .baby, .hasOnboarded, .illnessStartDate, .illnessTitle (+19 more)

### Community 6 - "CareDataMutation"
Cohesion: 0.12
Nodes (17): CareDataMutation, .babyID, createBaby, deleteActivity, deleteBaby, deleteReminder, deleteVaccination, endIllness (+9 more)

### Community 7 - "Sendable"
Cohesion: 0.27
Nodes (11): CloudMediaAsset, CloudMediaPlan, CloudMediaPurpose, activity, avatar, CloudMediaSyncResult, CloudMediaUpload, Data (+3 more)

### Community 8 - ".reveal"
Cohesion: 0.18
Nodes (5): StitchAppearanceTests, String, CGFloat, Int, XCUIElement

### Community 9 - "NextDoseView"
Cohesion: 0.19
Nodes (8): NextDosePrompt, .id, NextDoseView, .body, .current, UUID, Void, Int

### Community 11 - "CareStorageStatus"
Cohesion: 0.09
Nodes (15): CareStorageStatus, cached, cacheWarning, cloud, device, .message, pending, RuntimeSafetyTests (+7 more)

### Community 12 - "CameraCaptureView"
Cohesion: 0.06
Nodes (33): Any, CameraCaptureView, .isAvailable, Coordinator, Bool, Context, Coordinator, UIImage (+25 more)

### Community 13 - "View"
Cohesion: 0.09
Nodes (33): CareCard, CareSectionTitle, .body, InsightDateRangeView, .body, InsightMetricView, .body, Color (+25 more)

### Community 14 - ".text"
Cohesion: 0.06
Nodes (49): .body, CareTheme, CareBrandView, .body, CareDateTimeField, .body, CareFormCard, .body (+41 more)

### Community 15 - "ActivityKind"
Cohesion: 0.06
Nodes (37): .color, ActivityGroup, .assetName, feeding, .id, medical, routine, .title (+29 more)

### Community 16 - "LocalCareReminderService"
Cohesion: 0.11
Nodes (17): CareNotification, CareNotificationCenter, LocalCareReminderService, Bool, Never, String, Task, SystemCareNotificationCenter (+9 more)

### Community 17 - "Kiến trúc BabyCare"
Cohesion: 0.05
Nodes (33): App language, Bình chọn tính năng (27/10/2026, bản 1.2), Chia sẻ gia đình (26/10/2026, bản 1.2), Cloud provider đã tích hợp, Giao diện sáng/tối (25/10/2026), Góp ý trong app (27/10/2026, bản 1.2), iPhone Duo (cập nhật 23/10/2026, Xcode 27.1), Kiến trúc BabyCare (+25 more)

### Community 18 - "AppAppearance"
Cohesion: 0.15
Nodes (13): AppAppearance, dark, .id, .interfaceStyle, light, system, AppearancePicker, .body (+5 more)

### Community 19 - "FakeCloudRemote"
Cohesion: 0.22
Nodes (7): CloudCacheState, .queuedWrites, CloudProviderTests, FakeCloudCache, FakeCloudRemote, Int, String

### Community 20 - "SessionViewModel"
Cohesion: 0.12
Nodes (17): CareFeatureRemote, CareSharingRemote, SessionViewModel, .canSendFeedback, .canShare, .role, AsyncStream, AuthChangeEvent (+9 more)

### Community 21 - "CloudError"
Cohesion: 0.12
Nodes (13): CloudError, accessDenied, busy, conflict, consentRequired, .errorDescription, offline, rejected (+5 more)

### Community 22 - "LogActivityKind"
Cohesion: 0.08
Nodes (30): AppEnum, AppIntents, AppShortcut, AppShortcutsProvider, BabyCareShortcuts, .appShortcuts, DiaperContent, both (+22 more)

### Community 23 - "VoiceInputViewModel"
Cohesion: 0.06
Nodes (36): AnyObject, AVFoundation, ParseError, .errorDescription, Calendar, String, VoiceActivityParser, Int (+28 more)

### Community 24 - "ActivityFormViewModel"
Cohesion: 0.07
Nodes (36): ActivityFormAction, adjust, allergy, attachments, date, detail, followUp, loadingPhotos (+28 more)

### Community 25 - "ActivityFormView"
Cohesion: 0.09
Nodes (24): BreathingReference, ActivityFormView, .amountRow, .breathingFields, .checkHint, .dirty, .doctorFields, .isEditing (+16 more)

### Community 26 - "Date"
Cohesion: 0.23
Nodes (7): Date, ShowcaseBuilder, Bool, ClosedRange, Double, Int, T

### Community 27 - ".body"
Cohesion: 0.07
Nodes (33): EntryFieldLabel, .body, EntryFormCard, .body, EntryInputStyle, CGFloat, Content, Self (+25 more)

### Community 28 - "CareActivity"
Cohesion: 0.07
Nodes (48): CareActivity, ActivityDetailContent, .body, .current, .repeatedEntry, ActivityDetailView, .body, Void (+40 more)

### Community 29 - "Foundation"
Cohesion: 0.07
Nodes (19): BabyCare, CareQuote, CareQuotes, Int, String, UserDefaults, AppleSignInNonce, Int (+11 more)

### Community 30 - "GrowthStandard"
Cohesion: 0.07
Nodes (28): GrowthStandard, cdc, .id, .shortTitle, .title, Line, .id, p15 (+20 more)

### Community 31 - "Equatable"
Cohesion: 0.12
Nodes (21): CareFamilyRole, .canWrite, caregiver, owner, .summary, .title, viewer, CloudCreatedInvite (+13 more)

### Community 32 - ".seedV1"
Cohesion: 0.13
Nodes (18): BabyCareSchemaMigrationPlan, .schemas, .stages, BabyCareSchemaV1, .models, .versionIdentifier, BabyCareSchemaV2, .models (+10 more)

### Community 33 - ".plan"
Cohesion: 0.14
Nodes (14): FormKind, bath, diaper, meal, milk, other, sleep, temperature (+6 more)

### Community 34 - "ReportSection"
Cohesion: 0.18
Nodes (11): ReportSection, .color, feeding, .group, growth, .icon, .id, medical (+3 more)

### Community 35 - "Components"
Cohesion: 0.08
Nodes (25): 1. Primary Bottom Action Button (Floating CTA), 2. Category Activity Chips (Pill Filter), 3. Bottom Tab Bar (3 Primary Tabs), 4. Baby Profile Header & Switcher Sheet, 5. Status Banners (Persistent Ongoing Trackers), 6. Toast Notification with Quick Undo, 7. Form Inputs & Steppers, Action & Feedback Token (+17 more)

### Community 36 - ".applying"
Cohesion: 0.10
Nodes (23): CareDataError, babyNotFound, conflict, corruptData, .errorDescription, invalidInput, CareValidation, CodingKeys (+15 more)

### Community 37 - "CareReviewPolicy"
Cohesion: 0.20
Nodes (10): CareReviewPolicy, CareReviewTracker, Moment, illnessEnded, reportShared, Bool, Calendar, Int (+2 more)

### Community 38 - "CarePrimaryButton"
Cohesion: 0.07
Nodes (36): .title, .background, CareActivityRow, .body, CareAsyncButton, .body, CareBabyHeaderView, .body (+28 more)

### Community 39 - ".count"
Cohesion: 0.10
Nodes (18): Int, .sleepSummary, .body, UUID, VoiceEntryView, .body, DiaryActivityCardView, .body (+10 more)

### Community 40 - "SupabaseSharingRemote"
Cohesion: 0.29
Nodes (7): Family, Member, SupabaseSharingRemote, Encodable, SupabaseClient, T, UUID

### Community 41 - ".create"
Cohesion: 0.17
Nodes (9): CareAppStore, URL, CareReportPDF, CGFloat, UIImage, URL, GrowthLoopTests, .utc (+1 more)

### Community 44 - "Kế hoạch database cloud cho BabyCare"
Cohesion: 0.17
Nodes (11): 10. Thông tin cần có khi bắt đầu triển khai, 1. Chọn Supabase Free, 2. Phạm vi và kiến trúc đích, 3. Schema đề xuất, 4. Đăng nhập và phân quyền, 5. API, ảnh và transaction, 6. Chuyển dữ liệu SwiftData hiện có lên cloud, 7. Đồng bộ offline (+3 more)

### Community 45 - "BabyCare — Agent workflow"
Cohesion: 0.18
Nodes (10): 1. Feature requirement, 2. Graphify graph, 3. Dependency / impact analysis, 4. Inspect đúng source cần thiết, 5. Implementation plan, 6. Code, 7. Tests, 8. Graphify impact/review (+2 more)

### Community 46 - "CareWeatherCondition"
Cohesion: 0.05
Nodes (37): CareWeatherCondition, blizzard, blowingDust, blowingSnow, breezy, clear, cloudy, drizzle (+29 more)

### Community 47 - "GrowthChartView"
Cohesion: 0.11
Nodes (21): Accessory, GrowthChartView, .curves, .points, .selected, .span, .visible, .windowStart (+13 more)

### Community 48 - "SupabaseCareDataProvider"
Cohesion: 0.15
Nodes (12): CareCloudCache, SupabaseCareDataProvider, .visibleDatabase, Bool, Never, Set, String, Task (+4 more)

### Community 49 - "RevisionRemote"
Cohesion: 0.18
Nodes (4): MemoryCloudCache, RevisionRemote, Int, UUID

### Community 50 - ".normalize"
Cohesion: 0.12
Nodes (20): CareFeatureRequest, Request, SupabaseFeatureRemote, Int, SupabaseClient, UUID, FeatureBoardView, .body (+12 more)

### Community 51 - "SupabaseRemote"
Cohesion: 0.15
Nodes (13): CloudConfiguration, CloudFamily, CloudPrivacyDeletion, CloudSessionLease, ObjectPath, OwnedFamily, SupabaseRemote, Int (+5 more)

### Community 52 - "SwiftDataCloudCache"
Cohesion: 0.22
Nodes (7): CloudCacheRecord, Data, ModelContainer, ModelContext, URL, UUID, SwiftDataCloudCache

### Community 53 - ".body"
Cohesion: 0.14
Nodes (13): Field, confirmation, email, password, SignInView, .body, .captchaSection, .emailDivider (+5 more)

### Community 54 - "String"
Cohesion: 0.35
Nodes (6): SHA256.Digest, .hex, CareInviteCode, URL, .body, String

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

### Community 64 - "CareDatabase"
Cohesion: 0.12
Nodes (10): InMemoryCareDataProvider, Bool, CareDatabase, DelayedCloudLoad, .waiting, Bool, CheckedContinuation, Never (+2 more)

### Community 65 - "WidgetText"
Cohesion: 0.12
Nodes (19): .sample, QuickLogWidgetView, .body, Bool, Color, String, WidgetText, .appName (+11 more)

### Community 66 - "GrowthMetric"
Cohesion: 0.15
Nodes (13): CurvePoint, .id, GrowthLMS, GrowthMetric, height, .id, .unit, weight (+5 more)

### Community 67 - "QuickLogError"
Cohesion: 0.16
Nodes (13): QuickLogError, consent, .errorDescription, message, noBaby, signedOut, timeout, QuickLogPerformer (+5 more)

### Community 68 - "TemperatureDetail"
Cohesion: 0.12
Nodes (14): .displayText, Band, DoctorFollowUp, SleepRecommendation, Calendar, Int, TimeInterval, .displayName (+6 more)

### Community 69 - "CloudFamilySummary"
Cohesion: 0.11
Nodes (14): CareFeedbackRemote, CloudFamilySummary, Int, Features, Feedback, SharingUITestFixture, .currentFamilies, .enabled (+6 more)

### Community 70 - "CareTab"
Cohesion: 0.12
Nodes (21): Axis, CareBottomTabs, .body, .tabs, CareTab, diary, feedback, quick (+13 more)

### Community 71 - "XCTest"
Cohesion: 0.12
Nodes (5): BabyCareUITestsLaunchTests, MedicationFlowUITests, VaccinationUITests, XCTest, XCTestCase

### Community 72 - "SwiftDataCareDataProvider"
Cohesion: 0.25
Nodes (7): CarePersistenceConfiguration, .device, ModelContainer, ModelContext, Self, URL, SwiftDataCareDataProvider

### Community 73 - "CareWeatherService.swift"
Cohesion: 0.14
Nodes (15): CareLocationSource, CareLocationStatus, authorized, denied, notDetermined, CareWeatherError, locationDenied, locationUnavailable (+7 more)

### Community 74 - "CodingKeys"
Cohesion: 0.12
Nodes (17): CodingKeys, code, createdBy, email, expiresAt, familyID, id, invites (+9 more)

### Community 75 - "SymptomChoice"
Cohesion: 0.27
Nodes (5): SymptomCatalog, SymptomChoice, .token, .symptomFields, Collection

### Community 76 - "AppLanguage"
Cohesion: 0.08
Nodes (20): App, BabyCareApp, .body, .ageDescription, AppLanguage, .current, english, .id (+12 more)

### Community 77 - "WeatherViewModel"
Cohesion: 0.24
Nodes (7): CareWeatherAttribution, Bool, String, TimeInterval, URL, WeatherViewModel, .sampleWeather

### Community 78 - ".send"
Cohesion: 0.16
Nodes (9): .attachments, .date, .detail, .loadingPhotos, .note, .symptoms, .unit, .value (+1 more)

### Community 79 - "ControlledProvider"
Cohesion: 0.21
Nodes (8): ControlledProvider, .isWaiting, RecordingReminderService, Bool, CheckedContinuation, Never, String, Void

### Community 80 - "render"
Cohesion: 0.22
Nodes (12): AppKit, CoreText, NSAttributedString, NSBitmapImageRep, NSColor, NSImage, NSSize, drawCentered() (+4 more)

### Community 81 - "DataManagementView"
Cohesion: 0.25
Nodes (6): DataManagementView, .body, .isCloudAccount, DestructiveConfirmation, Bool, String

### Community 82 - "BabyData"
Cohesion: 0.18
Nodes (14): BabyData, .selectedBaby, Decoder, VaccinationRecord, Bool, UUID, VaccinationEntryView, .baby (+6 more)

### Community 83 - "CareFeatureStatus"
Cohesion: 0.17
Nodes (11): CareFeatureStatus, .badge, declined, done, .isPublished, open, pending, planned (+3 more)

### Community 84 - "StoreScreenshotsUITests"
Cohesion: 0.30
Nodes (4): StoreScreenshotsUITests, Bool, CGFloat, String

### Community 85 - "AdaptiveLayoutUITests"
Cohesion: 0.36
Nodes (4): AdaptiveLayoutUITests, Bool, String, XCUIElement

### Community 86 - "Status"
Cohesion: 0.22
Nodes (9): Status, alreadyMember, expired, familyFull, invalid, joined, rateLimited, revoked (+1 more)

### Community 87 - "CareWeather"
Cohesion: 0.36
Nodes (6): CareWeather, OutfitAdvice, OutfitItem, Double, Int, String

### Community 88 - "QuickLogWidget.swift"
Cohesion: 0.17
Nodes (12): QuickLogEntry, QuickLogProvider, QuickLogWidget, .body, Context, Void, Timeline, TimelineEntry (+4 more)

### Community 89 - "CareWindowMetrics"
Cohesion: 0.21
Nodes (6): CareWindowMetrics, .usesSideTabs, CGRect, CGSize, AdaptiveLayoutTests, DynamicTypeSize

### Community 90 - "SwiftUI"
Cohesion: 0.14
Nodes (11): Double, String, Void, WeatherCardView, .attributionRow, .body, Charts, CoreImage.CIFilterBuiltins (+3 more)

### Community 91 - "ConsentUITests"
Cohesion: 0.36
Nodes (3): ConsentUITests, Bool, XCUIElement

### Community 92 - "String"
Cohesion: 0.22
Nodes (7): AuthAction, resetPassword, signIn, signUp, Error, String, .appleButton

### Community 93 - "ProbeView"
Cohesion: 0.29
Nodes (7): CareWindowProbe, ProbeView, Context, Void, NSCoder, UIView, UIViewRepresentable

### Community 94 - "String"
Cohesion: 0.25
Nodes (6): AllergyNote, .line, .trimmed, MealEntry, String, .formattedValue

### Community 95 - "CareFont"
Cohesion: 0.07
Nodes (43): CareColumns, CareIcon, .body, CGFloat, CareActionStyle, CareFont, Color, IllnessTrackingView (+35 more)

### Community 96 - "Nội dung App Store Connect — Bé Khỏe (BabyCare)"
Cohesion: 0.25
Nodes (7): 1. Thông tin chung (không theo ngôn ngữ), 2. English (U.K.) — localization chính, 3. Vietnamese — localization thêm, 4. App Privacy (privacy nutrition labels), 5. Age rating questionnaire, 6. App Review Information, Nội dung App Store Connect — Bé Khỏe (BabyCare)

### Community 97 - "Quy trình phát hành Bé Khỏe lên App Store"
Cohesion: 0.22
Nodes (8): A. Trước khi archive, B. Tạo app trên App Store Connect, C. Archive và upload từ Xcode, D. Nộp duyệt, E. Sau khi lên store, F. Bản 1.2: việc làm đúng lúc nộp duyệt, Lý do từ chối hay gặp và trạng thái của app, Quy trình phát hành Bé Khỏe lên App Store

### Community 98 - "BabyProfile"
Cohesion: 0.11
Nodes (20): BabyGender, boy, girl, .id, .title, unspecified, BabyProfile, .initial (+12 more)

### Community 99 - "CareDemoMode"
Cohesion: 0.22
Nodes (7): AppDependencies, CareDemoMode, .dataset, .hidesDemoBadge, .isActive, .isFullBuild, Bool

### Community 100 - "AppRootView"
Cohesion: 0.11
Nodes (15): AuthenticationServices, ConsentUITestFixture, .enabled, AsyncStream, AuthChangeEvent, Bool, Session, AccountLoadingErrorView (+7 more)

### Community 101 - "QuickLogSnapshot"
Cohesion: 0.30
Nodes (6): QuickLogSnapshot, QuickLogStore, .defaults, Bool, TimeInterval, UserDefaults

### Community 102 - "BabyCare consent flow"
Cohesion: 0.29
Nodes (6): BabyCare consent flow, Deployment and rollback, Known operational limits, Quyết định 14/10/2026: không gate theo phiên bản phía client, Runtime contract, Versions and existing users

### Community 103 - "Growth/generate.py"
Cohesion: 0.48
Nodes (6): cdc(), main(), Generate BabyCare/Domain/GrowthReferenceData.swift from the official growth…, swift_rows(), who_daily(), who_monthly()

### Community 107 - "Hai người cùng chăm một bé – nghiên cứu (24/10/2026)"
Cohesion: 0.33
Nodes (5): Backend đã có gì, Hai người cùng chăm một bé – nghiên cứu (24/10/2026), Những chỗ phải sửa trước khi mở tính năng, Thiết kế đề xuất, Ước lượng

### Community 108 - "XCUIApplication"
Cohesion: 0.22
Nodes (6): BabyCareUITests, String, FeatureBoardUITests, CGRect, XCUIApplication, .windowFrame

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

### Community 119 - ".send"
Cohesion: 0.16
Nodes (11): CareDataProvider, Bool, String, CareReminderService, NoopCareReminderService, BabyCareAction, commit, dismissError (+3 more)

### Community 120 - ".weather"
Cohesion: 0.47
Nodes (3): AppleWeatherSource, CLLocation, WeatherCondition

### Community 121 - "Phase"
Cohesion: 0.33
Nodes (6): Phase, denied, failed, loaded, loading, needsPermission

### Community 122 - "Phase"
Cohesion: 0.40
Nodes (5): Phase, failed, idle, loading, ready

### Community 123 - "CareFeedbackDraft"
Cohesion: 0.12
Nodes (12): SupabaseFeedbackRemote, SupabaseClient, CareFeedbackContext, .machine, .summary, CareFeedbackDraft, .canSend, .trimmedMessage (+4 more)

### Community 124 - "Phase"
Cohesion: 0.33
Nodes (6): Phase, accountError, consent, content, signedOut, starting

### Community 126 - "HealthDetailsTests"
Cohesion: 0.18
Nodes (5): DoctorVisit, Row, ClosedRange, Double, HealthDetailsTests

### Community 127 - "CareWrapLayout"
Cohesion: 0.33
Nodes (8): CareWrapLayout, CGFloat, CGRect, CGSize, ProposedViewSize, Subviews, CGPoint, Layout

### Community 128 - "QuickLogAction"
Cohesion: 0.18
Nodes (9): BabyCareWidgetsBundle, .body, QuickLogPerformer, Widget, QuickLogAction, diaper, milk, sleep (+1 more)

### Community 129 - "LogDiaperIntent"
Cohesion: 0.40
Nodes (7): AppIntent, LiveActivityIntent, LogDiaperIntent, RepeatMilkIntent, IntentResult, LocalizedStringResource, ToggleSleepIntent

### Community 130 - "CodingKeys"
Cohesion: 0.20
Nodes (10): CodingKeys, allergies, avatarData, birthDate, bloodType, gender, healthNotes, id (+2 more)

### Community 131 - ".open"
Cohesion: 0.27
Nodes (6): SignupOutcome, confirmationPending, existingAccount, signedIn, Bool, Int

### Community 132 - "CareFeedbackKind"
Cohesion: 0.22
Nodes (9): CareFeedbackKind, bug, .icon, .id, other, .prompt, suggestion, .title (+1 more)

### Community 134 - "CareWidgetPublisher"
Cohesion: 0.42
Nodes (4): CareWidgetPublisher, Bool, String, UserDefaults

### Community 135 - ".avatar"
Cohesion: 0.61
Nodes (5): CarePreviewImages, CGFloat, CGSize, Data, String

### Community 136 - "CareAdaptiveLayout.swift"
Cohesion: 0.38
Nodes (4): CareAdaptiveRoot, EnvironmentValues, Content, View

### Community 137 - "CarePreviewData.swift"
Cohesion: 0.38
Nodes (4): CarePreviewData, SeededGenerator, RandomNumberGenerator, UInt64

## Knowledge Gaps
- **524 isolated node(s):** `.isFullBuild`, `.isActive`, `.hidesDemoBadge`, `.enabled`, `StoreKit` (+519 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 832 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **17 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Date` connect `Date` to `CloudSnapshot`, `MedicationReminder`, `BabyCareViewModel`, `CareDataMutation`, `CareWidgetPublisher`, `NextDoseView`, `View`, `.text`, `LocalCareReminderService`, `VoiceInputViewModel`, `ActivityFormViewModel`, `ActivityFormView`, `.body`, `CareActivity`, `Equatable`, `.plan`, `.applying`, `CareReviewPolicy`, `CarePrimaryButton`, `RevisionRemote`, `ConsentViewModel`, `WidgetText`, `GrowthMetric`, `TemperatureDetail`, `AppLanguage`, `WeatherViewModel`, `.send`, `BabyData`, `CareWeather`, `QuickLogWidget.swift`, `CareFont`, `BabyProfile`, `QuickLogSnapshot`, `LegacyArchive`, `HealthDetailsTests`?**
  _High betweenness centrality (0.100) - this node is a cross-community bridge._
- **Why does `CareActivity` connect `CareActivity` to `CloudSnapshot`, `MedicationReminder`, `BodyMeasurement`, `.make`, `CareDataMutation`, `Sendable`, `BabyCareViewModel`, `BabyCareTests`, `View`, `.text`, `ActivityKind`, `FakeCloudRemote`, `VoiceInputViewModel`, `ActivityFormViewModel`, `ActivityFormView`, `Date`, `Equatable`, `.plan`, `.applying`, `CareReviewPolicy`, `CarePrimaryButton`, `.count`, `RevisionRemote`, `String`, `TemperatureDetail`, `SwiftDataCareDataProvider`, `.send`, `BabyData`, `String`, `CareFont`, `BabyProfile`, `LegacyArchive`, `HealthDetailsTests`?**
  _High betweenness centrality (0.090) - this node is a cross-community bridge._
- **Why does `XCUIApplication` connect `XCUIApplication` to `XCTest`, `FamilySharingUITests`, `IllnessOfferUITests`, `LanguageUITests`, `.reveal`, `StoreScreenshotsUITests`, `AdaptiveLayoutUITests`, `ConsentUITests`, `FeedbackUITests`?**
  _High betweenness centrality (0.053) - this node is a cross-community bridge._
- **Are the 55 inferred relationships involving `CareActivity` (e.g. with `.decode()` and `.read()`) actually correct?**
  _`CareActivity` has 55 INFERRED edges - model-reasoned connections that need verification._
- **Are the 14 inferred relationships involving `CareDatabase` (e.g. with `.preserveUnavailableVaccinations()` and `.fourBabiesCanSwitchAndRetryButCannotAddFifth()`) actually correct?**
  _`CareDatabase` has 14 INFERRED edges - model-reasoned connections that need verification._
- **Are the 48 inferred relationships involving `BabyCareViewModel` (e.g. with `.makeSession()` and `.makeSession()`) actually correct?**
  _`BabyCareViewModel` has 48 INFERRED edges - model-reasoned connections that need verification._
- **What connects `.isFullBuild`, `.isActive`, `.hidesDemoBadge` to the rest of the system?**
  _524 weakly-connected nodes found - possible documentation gaps or missing edges._