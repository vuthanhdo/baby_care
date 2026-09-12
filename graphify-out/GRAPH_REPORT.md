# Graph Report - BabyCare  (2026-09-12)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 1110 nodes · 2985 edges · 44 communities (41 shown, 2 thin omitted)
- Extraction: 84% EXTRACTED · 16% INFERRED · 0% AMBIGUOUS · INFERRED: 473 edges (avg confidence: 0.83)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `9639ccd2`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- CareDatabase
- BabyProfile
- Foundation
- Date
- VoiceInputViewModel
- BabyCareViewModel
- CareDataMutation
- AppLanguage
- StitchAppearanceTests
- CareFont
- BabyCareTests
- SuspendedStatusProvider
- AuthCaptchaView
- String
- .body
- ActivityKind
- CareIcon
- CareActivity
- .body
- .text
- SessionViewModel
- BodyMeasurement
- StatisticsView
- AppleSpeechInputProvider
- ActivityFormViewModel
- ActivityFormView
- CarePrimaryButton
- OnboardingView
- View
- ActivityGroup
- Mode
- .body
- EntryFormCard
- ActivityFormAction
- ReportSection
- .authenticate
- .passwordError
- .send
- MedicationReminderView
- InsightRange
- Phase
- import_stitch_icons.py
- generate.py

## God Nodes (most connected - your core abstractions)
1. `CareActivity` - 76 edges
2. `BabyCareViewModel` - 67 edges
3. `CareDatabase` - 60 edges
4. `CareIcon` - 49 edges
5. `ActivityFormView` - 46 edges
6. `CareFont` - 46 edges
7. `ActivityKind` - 45 edges
8. `SupabaseCareDataProvider` - 36 edges
9. `BabyProfile` - 34 edges
10. `BodyMeasurement` - 34 edges

## Surprising Connections (you probably didn't know these)
- `ControlledProvider` --implements--> `CareDataProvider`  [EXTRACTED]
  BabyCareTests/BabyCareTests.swift → BabyCare/Data/CareDataProvider.swift
- `SuspendedStatusProvider` --implements--> `CareDataProvider`  [EXTRACTED]
  BabyCareTests/RuntimeSafetyTests.swift → BabyCare/Data/CareDataProvider.swift
- `ControlledProvider` --calls--> `CareDatabase`  [EXTRACTED]
  BabyCareTests/BabyCareTests.swift → BabyCare/Domain/CareDatabase.swift
- `FakeCloudRemote` --references--> `CloudEnvelope`  [EXTRACTED]
  BabyCareTests/CloudProviderTests.swift → BabyCare/Data/Cloud/CloudWire.swift
- `FakeCloudRemote` --references--> `CloudReceipt`  [EXTRACTED]
  BabyCareTests/CloudProviderTests.swift → BabyCare/Data/Cloud/CloudWire.swift

## Import Cycles
- None detected.

## Communities (44 total, 2 thin omitted)

### Community 0 - "CareDatabase"
Cohesion: 0.06
Nodes (40): CareDataProvider, InMemoryCareDataProvider, CareCloudCache, CloudCacheRecord, CloudCacheState, .queuedWrites, PendingCloudWrite, Data (+32 more)

### Community 1 - "BabyProfile"
Cohesion: 0.05
Nodes (56): CloudMediaAsset, CloudMediaPlan, CloudMediaPurpose, activity, avatar, CloudMediaSyncResult, CloudMediaUpload, Bool (+48 more)

### Community 2 - "Foundation"
Cohesion: 0.06
Nodes (25): AVFAudio, BabyCare, CloudConfiguration, CarePreviewData, BabyCareAction, commit, dismissError, load (+17 more)

### Community 3 - "Date"
Cohesion: 0.08
Nodes (31): ActivityEntity, BabyCareSchemaMigrationPlan, .schemas, .stages, BabyCareSchemaV1, .models, .versionIdentifier, BabyEntity (+23 more)

### Community 4 - "VoiceInputViewModel"
Cohesion: 0.08
Nodes (22): ParseError, .errorDescription, Calendar, String, VoiceActivityParser, Int, String, VoicePhraseNormalizer (+14 more)

### Community 5 - "BabyCareViewModel"
Cohesion: 0.05
Nodes (39): CareReminderService, LocalCareReminderService, NoopCareReminderService, Set, String, BabyCareState, BabyCareViewModel, .activities (+31 more)

### Community 6 - "CareDataMutation"
Cohesion: 0.07
Nodes (34): CloudError, accessDenied, busy, conflict, .errorDescription, offline, signedOut, uncertain (+26 more)

