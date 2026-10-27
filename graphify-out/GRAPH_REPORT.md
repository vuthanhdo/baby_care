# Graph Report - BabyCare  (2026-10-27)

## Corpus Check
- 420 files · ~1,529,229 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 2481 nodes · 6496 edges · 126 communities (111 shown, 15 thin omitted)
- Extraction: 86% EXTRACTED · 14% INFERRED · 0% AMBIGUOUS · INFERRED: 935 edges (avg confidence: 0.83)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `f2788fb8`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- .decode
- CareWindowMetrics
- OnboardingConsentView
- MedicationReminder
- MeasurementEntryView
- BabyCareViewModel
- CareDatabase
- Sendable
- XCUIApplication
- .text
- BabyCareTests
- CareDataProvider
- CameraCaptureView
- CareReportSnapshot
- CareTheme
- ActivityKind
- LocalCareReminderService
- Kiến trúc BabyCare
- AppAppearance
- FakeCloudRemote
- SessionViewModel
- .normalize
- .daySummary
- VoiceInputViewModel
- ActivityFormViewModel
- ActivityFormView
- Date
- SwiftUI
- View
- Foundation
- CaseIterable
- Equatable
- BabyCareSchemaMigrationPlan
- ActivityFormAction
- ReportSection
- Components
- .applying
- CareReviewPolicy
- CareComponents.swift
- .body
- SupabaseSharingRemote
- .create
- import_stitch_icons.py
- generate.py
- Kế hoạch database cloud cho BabyCare
- BabyCare — Agent workflow
- CareWeatherCondition
- BabyCareAction
- SupabaseCareDataProvider
- CloudSnapshot
- CareFeatureRequest
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
- UUID
- FeedbackForm
- GrowthChartView
- CareFeatureVote
- TemperatureDetail
- Sharing
- CareTab
- XCTest
- SwiftDataCareDataProvider
- CareWeatherService.swift
- CodingKeys
- String
- AppLanguage
- WeatherViewModel
- .episodeSummary
- ControlledProvider
- render
- DataManagementView
- .number
- CareFeatureStatus
- StoreScreenshotsUITests
- AdaptiveLayoutUITests
- Status
- CareWeather
- .body
- ActivityPickerView
- WeatherCardView
- ConsentUITests
- SuggestFeatureSheet
- ActivityGroup
- CareActivity
- CareFont
- Nội dung App Store Connect — Bé Khỏe (BabyCare)
- Quy trình phát hành Bé Khỏe lên App Store
- BabyGender
- CareDemoMode
- ConsentUITestFixture
- JoinFamilySheet
- BabyCare consent flow
- Growth/generate.py
- .reveal
- IllnessOfferUITests
- LanguageUITests
- Hai người cùng chăm một bé – nghiên cứu (24/10/2026)
- FeatureBoardUITests
- Trả lời App Review – Guideline 2.1 Information Needed (21/10/2026)
- index.ts
- run-pglite.mjs
- Link chiến dịch App Store
- StitchAssetTests
- BodyMeasurement
- AppStore/README.md
- templates/README.md
- store_screenshots.sh
- store_screenshots_duo.sh
- CareReminderService
- .weather
- Phase
- Phase
- CareFeedbackDraft
- Phase
- FeedbackUITests

## God Nodes (most connected - your core abstractions)
1. `CareActivity` - 120 edges
2. `CareDatabase` - 93 edges
3. `BabyCareViewModel` - 92 edges
4. `SessionViewModel` - 87 edges
5. `CareFont` - 78 edges
6. `CareIcon` - 62 edges
7. `ActivityFormView` - 61 edges
8. `BabyProfile` - 56 edges
9. `SupabaseCareDataProvider` - 55 edges
10. `XCUIApplication` - 51 edges

## Surprising Connections (you probably didn't know these)
- `.body` --calls--> `AppRootView`  [INFERRED]
  BabyCare/BabyCareApp.swift → BabyCare/Views/Profile/AccountView.swift
- `ControlledProvider` --implements--> `CareDataProvider`  [EXTRACTED]
  BabyCareTests/BabyCareTests.swift → BabyCare/Data/CareDataProvider.swift
