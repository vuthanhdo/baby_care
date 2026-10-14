# Graph Report - BabyCare  (2026-09-16)

## Corpus Check
- 350 files · ~1,434,133 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1360 nodes · 3563 edges · 66 communities (60 shown, 6 thin omitted)
- Extraction: 85% EXTRACTED · 15% INFERRED · 0% AMBIGUOUS · INFERRED: 547 edges (avg confidence: 0.83)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `e82bea02`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- CareDatabase
- VoiceActivityParser
- OnboardingConsentView
- Date
- BodyMeasurement
- BabyCareViewModel
- CareDataMutation
- String
- StitchAppearanceTests
- .text
- MedicationReminder
- SuspendedStatusProvider
- AuthCaptchaView
- CareReportSnapshot
- CareTheme
- ActivityKind
- LocalCareReminderService
- Kiến trúc BabyCare
- .body
- .body
- .signOut
- CloudError
- CareActivity
- VoiceInputViewModel
- ActivityFormViewModel
- ActivityFormView
- CarePrimaryButton
- CareFont
- View
- Foundation
- Identifiable
- EntryFormCard
- BabyCareSchemaMigrationPlan
- ActivityFormAction
- ReportSection
- Components
- .applying
- BabyProfile
- .body
- BabyData
- CareDataProvider
- CareIcon
- import_stitch_icons.py
- generate.py
- Kế hoạch database cloud cho BabyCare
- BabyCare — Agent workflow
- SwiftDataCloudCache
- BabyCareAction
- .send
- CareStorageStatus
- StatisticsView
- SwiftUI
- .make
- .body
- RuntimeSafetyTests
- Vaccination Tracking
- InsightRange
- Đối chiếu giao diện Stitch → SwiftUI
- Rà soát crash và bộ nhớ — 11/09/2026
- Rà soát UI BabyCare — 11/09/2026
- Nhập và tự lưu bằng giọng nói
- Bật CAPTCHA cho BabyCare
- EntryReview-2026-09-12/README.md
- DataManagementView
- SessionViewModel
- Phase

## God Nodes (most connected - your core abstractions)
1. `CareActivity` - 77 edges
2. `CareDatabase` - 75 edges
3. `BabyCareViewModel` - 72 edges
4. `CareIcon` - 52 edges
5. `CareFont` - 49 edges
6. `ActivityFormView` - 46 edges
7. `ActivityKind` - 45 edges
8. `SupabaseCareDataProvider` - 44 edges
9. `BabyProfile` - 38 edges
10. `CareDataMutation` - 37 edges

## Surprising Connections (you probably didn't know these)
- `ControlledProvider` --implements--> `CareDataProvider`  [EXTRACTED]
  BabyCareTests/BabyCareTests.swift → BabyCare/Data/CareDataProvider.swift
- `DelayedCloudLoad` --implements--> `CareDataProvider`  [EXTRACTED]
  BabyCareTests/CloudProviderTests.swift → BabyCare/Data/CareDataProvider.swift
- `SuspendedStatusProvider` --implements--> `CareDataProvider`  [EXTRACTED]
  BabyCareTests/RuntimeSafetyTests.swift → BabyCare/Data/CareDataProvider.swift
- `FakeCloudRemote` --references--> `CloudError`  [EXTRACTED]
  BabyCareTests/CloudProviderTests.swift → BabyCare/Data/Cloud/SupabaseRemote.swift
- `.body` --calls--> `CareCard`  [INFERRED]
  BabyCare/DesignSystem/StitchStyle.swift → BabyCare/DesignSystem/CareComponents.swift

## Import Cycles
- None detected.

## Communities (66 total, 6 thin omitted)

### Community 0 - "CareDatabase"
Cohesion: 0.06
Nodes (50): CareCloudCache, CloudCacheState, .queuedWrites, PendingCloudWrite, Bool, CloudChange, CloudEnvelope, CloudMapping (+42 more)

### Community 1 - "VoiceActivityParser"
Cohesion: 0.13
Nodes (12): ParseError, .errorDescription, Calendar, String, VoiceActivityParser, Int, String, VoicePhraseNormalizer (+4 more)

### Community 2 - "OnboardingConsentView"
Cohesion: 0.14
Nodes (16): LegalDocument, .id, privacy, terms, .title, LegalDocumentView, .body, .sections (+8 more)

### Community 3 - "Date"
Cohesion: 0.19
Nodes (14): ActivityEntity, BabyEntity, CareMetadataEntity, MeasurementEntity, ReminderEntity, Bool, Data, Double (+6 more)

### Community 4 - "BodyMeasurement"
Cohesion: 0.17
Nodes (15): BodyMeasurement, Double, MeasurementHistoryView, .body, .sorted, MeasurementEntryView, .hasChanges, .headValue (+7 more)