### Community 7 - "AppLanguage"
Cohesion: 0.08
Nodes (22): App, BabyCareApp, .body, AppLanguage, .current, english, .id, .locale (+14 more)

### Community 8 - "StitchAppearanceTests"
Cohesion: 0.10
Nodes (10): BabyCareUITests, String, XCUIApplication, BabyCareUITestsLaunchTests, LanguageUITests, StitchAppearanceTests, String, XCUIApplication (+2 more)

### Community 9 - "CareFont"
Cohesion: 0.13
Nodes (27): CareCard, CareTheme, Content, .body, CareFont, CareFormCard, .body, Content (+19 more)

### Community 10 - "BabyCareTests"
Cohesion: 0.16
Nodes (10): BabyCareTests, ControlledProvider, .isWaiting, RecordingReminderService, Bool, CheckedContinuation, Never, String (+2 more)

### Community 11 - "SuspendedStatusProvider"
Cohesion: 0.08
Nodes (16): CareImageProcessor, Bool, Data, Int, RuntimeSafetyTests, SuspendedStatusProvider, .waiting, Bool (+8 more)

### Community 12 - "AuthCaptchaView"
Cohesion: 0.09
Nodes (21): AuthCaptchaConfiguration, .isEnabled, .pageURL, AuthCaptchaView, Coordinator, Bool, Error, URL (+13 more)

### Community 13 - "String"
Cohesion: 0.12
Nodes (17): SHA256.Digest, .hex, InsightBadge, .body, InsightDateRangeView, .body, DateInterval, Void (+9 more)

### Community 14 - ".body"
Cohesion: 0.10
Nodes (23): CareBrandView, .body, CareDateTimeField, .body, CareInputStyle, CareSplashView, .body, CGFloat (+15 more)

### Community 15 - "ActivityKind"
Cohesion: 0.08
Nodes (23): ActivityKind, allergy, .assetName, bath, .defaultUnit, diaper, doctor, .group (+15 more)

### Community 16 - "CareIcon"
Cohesion: 0.12
Nodes (22): .body, CareIcon, .body, .body, CGFloat, CareActionStyle, Color, BabyProfileView (+14 more)

### Community 17 - "CareActivity"
Cohesion: 0.13
Nodes (23): CloudFamily, Int, String, CareActivity, .displayDetail, .formattedValue, ActivityDetailView, .repeatedEntry (+15 more)

### Community 18 - ".body"
Cohesion: 0.12
Nodes (18): CareBottomTabs, .body, CareTab, diary, quick, statistics, ContentView, .body (+10 more)

### Community 19 - ".text"
Cohesion: 0.16
Nodes (14): .body, UUID, VoiceEntryView, .body, .googleButton, ProfileHealthEditorView, .body, ProfileGuideView (+6 more)

### Community 20 - "SessionViewModel"
Cohesion: 0.14
Nodes (10): AsyncStream, AuthChangeEvent, AppDependencies, SessionViewModel, Int, Never, Task, UUID (+2 more)

### Community 21 - "BodyMeasurement"
Cohesion: 0.18
Nodes (14): BodyMeasurement, Double, MeasurementHistoryView, .body, .sorted, MeasurementEntryView, .hasChanges, .headValue (+6 more)

### Community 22 - "StatisticsView"
Cohesion: 0.17
Nodes (14): InsightData, InsightMetricView, Color, Double, Int, StatisticsView, .activities, .foodContent (+6 more)

### Community 23 - "AppleSpeechInputProvider"
Cohesion: 0.19
Nodes (13): AnyObject, AVFoundation, AppleSpeechInputProvider, SpeechInputProvider, MainActor, Never, String, Task (+5 more)

### Community 24 - "ActivityFormViewModel"
Cohesion: 0.13
Nodes (18): ActivityFormState, ActivityFormViewModel, .attachments, .date, .detail, .loadingPhotos, .note, .number (+10 more)

### Community 25 - "ActivityFormView"
Cohesion: 0.13
Nodes (16): ActivityFormView, .dirty, .isEditing, .number, .numeric, .valid, .validationMessage, Bool (+8 more)

### Community 26 - "CarePrimaryButton"
Cohesion: 0.17
Nodes (15): .background, CareActivityRow, .body, CareAsyncButton, .body, CareBadge, .body, .body (+7 more)

### Community 27 - "OnboardingView"
Cohesion: 0.16
Nodes (16): .birthdayLabel, .body, OnboardingView, .body, .hasDraft, .validName, profileAge(), ProfileAvatarView (+8 more)