- `CancellingProvider` --implements--> `CareDataProvider`  [EXTRACTED]
  BabyCareTests/SharedCareTests.swift → BabyCare/Data/CareDataProvider.swift
- `MemoryCloudCache` --calls--> `CloudCacheState`  [EXTRACTED]
  BabyCareTests/SharedCareTests.swift → BabyCare/Data/Cloud/CloudCache.swift
- `FakeCloudCache` --implements--> `CareCloudCache`  [EXTRACTED]
  BabyCareTests/CloudProviderTests.swift → BabyCare/Data/Cloud/CloudCache.swift

## Import Cycles
- None detected.

## Communities (126 total, 15 thin omitted)

### Community 0 - ".decode"
Cohesion: 0.10
Nodes (21): CloudChange, CloudMapping, CloudValue, bool, .flag, null, number, string (+13 more)

### Community 1 - "CareWindowMetrics"
Cohesion: 0.07
Nodes (36): CareAdaptiveRoot, .body, CareColumnsLayout, CareColumnsPlan, .isSplit, CareWindowMetrics, .usesSideTabs, CareWindowProbe (+28 more)

### Community 2 - "OnboardingConsentView"
Cohesion: 0.12
Nodes (20): AttributedString, ConsentStatusView, .body, LegalDocument, .id, privacy, terms, .title (+12 more)

### Community 3 - "MedicationReminder"
Cohesion: 0.15
Nodes (13): ActivityEntity, ActivityFollowUpEntity, BabyDetailsEntity, BabyEntity, CareMetadataEntity, ReminderEntity, Bool, Data (+5 more)

### Community 4 - "MeasurementEntryView"
Cohesion: 0.27
Nodes (10): MeasurementEntryView, .hasChanges, .headValue, .heightValue, .isValid, .weightValue, Binding, Bool (+2 more)

### Community 5 - "BabyCareViewModel"
Cohesion: 0.07
Nodes (26): BabyCareViewModel, .activities, .babies, .baby, .hasOnboarded, .illnessStartDate, .illnessTitle, .isTrackingIllness (+18 more)

### Community 6 - "CareDatabase"
Cohesion: 0.06
Nodes (33): InMemoryCareDataProvider, Bool, URL, BabyData, CareDatabase, .selectedBaby, CareDataError, babyNotFound (+25 more)

### Community 7 - "Sendable"
Cohesion: 0.19
Nodes (15): PendingCloudWrite, CloudMediaAsset, CloudMediaPlan, CloudMediaPurpose, activity, avatar, CloudMediaSyncResult, CloudMediaUpload (+7 more)

### Community 8 - "XCUIApplication"
Cohesion: 0.27
Nodes (5): StitchAppearanceTests, String, CGRect, XCUIApplication, .windowFrame

### Community 9 - ".text"
Cohesion: 0.08
Nodes (31): AVFAudio, .body, CareBabyHeaderView, .body, .body, MedicationReminderView, .body, NextDosePrompt (+23 more)

### Community 11 - "CareDataProvider"
Cohesion: 0.07
Nodes (22): CareDataProvider, Bool, String, CareStorageStatus, cached, cacheWarning, cloud, device (+14 more)

### Community 12 - "CameraCaptureView"
Cohesion: 0.06
Nodes (33): Any, CameraCaptureView, .isAvailable, Coordinator, Bool, Context, Coordinator, UIImage (+25 more)

### Community 13 - "CareReportSnapshot"
Cohesion: 0.08
Nodes (27): CareColumns, CareSectionTitle, .body, Int, .body, UUID, VoiceEntryView, .body (+19 more)

### Community 14 - "CareTheme"
Cohesion: 0.08
Nodes (31): AuthenticationServices, CareTheme, CareBrandView, .body, CareDateTimeField, .body, CareFormCard, .body (+23 more)

### Community 15 - "ActivityKind"
Cohesion: 0.10
Nodes (21): ActivityKind, allergy, .assetName, bath, breathing, .defaultUnit, diaper, doctor (+13 more)

### Community 16 - "LocalCareReminderService"
Cohesion: 0.09
Nodes (20): DoctorFollowUp, Calendar, TimeInterval, CareNotification, CareNotificationCenter, LocalCareReminderService, Bool, Never (+12 more)