### Community 5 - "BabyCareViewModel"
Cohesion: 0.07
Nodes (26): BabyCareViewModel, .activities, .baby, .hasOnboarded, .illnessStartDate, .illnessTitle, .isTrackingIllness, .measurements (+18 more)

### Community 6 - "CareDataMutation"
Cohesion: 0.08
Nodes (24): CareDataError, babyNotFound, conflict, corruptData, .errorDescription, CareDataMutation, .babyID, createBaby (+16 more)

### Community 7 - "String"
Cohesion: 0.09
Nodes (28): CloudMediaAsset, CloudMediaPlan, CloudMediaPurpose, activity, avatar, CloudMediaSyncResult, CloudMediaUpload, SHA256.Digest (+20 more)

### Community 8 - "StitchAppearanceTests"
Cohesion: 0.09
Nodes (11): BabyCareUITests, String, XCUIApplication, BabyCareUITestsLaunchTests, LanguageUITests, StitchAppearanceTests, String, XCUIApplication (+3 more)

### Community 9 - ".text"
Cohesion: 0.13
Nodes (19): .body, IllnessTrackingView, .body, .episodeCard, MedicationReminderView, .body, .valid, Bool (+11 more)

### Community 10 - "MedicationReminder"
Cohesion: 0.10
Nodes (20): AppDependencies, CarePersistenceConfiguration, .device, ModelContainer, ModelContext, Self, URL, SwiftDataCareDataProvider (+12 more)

### Community 11 - "SuspendedStatusProvider"
Cohesion: 0.29
Nodes (6): SuspendedStatusProvider, .waiting, Bool, CheckedContinuation, Never, Void

### Community 12 - "AuthCaptchaView"
Cohesion: 0.09
Nodes (21): AuthCaptchaConfiguration, .isEnabled, .pageURL, AuthCaptchaView, Coordinator, Bool, Error, URL (+13 more)

### Community 13 - "CareReportSnapshot"
Cohesion: 0.19
Nodes (10): CareReportPDF, CareReportSnapshot, ShareReportView, .body, .canPreview, Bool, DateInterval, Int (+2 more)

### Community 14 - "CareTheme"
Cohesion: 0.09
Nodes (26): CareTheme, CareBrandView, .body, CareDateTimeField, .body, CareFormCard, .body, CareInputStyle (+18 more)

### Community 15 - "ActivityKind"
Cohesion: 0.05
Nodes (41): .color, ActivityGroup, .assetName, feeding, .id, medical, routine, .title (+33 more)

### Community 16 - "LocalCareReminderService"
Cohesion: 0.10
Nodes (19): pending, CareNotification, CareNotificationCenter, CareReminderService, LocalCareReminderService, NoopCareReminderService, Bool, Never (+11 more)

### Community 17 - "Kiến trúc BabyCare"
Cohesion: 0.07
Nodes (24): App language, Cloud provider đã tích hợp, Kiến trúc BabyCare, Lưu dữ liệu trên device, Ranh giới các layer, Tài khoản và tối đa 4 bé (12/09/2026), BabyCare · SwiftUI, Chạy và xem trước (+16 more)

### Community 18 - ".body"
Cohesion: 0.24
Nodes (10): CareBottomTabs, .body, CareTab, diary, quick, statistics, ContentView, .body (+2 more)

### Community 19 - ".body"
Cohesion: 0.17
Nodes (13): AVFAudio, ProfileGuideView, .body, ProfilePermissionsView, .body, SettingsView, .appVersion, .body (+5 more)

### Community 20 - ".signOut"
Cohesion: 0.19
Nodes (8): AsyncStream, AuthChangeEvent, Bool, Int, Task, CareAccountSection, .body, Session

### Community 21 - "CloudError"
Cohesion: 0.10
Nodes (22): CloudConfiguration, CloudError, accessDenied, busy, conflict, .errorDescription, offline, signedOut (+14 more)

### Community 22 - "CareActivity"
Cohesion: 0.16
Nodes (18): CareActivity, .displayDetail, .formattedValue, .repeatedEntry, InsightData, Double, Int, TemperatureChartView (+10 more)

### Community 23 - "VoiceInputViewModel"
Cohesion: 0.09
Nodes (26): AnyObject, AVFoundation, AppleSpeechInputProvider, SpeechInputProvider, MainActor, Never, String, Task (+18 more)

### Community 24 - "ActivityFormViewModel"
Cohesion: 0.12
Nodes (18): ActivityFormState, ActivityFormViewModel, .attachments, .date, .detail, .loadingPhotos, .note, .number (+10 more)

### Community 25 - "ActivityFormView"
Cohesion: 0.13
Nodes (16): ActivityFormView, .dirty, .isEditing, .number, .numeric, .valid, .validationMessage, Bool (+8 more)