### Community 28 - "View"
Cohesion: 0.26
Nodes (9): CareSectionTitle, .body, View, InsightActivityRow, ReportPreviewView, .body, Color, String (+1 more)

### Community 29 - "ActivityGroup"
Cohesion: 0.13
Nodes (15): .color, ActivityGroup, .assetName, feeding, .id, medical, routine, .title (+7 more)

### Community 30 - "Mode"
Cohesion: 0.17
Nodes (13): GrowthMetric, height, .id, .unit, Mode, .color, food, growth (+5 more)

### Community 31 - ".body"
Cohesion: 0.24
Nodes (10): Field, confirmation, email, password, SignInView, .body, .captchaSection, .emailDivider (+2 more)

### Community 32 - "EntryFormCard"
Cohesion: 0.17
Nodes (10): EntryFieldLabel, EntryFormCard, .body, EntryInputStyle, CGFloat, Content, Self, String (+2 more)

### Community 33 - "ActivityFormAction"
Cohesion: 0.17
Nodes (12): ActivityFormAction, adjust, attachments, date, detail, loadingPhotos, note, symptoms (+4 more)

### Community 34 - "ReportSection"
Cohesion: 0.18
Nodes (11): ReportSection, .color, feeding, .group, growth, .icon, .id, medical (+3 more)

### Community 35 - ".authenticate"
Cohesion: 0.31
Nodes (6): AuthAction, resetPassword, signIn, signUp, Error, String

### Community 36 - ".passwordError"
Cohesion: 0.36
Nodes (3): AuthValidation, String, AuthValidationTests

### Community 37 - ".send"
Cohesion: 0.22
Nodes (8): .attachments, .date, .detail, .loadingPhotos, .note, .symptoms, .unit, .value

### Community 38 - "MedicationReminderView"
Cohesion: 0.33
Nodes (5): MedicationReminderView, .body, .valid, Bool, String

### Community 39 - "InsightRange"
Cohesion: 0.29
Nodes (7): InsightRange, custom, hours48, .id, today, week, Self

### Community 40 - "Phase"
Cohesion: 0.40
Nodes (5): Phase, accountError, content, signedOut, starting

## Knowledge Gaps
- **168 isolated node(s):** `.queuedWrites`, `cached`, `cacheWarning`, `cloud`, `device` (+163 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 307 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **2 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `CareActivity` connect `CareActivity` to `CareDatabase`, `BabyProfile`, `Date`, `VoiceInputViewModel`, `BabyCareViewModel`, `CareDataMutation`, `CareFont`, `BabyCareTests`, `String`, `ActivityKind`, `.body`, `BodyMeasurement`, `StatisticsView`, `ActivityFormViewModel`, `ActivityFormView`, `CarePrimaryButton`, `View`, `ActivityGroup`, `.save`?**
  _High betweenness centrality (0.134) - this node is a cross-community bridge._
- **Why does `BabyCareViewModel` connect `BabyCareViewModel` to `CareDatabase`, `BabyProfile`, `Foundation`, `Date`, `VoiceInputViewModel`, `AppLanguage`, `CareFont`, `BabyCareTests`, `SuspendedStatusProvider`, `String`, `.body`, `CareActivity`, `.body`, `.text`, `SessionViewModel`, `BodyMeasurement`, `StatisticsView`, `ActivityFormView`, `CarePrimaryButton`?**
  _High betweenness centrality (0.121) - this node is a cross-community bridge._
- **Why does `CareDatabase` connect `CareDatabase` to `BabyProfile`, `Foundation`, `Date`, `BabyCareViewModel`, `CareDataMutation`, `BabyCareTests`, `SuspendedStatusProvider`, `.text`?**
  _High betweenness centrality (0.083) - this node is a cross-community bridge._
- **Are the 33 inferred relationships involving `CareActivity` (e.g. with `.decode()` and `.read()`) actually correct?**
  _`CareActivity` has 33 INFERRED edges - model-reasoned connections that need verification._
- **Are the 31 inferred relationships involving `BabyCareViewModel` (e.g. with `.body` and `.current`) actually correct?**
  _`BabyCareViewModel` has 31 INFERRED edges - model-reasoned connections that need verification._
- **Are the 40 inferred relationships involving `CareIcon` (e.g. with `.tab()` and `.body`) actually correct?**
  _`CareIcon` has 40 INFERRED edges - model-reasoned connections that need verification._
- **What connects `.queuedWrites`, `cached`, `cacheWarning` to the rest of the system?**
  _168 weakly-connected nodes found - possible documentation gaps or missing edges._