### Community 17 - "Kiến trúc BabyCare"
Cohesion: 0.06
Nodes (32): App language, Bình chọn tính năng (27/10/2026, bản 1.2), Chia sẻ gia đình (26/10/2026, bản 1.2), Cloud provider đã tích hợp, Giao diện sáng/tối (25/10/2026), Góp ý trong app (27/10/2026, bản 1.2), iPhone Duo (cập nhật 23/10/2026, Xcode 27.1), Kiến trúc BabyCare (+24 more)

### Community 18 - "AppAppearance"
Cohesion: 0.15
Nodes (13): AppAppearance, dark, .id, .interfaceStyle, light, system, AppearancePicker, .body (+5 more)

### Community 19 - "FakeCloudRemote"
Cohesion: 0.20
Nodes (8): CloudCacheState, .queuedWrites, VaccinationRecord, CloudProviderTests, FakeCloudCache, FakeCloudRemote, Int, String

### Community 20 - "SessionViewModel"
Cohesion: 0.09
Nodes (25): CareFeatureRemote, CareSharingRemote, CloudFamilySummary, Int, SessionViewModel, .canSendFeedback, .canShare, .currentFamily (+17 more)

### Community 21 - ".normalize"
Cohesion: 0.11
Nodes (17): CloudError, accessDenied, busy, conflict, consentRequired, .errorDescription, offline, rejected (+9 more)

### Community 22 - ".daySummary"
Cohesion: 0.26
Nodes (7): InsightDaySummary, .isEmpty, Bool, Calendar, InsightDaySummaryTests, .start, Double

### Community 23 - "VoiceInputViewModel"
Cohesion: 0.06
Nodes (36): AnyObject, AVFoundation, ParseError, .errorDescription, Calendar, String, VoiceActivityParser, Int (+28 more)

### Community 24 - "ActivityFormViewModel"
Cohesion: 0.08
Nodes (29): ActivityFormState, ActivityFormViewModel, .attachments, .date, .detail, .loadingPhotos, .note, .number (+21 more)

### Community 25 - "ActivityFormView"
Cohesion: 0.06
Nodes (37): TemperatureReference, ActivityFormView, .amountRow, .breathingFields, .checkHint, .dirty, .doctorFields, .fieldsSection (+29 more)

### Community 26 - "Date"
Cohesion: 0.13
Nodes (16): Date, CarePreviewData, CarePreviewImages, SeededGenerator, ShowcaseBuilder, Bool, CGFloat, CGSize (+8 more)

### Community 27 - "SwiftUI"
Cohesion: 0.05
Nodes (38): EntryFieldLabel, .body, EntryFormCard, .body, EntryInputStyle, CGFloat, Content, Self (+30 more)

### Community 28 - "View"
Cohesion: 0.06
Nodes (54): CareActivityRow, CareBadge, CareCard, CareIcon, .body, CarePrimaryButton, .body, CGFloat (+46 more)

### Community 29 - "Foundation"
Cohesion: 0.07
Nodes (23): BabyCare, CareFeedbackRemote, SupabaseFeedbackRemote, SupabaseClient, CareQuote, CareQuotes, Int, String (+15 more)

### Community 30 - "CaseIterable"
Cohesion: 0.12
Nodes (17): InsightRange, custom, hours48, .id, today, week, Self, Mode (+9 more)

### Community 31 - "Equatable"
Cohesion: 0.16
Nodes (20): CareFamilyRole, .canWrite, caregiver, owner, .summary, .title, viewer, CloudCreatedInvite (+12 more)

### Community 32 - "BabyCareSchemaMigrationPlan"
Cohesion: 0.14
Nodes (16): BabyCareSchemaMigrationPlan, .schemas, .stages, BabyCareSchemaV1, .models, .versionIdentifier, BabyCareSchemaV2, .models (+8 more)

### Community 33 - "ActivityFormAction"
Cohesion: 0.12
Nodes (16): ActivityFormAction, adjust, allergy, attachments, date, detail, followUp, loadingPhotos (+8 more)