### Community 26 - "CarePrimaryButton"
Cohesion: 0.15
Nodes (16): CareAsyncButton, .body, CareBadge, .body, CarePrimaryButton, .body, Color, MainActor (+8 more)

### Community 27 - "CareFont"
Cohesion: 0.09
Nodes (32): CareFont, .body, BabyProfileView, .birthdayLabel, .body, .genderLabel, ProfileEditorView, .body (+24 more)

### Community 28 - "View"
Cohesion: 0.13
Nodes (26): .background, CareActivityRow, .body, CareCard, .body, CareSectionTitle, .body, Content (+18 more)

### Community 29 - "Foundation"
Cohesion: 0.19
Nodes (7): BabyCare, Foundation, Observation, Supabase, SwiftData, Testing, UserNotifications

### Community 30 - "Identifiable"
Cohesion: 0.14
Nodes (16): CloudFamily, Int, GrowthMetric, height, .id, .unit, Mode, .color (+8 more)

### Community 31 - "EntryFormCard"
Cohesion: 0.15
Nodes (11): EntryFieldLabel, .body, EntryFormCard, .body, EntryInputStyle, CGFloat, Content, Self (+3 more)

### Community 32 - "BabyCareSchemaMigrationPlan"
Cohesion: 0.16
Nodes (14): BabyCareSchemaMigrationPlan, .schemas, .stages, BabyCareSchemaV1, .models, .versionIdentifier, BabyCareSchemaV2, .models (+6 more)

### Community 33 - "ActivityFormAction"
Cohesion: 0.17
Nodes (12): ActivityFormAction, adjust, attachments, date, detail, loadingPhotos, note, symptoms (+4 more)

### Community 34 - "ReportSection"
Cohesion: 0.18
Nodes (11): ReportSection, .color, feeding, .group, growth, .icon, .id, medical (+3 more)

### Community 35 - "Components"
Cohesion: 0.08
Nodes (25): 1. Primary Bottom Action Button (Floating CTA), 2. Category Activity Chips (Pill Filter), 3. Bottom Tab Bar (3 Primary Tabs), 4. Baby Profile Header & Switcher Sheet, 5. Status Banners (Persistent Ongoing Trackers), 6. Toast Notification with Quick Undo, 7. Form Inputs & Steppers, Action & Feedback Token (+17 more)

### Community 36 - ".applying"
Cohesion: 0.16
Nodes (15): invalidInput, CareValidation, CodingKeys, activities, illnessStartDate, illnessTitle, isTrackingIllness, measurements (+7 more)

### Community 37 - "BabyProfile"
Cohesion: 0.19
Nodes (11): LegacyArchive, LegacyJSONMigration, LegacySnapshot, Bool, String, URL, BabyProfile, .ageDescription (+3 more)

### Community 38 - ".body"
Cohesion: 0.12
Nodes (14): App, BabyCareApp, .body, URL, AccountFeedback, .body, AccountLoadingErrorView, .body (+6 more)

### Community 39 - "BabyData"
Cohesion: 0.15
Nodes (15): BabyData, .selectedBaby, Decoder, VaccinationRecord, Bool, UUID, VaccinationEntryView, .baby (+7 more)

### Community 40 - "CareDataProvider"
Cohesion: 0.18
Nodes (3): CareDataProvider, InMemoryCareDataProvider, Bool

### Community 41 - "CareIcon"
Cohesion: 0.17
Nodes (13): CareBabyHeaderView, CareIcon, .body, CGFloat, .body, DiaryActivityCardView, .body, DiaryView (+5 more)

### Community 44 - "Kế hoạch database cloud cho BabyCare"
Cohesion: 0.17
Nodes (11): 10. Thông tin cần có khi bắt đầu triển khai, 1. Chọn Supabase Free, 2. Phạm vi và kiến trúc đích, 3. Schema đề xuất, 4. Đăng nhập và phân quyền, 5. API, ảnh và transaction, 6. Chuyển dữ liệu SwiftData hiện có lên cloud, 7. Đồng bộ offline (+3 more)

### Community 45 - "BabyCare — Agent workflow"
Cohesion: 0.18
Nodes (10): 1. Feature requirement, 2. Graphify graph, 3. Dependency / impact analysis, 4. Inspect đúng source cần thiết, 5. Implementation plan, 6. Code, 7. Tests, 8. Graphify impact/review (+2 more)

### Community 46 - "SwiftDataCloudCache"
Cohesion: 0.23
Nodes (7): CloudCacheRecord, Data, ModelContainer, ModelContext, URL, UUID, SwiftDataCloudCache

### Community 47 - "BabyCareAction"
Cohesion: 0.14
Nodes (13): BabyCareAction, commit, dismissError, load, showMessage, BabyCareState, Phase, failed (+5 more)

### Community 48 - ".send"
Cohesion: 0.22
Nodes (8): .attachments, .date, .detail, .loadingPhotos, .note, .symptoms, .unit, .value

### Community 49 - "CareStorageStatus"
Cohesion: 0.22
Nodes (7): CareStorageStatus, cached, cacheWarning, cloud, device, .message, String

### Community 50 - "StatisticsView"
Cohesion: 0.32
Nodes (7): StatisticsView, .activities, .interval, .medicines, .temperatures, Color, DateInterval

### Community 51 - "SwiftUI"
Cohesion: 0.21
Nodes (5): Charts, ImageIO, PhotosUI, SwiftUI, UIKit

### Community 53 - ".body"
Cohesion: 0.16
Nodes (13): Field, confirmation, email, password, SignInView, .body, .captchaSection, .emailDivider (+5 more)

### Community 55 - "Vaccination Tracking"
Cohesion: 0.33
Nodes (5): Dependency / impact review, Deployment and compatibility, Login load regression (2026-09-13), Vaccination Tracking, Validation completed

### Community 57 - "InsightRange"
Cohesion: 0.17
Nodes (11): InsightDateRangeView, .body, InsightRange, custom, hours48, .id, today, week (+3 more)

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

### Community 64 - "DataManagementView"
Cohesion: 0.25
Nodes (6): DataManagementView, .body, .isCloudAccount, DestructiveConfirmation, Bool, String

### Community 65 - "SessionViewModel"
Cohesion: 0.18
Nodes (10): AuthAction, resetPassword, signIn, signUp, SessionViewModel, Error, Never, String (+2 more)

### Community 70 - "Phase"
Cohesion: 0.40
Nodes (5): Phase, accountError, content, signedOut, starting

## Knowledge Gaps
- **258 isolated node(s):** `quick`, `diary`, `statistics`, `.queuedWrites`, `CryptoKit` (+253 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 420 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **6 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `CareActivity` connect `CareActivity` to `CareDatabase`, `VoiceActivityParser`, `Date`, `BodyMeasurement`, `BabyCareViewModel`, `CareDataMutation`, `String`, `.text`, `MedicationReminder`, `CareReportSnapshot`, `ActivityKind`, `VoiceInputViewModel`, `ActivityFormViewModel`, `ActivityFormView`, `CarePrimaryButton`, `View`, `Identifiable`, `.applying`, `BabyProfile`, `BabyData`, `CareIcon`, `StatisticsView`, `.make`?**
  _High betweenness centrality (0.105) - this node is a cross-community bridge._
- **Why does `BabyCareViewModel` connect `BabyCareViewModel` to `CareDatabase`, `Date`, `BodyMeasurement`, `.text`, `MedicationReminder`, `SuspendedStatusProvider`, `CareReportSnapshot`, `CareTheme`, `LocalCareReminderService`, `CareActivity`, `VoiceInputViewModel`, `ActivityFormView`, `CarePrimaryButton`, `CareFont`, `View`, `BabyProfile`, `.body`, `BabyData`, `CareDataProvider`, `CareIcon`, `BabyCareAction`, `StatisticsView`, `.make`, `DataManagementView`, `SessionViewModel`?**
  _High betweenness centrality (0.081) - this node is a cross-community bridge._
- **Why does `Date` connect `Date` to `CareDatabase`, `VoiceActivityParser`, `BabyCareViewModel`, `CareDataMutation`, `.text`, `CareTheme`, `LocalCareReminderService`, `CareActivity`, `VoiceInputViewModel`, `ActivityFormViewModel`, `ActivityFormView`, `CarePrimaryButton`, `CareFont`, `View`, `ActivityFormAction`, `.applying`, `BabyProfile`, `BabyData`, `StatisticsView`, `InsightRange`?**
  _High betweenness centrality (0.070) - this node is a cross-community bridge._
- **Are the 34 inferred relationships involving `CareActivity` (e.g. with `.decode()` and `.read()`) actually correct?**
  _`CareActivity` has 34 INFERRED edges - model-reasoned connections that need verification._
- **Are the 8 inferred relationships involving `CareDatabase` (e.g. with `.preserveUnavailableVaccinations()` and `.fourBabiesCanSwitchAndRetryButCannotAddFifth()`) actually correct?**
  _`CareDatabase` has 8 INFERRED edges - model-reasoned connections that need verification._
- **Are the 34 inferred relationships involving `BabyCareViewModel` (e.g. with `.body` and `.current`) actually correct?**
  _`BabyCareViewModel` has 34 INFERRED edges - model-reasoned connections that need verification._
- **Are the 43 inferred relationships involving `CareIcon` (e.g. with `.tab()` and `.body`) actually correct?**
  _`CareIcon` has 43 INFERRED edges - model-reasoned connections that need verification._