### Community 34 - "ReportSection"
Cohesion: 0.18
Nodes (11): ReportSection, .color, feeding, .group, growth, .icon, .id, medical (+3 more)

### Community 35 - "Components"
Cohesion: 0.08
Nodes (25): 1. Primary Bottom Action Button (Floating CTA), 2. Category Activity Chips (Pill Filter), 3. Bottom Tab Bar (3 Primary Tabs), 4. Baby Profile Header & Switcher Sheet, 5. Status Banners (Persistent Ongoing Trackers), 6. Toast Notification with Quick Undo, 7. Form Inputs & Steppers, Action & Feedback Token (+17 more)

### Community 36 - ".applying"
Cohesion: 0.06
Nodes (36): invalidInput, CareValidation, CodingKeys, activities, illnessStartDate, illnessTitle, isTrackingIllness, measurements (+28 more)

### Community 37 - "CareReviewPolicy"
Cohesion: 0.21
Nodes (10): CareReviewPolicy, CareReviewTracker, Moment, illnessEnded, reportShared, Bool, Calendar, Int (+2 more)

### Community 38 - "CareComponents.swift"
Cohesion: 0.13
Nodes (17): .title, .background, .body, CareAsyncButton, .body, .body, .body, CareChoiceChips (+9 more)

### Community 39 - ".body"
Cohesion: 0.16
Nodes (9): AsyncStream, AuthChangeEvent, Session, Task, AppRootView, .authPreview, .body, .bypass (+1 more)

### Community 40 - "SupabaseSharingRemote"
Cohesion: 0.26
Nodes (7): Family, Member, SupabaseSharingRemote, Encodable, SupabaseClient, T, UUID

### Community 41 - ".create"
Cohesion: 0.16
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

### Community 47 - "BabyCareAction"
Cohesion: 0.33
Nodes (5): BabyCareAction, commit, dismissError, load, showMessage

### Community 48 - "SupabaseCareDataProvider"
Cohesion: 0.15
Nodes (12): CareCloudCache, SupabaseCareDataProvider, .visibleDatabase, Bool, Never, Set, String, Task (+4 more)

### Community 49 - "CloudSnapshot"
Cohesion: 0.16
Nodes (7): CloudSnapshot, UUID, MemoryCloudCache, RevisionRemote, SharedCareTests, Int, UUID

### Community 50 - "CareFeatureRequest"
Cohesion: 0.25
Nodes (8): CareFeatureRequest, Features, FeatureBoardView, .body, .mine, .published, Set, UUID

### Community 51 - "SupabaseRemote"
Cohesion: 0.20
Nodes (6): CloudConfiguration, CloudFamily, CloudSessionLease, SupabaseRemote, Int, URLSession

### Community 52 - "SwiftDataCloudCache"
Cohesion: 0.22
Nodes (7): CloudCacheRecord, Data, ModelContainer, ModelContext, URL, UUID, SwiftDataCloudCache

### Community 53 - ".body"
Cohesion: 0.12
Nodes (17): AuthAction, resetPassword, signIn, signUp, Field, confirmation, email, password (+9 more)

### Community 54 - "String"
Cohesion: 0.29
Nodes (7): SHA256.Digest, .hex, CareInviteCode, URL, URL, .body, String

### Community 55 - "Vaccination Tracking"
Cohesion: 0.33
Nodes (5): Dependency / impact review, Deployment and compatibility, Login load regression (2026-09-13), Vaccination Tracking, Validation completed

### Community 56 - "ConsentViewModel"
Cohesion: 0.12
Nodes (22): Transport, Consent, ConsentRecord, ConsentRemote, ConsentStatus, .isCurrent, ConsentVersions, ConsentViewModel (+14 more)

### Community 57 - "FamilySharingView"
Cohesion: 0.28
Nodes (5): FamilySharingView, .body, .isOwner, UUID, Void

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

### Community 64 - "UUID"
Cohesion: 0.36
Nodes (7): CloudPrivacyDeletion, ObjectPath, OwnedFamily, Set, String, SupabaseClient, UUID

### Community 65 - "FeedbackForm"
Cohesion: 0.21
Nodes (10): FeedbackForm, .body, .context, .email, .form, .thanks, Data, Int (+2 more)

### Community 66 - "GrowthChartView"
Cohesion: 0.05
Nodes (48): Accessory, CurvePoint, .id, GrowthLMS, GrowthMetric, height, .id, .unit (+40 more)

### Community 67 - "CareFeatureVote"
Cohesion: 0.21
Nodes (8): CareFeatureVote, Request, SupabaseFeatureRemote, Bool, Int, SupabaseClient, UUID, Encodable

### Community 68 - "TemperatureDetail"
Cohesion: 0.13
Nodes (16): .displayText, Band, BreathingReference, DoctorVisit, Row, SleepRecommendation, ClosedRange, Double (+8 more)

### Community 69 - "Sharing"
Cohesion: 0.26
Nodes (3): Sharing, String, UUID

### Community 70 - "CareTab"
Cohesion: 0.12
Nodes (20): Axis, CareBottomTabs, .body, .tabs, CareTab, diary, feedback, quick (+12 more)

### Community 71 - "XCTest"
Cohesion: 0.10
Nodes (7): BabyCareUITests, String, BabyCareUITestsLaunchTests, MedicationFlowUITests, VaccinationUITests, XCTest, XCTestCase

### Community 72 - "SwiftDataCareDataProvider"
Cohesion: 0.20
Nodes (9): CarePersistenceConfiguration, .device, ModelContainer, ModelContext, Self, URL, SwiftDataCareDataProvider, HealthDetailsTests (+1 more)

### Community 73 - "CareWeatherService.swift"
Cohesion: 0.19
Nodes (11): CareLocationSource, CareLocationStatus, authorized, denied, notDetermined, CareWeatherSource, SystemLocationSource, .status (+3 more)

### Community 74 - "CodingKeys"
Cohesion: 0.12
Nodes (17): CodingKeys, code, createdBy, email, expiresAt, familyID, id, invites (+9 more)

### Community 75 - "String"
Cohesion: 0.15
Nodes (12): AllergyNote, .line, .trimmed, String, SymptomCatalog, SymptomChoice, .token, .symptomFields (+4 more)

### Community 76 - "AppLanguage"
Cohesion: 0.07
Nodes (21): App, BabyCareApp, .body, .ageDescription, AppLanguage, .current, english, .id (+13 more)

### Community 77 - "WeatherViewModel"
Cohesion: 0.27
Nodes (6): CareWeatherAttribution, Bool, String, TimeInterval, URL, WeatherViewModel

### Community 78 - ".episodeSummary"
Cohesion: 0.29
Nodes (6): .summary, InsightEpisodeSummary, .symptomNames, InsightEpisodeSummaryTests, .start, Double

### Community 79 - "ControlledProvider"
Cohesion: 0.21
Nodes (8): ControlledProvider, .isWaiting, RecordingReminderService, Bool, CheckedContinuation, Never, String, Void

### Community 80 - "render"
Cohesion: 0.22
Nodes (12): AppKit, CoreText, NSAttributedString, NSBitmapImageRep, NSColor, NSImage, NSSize, drawCentered() (+4 more)

### Community 81 - "DataManagementView"
Cohesion: 0.25
Nodes (6): DataManagementView, .body, .isCloudAccount, DestructiveConfirmation, Bool, String

### Community 82 - ".number"
Cohesion: 0.16
Nodes (14): .valid, InsightData, InsightDateRangeView, .body, InsightMetricView, Color, DateInterval, Double (+6 more)

### Community 83 - "CareFeatureStatus"
Cohesion: 0.22
Nodes (9): CareFeatureStatus, .badge, declined, done, .isPublished, open, pending, planned (+1 more)

### Community 84 - "StoreScreenshotsUITests"
Cohesion: 0.29
Nodes (4): StoreScreenshotsUITests, Bool, CGFloat, String

### Community 85 - "AdaptiveLayoutUITests"
Cohesion: 0.35
Nodes (5): sleep, AdaptiveLayoutUITests, Bool, String, XCUIElement

### Community 86 - "Status"
Cohesion: 0.22
Nodes (9): Status, alreadyMember, expired, familyFull, invalid, joined, rateLimited, revoked (+1 more)

### Community 87 - "CareWeather"
Cohesion: 0.31
Nodes (7): CareWeather, OutfitAdvice, OutfitItem, Double, Int, String, .sampleWeather

### Community 88 - ".body"
Cohesion: 0.14
Nodes (16): BabyProfileView, .body, .genderLabel, MeasurementHistoryView, .body, .sorted, ProfileEditorView, .latestAllowedBirthDate (+8 more)

### Community 89 - "ActivityPickerView"
Cohesion: 0.22
Nodes (6): ActivityPickerView, .gridColumns, .kinds, CGFloat, ClosedRange, Color

### Community 90 - "WeatherCardView"
Cohesion: 0.36
Nodes (6): Double, String, Void, WeatherCardView, .attributionRow, .body

### Community 91 - "ConsentUITests"
Cohesion: 0.42
Nodes (3): ConsentUITests, Bool, XCUIElement

### Community 92 - "SuggestFeatureSheet"
Cohesion: 0.28
Nodes (7): SuggestFeatureSheet, .body, .trimmedTitle, .valid, Bool, String, Void

### Community 93 - "ActivityGroup"
Cohesion: 0.25
Nodes (8): .color, ActivityGroup, .assetName, feeding, .id, medical, routine, .title

### Community 94 - "CareActivity"
Cohesion: 0.13
Nodes (17): MealEntry, CareActivity, .formattedValue, Data, UUID, Void, ClosedRange, TemperatureChartView (+9 more)

### Community 95 - "CareFont"
Cohesion: 0.13
Nodes (18): CareFont, .sleepSummary, IllnessTrackingView, .body, .days, .episodeCard, Bool, Color (+10 more)

### Community 96 - "Nội dung App Store Connect — Bé Khỏe (BabyCare)"
Cohesion: 0.25
Nodes (7): 1. Thông tin chung (không theo ngôn ngữ), 2. English (U.K.) — localization chính, 3. Vietnamese — localization thêm, 4. App Privacy (privacy nutrition labels), 5. Age rating questionnaire, 6. App Review Information, Nội dung App Store Connect — Bé Khỏe (BabyCare)

### Community 97 - "Quy trình phát hành Bé Khỏe lên App Store"
Cohesion: 0.25
Nodes (7): A. Trước khi archive, B. Tạo app trên App Store Connect, C. Archive và upload từ Xcode, D. Nộp duyệt, E. Sau khi lên store, Lý do từ chối hay gặp và trạng thái của app, Quy trình phát hành Bé Khỏe lên App Store

### Community 98 - "BabyGender"
Cohesion: 0.25
Nodes (7): BabyGender, boy, girl, .id, .title, unspecified, Self

### Community 99 - "CareDemoMode"
Cohesion: 0.22
Nodes (7): AppDependencies, CareDemoMode, .dataset, .hidesDemoBadge, .isActive, .isFullBuild, Bool

### Community 100 - "ConsentUITestFixture"
Cohesion: 0.25
Nodes (6): ConsentUITestFixture, .enabled, AsyncStream, AuthChangeEvent, Bool, Session

### Community 101 - "JoinFamilySheet"
Cohesion: 0.29
Nodes (7): InviteCodeSheet, InviteSheetItem, .id, JoinFamilySheet, .body, Bool, String

### Community 102 - "BabyCare consent flow"
Cohesion: 0.29
Nodes (6): BabyCare consent flow, Deployment and rollback, Known operational limits, Quyết định 14/10/2026: không gate theo phiên bản phía client, Runtime contract, Versions and existing users

### Community 103 - "Growth/generate.py"
Cohesion: 0.48
Nodes (6): cdc(), main(), Generate BabyCare/Domain/GrowthReferenceData.swift from the official growth…, swift_rows(), who_daily(), who_monthly()

### Community 104 - ".reveal"
Cohesion: 0.25
Nodes (4): FamilySharingUITests, CGFloat, Int, XCUIElement

### Community 107 - "Hai người cùng chăm một bé – nghiên cứu (24/10/2026)"
Cohesion: 0.33
Nodes (5): Backend đã có gì, Hai người cùng chăm một bé – nghiên cứu (24/10/2026), Những chỗ phải sửa trước khi mở tính năng, Thiết kế đề xuất, Ước lượng

### Community 109 - "Trả lời App Review – Guideline 2.1 Information Needed (21/10/2026)"
Cohesion: 0.40
Nodes (4): A. Quay video (mục 1), B. Reply (dán nguyên vào Resolution Center, giới hạn 4000 ký tự), C. Notes (App Review Information → Notes; đã dán trên App Store Connect), Trả lời App Review – Guideline 2.1 Information Needed (21/10/2026)

### Community 111 - "run-pglite.mjs"
Cohesion: 0.40
Nodes (4): db, { PGlite }, require, root

### Community 112 - "Link chiến dịch App Store"
Cohesion: 0.50
Nodes (3): Link chiến dịch App Store, Mốc so sánh, Đọc số liệu

### Community 114 - "BodyMeasurement"
Cohesion: 0.19
Nodes (10): LegacyArchive, LegacyJSONMigration, LegacySnapshot, Bool, String, MeasurementEntity, Double, BodyMeasurement (+2 more)

### Community 119 - "CareReminderService"
Cohesion: 0.40
Nodes (3): CareReminderService, NoopCareReminderService, Bool

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
Cohesion: 0.07
Nodes (23): CareFeedbackContext, .machine, .summary, CareFeedbackDraft, .canSend, .trimmedMessage, CareFeedbackKind, bug (+15 more)

### Community 124 - "Phase"
Cohesion: 0.33
Nodes (6): Phase, accountError, consent, content, signedOut, starting

## Knowledge Gaps
- **477 isolated node(s):** `.isFullBuild`, `.isActive`, `.hidesDemoBadge`, `.enabled`, `StoreKit` (+472 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 766 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **15 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `ActivityKind` connect `ActivityKind` to `.decode`, `MedicationReminder`, `Sendable`, `.text`, `CareReportSnapshot`, `CareTheme`, `ActivityFormViewModel`, `ActivityFormView`, `View`, `CaseIterable`, `Equatable`, `String`, `String`, `.number`, `AdaptiveLayoutUITests`, `ActivityPickerView`, `ActivityGroup`, `CareActivity`, `BabyGender`, `StitchAssetTests`?**
  _High betweenness centrality (0.124) - this node is a cross-community bridge._
- **Why does `CareActivity` connect `CareActivity` to `.decode`, `MedicationReminder`, `BabyCareViewModel`, `CareDatabase`, `Sendable`, `BabyCareTests`, `CareReportSnapshot`, `ActivityKind`, `FakeCloudRemote`, `.daySummary`, `VoiceInputViewModel`, `ActivityFormViewModel`, `ActivityFormView`, `Date`, `View`, `Equatable`, `.applying`, `CareReviewPolicy`, `CloudSnapshot`, `String`, `TemperatureDetail`, `SwiftDataCareDataProvider`, `String`, `.episodeSummary`, `.number`, `CareFont`, `BabyGender`, `BodyMeasurement`?**
  _High betweenness centrality (0.104) - this node is a cross-community bridge._
- **Why does `sleep` connect `AdaptiveLayoutUITests` to `StoreScreenshotsUITests`, `ActivityKind`?**
  _High betweenness centrality (0.098) - this node is a cross-community bridge._
- **Are the 55 inferred relationships involving `CareActivity` (e.g. with `.decode()` and `.read()`) actually correct?**
  _`CareActivity` has 55 INFERRED edges - model-reasoned connections that need verification._
- **Are the 12 inferred relationships involving `CareDatabase` (e.g. with `.preserveUnavailableVaccinations()` and `.fourBabiesCanSwitchAndRetryButCannotAddFifth()`) actually correct?**
  _`CareDatabase` has 12 INFERRED edges - model-reasoned connections that need verification._
- **Are the 47 inferred relationships involving `BabyCareViewModel` (e.g. with `.makeSession()` and `.makeSession()`) actually correct?**
  _`BabyCareViewModel` has 47 INFERRED edges - model-reasoned connections that need verification._
- **What connects `.isFullBuild`, `.isActive`, `.hidesDemoBadge` to the rest of the system?**
  _477 weakly-connected nodes found - possible documentation gaps or missing edges._