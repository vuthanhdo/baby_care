import Foundation
import SwiftData
import Testing
@testable import BabyCare

@MainActor
struct CareEntryDetailsTests {
    // MARK: Symptoms

    @Test func symptomsStoreTheirSecondLevelInCatalogueOrder() {
        let value = SymptomCatalog.format([SymptomChoice(name: "Ho", variant: "khan"), SymptomChoice(name: "Sốt", variant: "1–2 ngày"), SymptomChoice(name: "Mệt")])
        #expect(value == "Sốt (1–2 ngày), Ho (khan), Mệt")
        #expect(SymptomCatalog.parse(value) == [SymptomChoice(name: "Sốt", variant: "1–2 ngày"), SymptomChoice(name: "Ho", variant: "khan"), SymptomChoice(name: "Mệt")])
        #expect(SymptomChoice(token: "Ho (khan)").displayName == "\(L10n.text("Ho")) (\(L10n.text("khan")))")
    }

    @Test func oldAndUnknownSymptomTextIsKeptAsWritten() {
        #expect(SymptomCatalog.parse("Ho, Sổ mũi") == [SymptomChoice(name: "Ho"), SymptomChoice(name: "Sổ mũi")])
        // Brackets after a name the catalogue does not know are part of that name.
        #expect(SymptomChoice(token: "Vàng da (nhẹ)") == SymptomChoice(name: "Vàng da (nhẹ)"))
        for name in SymptomCatalog.names {
            #expect(SymptomCatalog.variants(for: name).allSatisfy { !$0.contains(", ") })
        }
    }

    @Test func untickingASymptomDropsItsSecondLevel() {
        let form = ActivityFormViewModel(kind: .symptom)
        form.send(.symptoms(["Ho", "Sốt"]))
        form.send(.symptomVariant("Ho", "có đờm"))
        form.send(.symptomVariant("Sốt", "3 ngày trở lên"))
        form.send(.symptoms(["Sốt"]))
        #expect(form.makeEntry()?.value == "Sốt (3 ngày trở lên)")
        form.send(.symptomVariant("Sốt", ""))
        #expect(form.makeEntry()?.value == "Sốt")
        let edited = ActivityFormViewModel(kind: .symptom, activity: CareActivity(kind: .symptom, value: "Ho (khan), Nôn"))
        #expect(edited.state.symptoms == ["Ho", "Nôn"] && edited.state.symptomVariants == ["Ho": "khan"])
    }

    // MARK: Allergies

    @Test func allergyLinesKeepNameSeverityAndCertainty() {
        let note = AllergyNote(name: "Đậu phộng", severity: "Nặng", certainty: "Đã xác nhận")
        #expect(note.line == "Đậu phộng · Nặng · Đã xác nhận")
        #expect(AllergyNote(line: note.line) == note)
        #expect(AllergyNote(line: "Tôm · Nghi ngờ") == AllergyNote(name: "Tôm", certainty: "Nghi ngờ"))
        // Free text from 1.0 stays one allergy, even when it happens to contain the separator.
        #expect(AllergyNote(line: "Phát ban khi ăn tôm · hay gãi") == AllergyNote(name: "Phát ban khi ăn tôm · hay gãi"))
        let text = AllergyNote.text([note, AllergyNote(name: "  Trứng "), AllergyNote(severity: "Nhẹ")])
        #expect(text == "Đậu phộng · Nặng · Đã xác nhận\nTrứng")
        #expect(AllergyNote.list(text) == [note, AllergyNote(name: "Trứng")])
    }

    @Test func allergyEntryNeedsANameAndStoresOneLine() {
        let form = ActivityFormViewModel(kind: .allergy)
        form.send(.allergy(AllergyNote(severity: "Nặng")))
        #expect(!form.valid)
        form.send(.allergy(AllergyNote(name: " Sữa bò ", severity: "Nặng", certainty: "Khả năng cao")))
        #expect(form.makeEntry()?.value == "Sữa bò · Nặng · Khả năng cao")
        // Only mild and severe are offered now; "Vừa" saved earlier still reads back as a severity.
        #expect(AllergyNote.severities == ["Nhẹ", "Nặng"])
        #expect(AllergyNote(line: "Tôm · Vừa · Nghi ngờ") == AllergyNote(name: "Tôm", severity: "Vừa", certainty: "Nghi ngờ"))
        let edited = ActivityFormViewModel(kind: .allergy, activity: CareActivity(kind: .allergy, value: "Nổi mẩn sau khi ăn cua"))
        #expect(edited.state.allergy == AllergyNote(name: "Nổi mẩn sau khi ăn cua"))
    }

    // MARK: Temperature

    @Test func temperatureDetailAddsTheThermometerToTheSite() {
        #expect(TemperatureDetail("Nách") == TemperatureDetail(site: "Nách"))
        #expect(TemperatureDetail("") == TemperatureDetail(site: "Chưa rõ"))
        #expect(TemperatureDetail("Hậu môn · Thủy ngân") == TemperatureDetail(site: "Hậu môn", thermometer: "Thủy ngân"))
        #expect(TemperatureDetail(site: "Tai", thermometer: "Điện tử").detail == "Tai · Điện tử")
        #expect(TemperatureDetail(site: "Tai").detail == "Tai")
        #expect(TemperatureReference.row(for: "Hậu môn")?.range == 36.6...38.0)
        #expect(TemperatureReference.row(for: "Trán") == nil)
    }

    // MARK: Medicine, meals, sleep, breathing

    @Test func medicinePhotoReplacesTheName() throws {
        let form = ActivityFormViewModel(kind: .medicine)
        form.send(.value("5"))
        form.send(.unit("ml"))
        #expect(!form.valid)
        form.send(.attachments([Data([1, 2, 3])]))
        let entry = try #require(form.makeEntry())
        #expect(entry.detail.isEmpty)
        try CareValidation.activity(entry)
        var unnamed = entry
        unnamed.attachments = []
        #expect(throws: CareDataError.self) { try CareValidation.activity(unnamed) }
    }

    @Test func mealFoodAndAmountAreOptional() throws {
        let empty = try #require(ActivityFormViewModel(kind: .meal).makeEntry())
        #expect(empty.value == CareActivity.recordedValue && empty.unit.isEmpty)
        let form = ActivityFormViewModel(kind: .meal)
        form.send(.value("Cháo bí đỏ"))
        form.send(.unit(" 1/2 bát "))
        let meal = try #require(form.makeEntry())
        #expect(meal.value == "Cháo bí đỏ" && meal.unit == "1/2 bát")
        #expect(meal.formattedValue == "Cháo bí đỏ · 1/2 bát")
        let amountOnly = CareActivity(kind: .meal, value: CareActivity.recordedValue, unit: "100 g")
        #expect(amountOnly.formattedValue == "100 g")
        #expect(ActivityFormViewModel(kind: .meal, activity: amountOnly).state.value.isEmpty)
    }

    @Test func pastSleepIsEnteredAsStartAndEnd() throws {
        let now = Date()
        let form = ActivityFormViewModel(kind: .sleep, now: now)
        #expect(form.state.date == now.addingTimeInterval(-3600) && form.state.value == "60")
        form.send(.sleepEnd(now.addingTimeInterval(-1800)))
        #expect(form.state.value == "30")
        // Moving the start keeps the end.
        form.send(.date(now.addingTimeInterval(-7200)))
        #expect(form.state.value == "90" && form.sleepEnd == now.addingTimeInterval(-1800))
        #expect(form.valid)
        form.send(.sleepEnd(now.addingTimeInterval(-7200)))
        #expect(!form.valid)
        form.send(.sleepEnd(now.addingTimeInterval(600)))
        #expect(!form.valid)
    }

    @Test func breathingRateIsCheckedAndReferencedByAge() throws {
        let form = ActivityFormViewModel(kind: .breathing)
        #expect(form.state.unit == "lần/phút" && form.state.detail == "Chưa rõ")
        form.send(.value("151"))
        #expect(!form.valid)
        form.send(.value("42"))
        let entry = try #require(form.makeEntry())
        try CareValidation.activity(entry)
        var tooFast = entry
        tooFast.value = "200"
        #expect(throws: CareDataError.self) { try CareValidation.activity(tooFast) }

        let calendar = Calendar.current
        let birth = try #require(calendar.date(from: DateComponents(year: 2026, month: 1, day: 10, hour: 12)))
        func band(months: Int) throws -> Int? {
            BreathingReference.band(birthDate: birth, at: try #require(calendar.date(byAdding: .month, value: months, to: birth)))?.fastFrom
        }
        #expect(try band(months: 1) == 60)
        #expect(try band(months: 2) == 50)
        #expect(try band(months: 11) == 50)
        #expect(try band(months: 12) == 40)
        #expect(try band(months: 60) == nil)
    }

    @Test func ageShowsMonthsAndDaysUntilTwoYears() throws {
        let calendar = Calendar.current
        func day(_ year: Int, _ month: Int, _ day: Int) throws -> Date {
            try #require(calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)))
        }
        let birth = try day(2026, 1, 10)
        #expect(BabyProfile.ageText(from: birth, at: try day(2026, 9, 12), language: .vietnamese) == "8 tháng 2 ngày")
        #expect(BabyProfile.ageText(from: birth, at: try day(2026, 2, 11), language: .english) == "1 month 1 day")
        #expect(BabyProfile.ageText(from: birth, at: try day(2026, 9, 10), language: .vietnamese) == "8 tháng tuổi")
        #expect(BabyProfile.ageText(from: birth, at: try day(2028, 3, 15), language: .vietnamese) == "2 tuổi 2 tháng")
    }

    // MARK: Cloud

    @Test func cloudSnapshotSkipsKindsFromNewerVersions() throws {
        let baby = BabyProfile(name: "Bé", birthDate: Date(timeIntervalSince1970: 1_700_000_000))
        let breathing = CareActivity(kind: .breathing, date: Date(timeIntervalSince1970: 1_750_000_000), value: "40", unit: "lần/phút", detail: "Lúc ngủ")
        let data = try CareDatabase().applying(.createBaby(baby)).applying(.saveActivities(babyID: baby.id, entries: [breathing]))
        var tables: [String: [CloudRow]] = [:]
        for (entity, rows) in CloudMapping.rows(data) {
            tables[entity] = rows.map { id, row in
                row.merging(["id": .id(id), "baby_id": .id(baby.id), "version": .number(1), "deleted_at": .null]) { _, new in new }
            }
        }
        #expect(try CloudMapping.decode(tables, revision: 1, selected: baby.id).database.selectedBaby?.activities == [breathing])
        var future = try #require(tables["care_activities"]?.first)
        future["id"] = .id(UUID())
        future["kind"] = .string("pulse")
        tables["care_activities"]?.append(future)
        #expect(try CloudMapping.decode(tables, revision: 1, selected: baby.id).database.selectedBaby?.activities == [breathing])
    }
}

@MainActor
struct HealthDetailsTests {
    @Test func doctorFollowUpIsSavedValidatedAndRemindedTwoDaysAhead() throws {
        let visit = Date().addingTimeInterval(-3600)
        let form = ActivityFormViewModel(kind: .doctor, activity: CareActivity(kind: .doctor, date: visit, value: "Khám ho"))
        form.send(.detail("Uống siro 2 lần/ngày"))
        form.send(.followUp(visit.addingTimeInterval(-60)))
        #expect(!form.valid)
        let appointment = visit.addingTimeInterval(5 * 86_400)
        form.send(.followUp(appointment))
        let entry = try #require(form.makeEntry())
        #expect(entry.followUpDate == appointment && entry.detail == "Uống siro 2 lần/ngày")
        try CareValidation.activity(entry)
        var misplaced = CareActivity(kind: .meal, value: "Cháo")
        misplaced.followUpDate = appointment
        #expect(throws: CareDataError.self) { try CareValidation.activity(misplaced) }
        // Other kinds never keep a follow-up from the form.
        #expect(ActivityFormViewModel(kind: .meal, activity: misplaced).makeEntry()?.followUpDate == nil)

        let baby = BabyProfile(name: "Bé", birthDate: visit.addingTimeInterval(-400 * 86_400))
        let data = try CareDatabase().applying(.createBaby(baby)).applying(.saveActivities(babyID: baby.id, entries: [entry]))
        let reminders = LocalCareReminderService(scope: "test").desired(in: data)
        #expect(reminders.map(\.date) == [appointment.addingTimeInterval(-2 * 86_400)])
        #expect(reminders.first?.id.contains("followup.\(entry.id.uuidString)") == true)
        #expect(DoctorFollowUp.upcoming(in: data.selectedBaby?.activities ?? []) == entry)
        // Less than two days ahead: shown on the home screen, but no reminder in the past.
        let soon = try CareDatabase().applying(.createBaby(baby)).applying(.saveActivities(babyID: baby.id, entries: [
            CareActivity(id: entry.id, kind: .doctor, date: visit, value: "Khám ho", followUpDate: Date().addingTimeInterval(86_400))]))
        #expect(LocalCareReminderService(scope: "test").desired(in: soon).isEmpty)
    }

    @Test func doctorDiagnosisIsKeptBesideTheReason() throws {
        let form = ActivityFormViewModel(kind: .doctor)
        form.send(.value("Sốt, ho"))
        form.send(.unit(" Viêm họng cấp "))
        let visit = try #require(form.makeEntry())
        #expect(visit.unit == "Viêm họng cấp" && DoctorVisit.diagnosis(visit) == "Viêm họng cấp")
        #expect(visit.formattedValue == "Sốt, ho · Viêm họng cấp")
        #expect(CareActivity(kind: .doctor, value: "Khám định kỳ").formattedValue == "Khám định kỳ")
        #expect(DoctorVisit.diagnosis(CareActivity(kind: .meal, value: "Cháo", unit: "1 bát")).isEmpty)
    }

    @Test func sleepRecommendationFollowsAge() throws {
        let calendar = Calendar.current
        let birth = try #require(calendar.date(from: DateComponents(year: 2026, month: 1, day: 10, hour: 12)))
        func hours(_ months: Int) throws -> ClosedRange<Int>? {
            SleepRecommendation.band(birthDate: birth, at: try #require(calendar.date(byAdding: .month, value: months, to: birth)))?.hours
        }
        #expect(try hours(0) == 14...17)
        #expect(try hours(3) == 14...17)
        #expect(try hours(4) == 12...16)
        #expect(try hours(12) == 11...14)
        #expect(try hours(36) == 10...13)
        #expect(try hours(72) == 9...12)
        #expect(try hours(160) == nil)
    }

    @Test func profilesFromBeforeMedicalHistoryStillDecode() throws {
        let old = #"{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","name":"Bé","birthDate":0,"gender":"girl","bloodType":"O","allergies":"","healthNotes":""}"#
        let profile = try JSONDecoder().decode(BabyProfile.self, from: Data(old.utf8))
        #expect(profile.medicalHistory.isEmpty && profile.name == "Bé")
        var updated = profile
        updated.medicalHistory = "Sinh non 35 tuần"
        #expect(try JSONDecoder().decode(BabyProfile.self, from: JSONEncoder().encode(updated)) == updated)
    }

    @Test func cloudRowsCarryMedicalHistoryAndFollowUps() throws {
        var baby = BabyProfile(name: "Bé", birthDate: Date(timeIntervalSince1970: 1_700_000_000))
        baby.medicalHistory = "Viêm phổi lúc 6 tháng"
        let visit = CareActivity(kind: .doctor, date: Date(timeIntervalSince1970: 1_750_000_000), value: "Khám", detail: "Lời dặn",
                                 followUpDate: Date(timeIntervalSince1970: 1_750_600_000))
        let meal = CareActivity(kind: .meal, date: Date(timeIntervalSince1970: 1_750_000_100), value: "Cháo", unit: "1 bát")
        let data = try CareDatabase().applying(.createBaby(baby)).applying(.saveActivities(babyID: baby.id, entries: [visit, meal]))
        let rows = CloudMapping.rows(data)
        #expect(rows["babies"]?[baby.id]?["medical_history"] == .string("Viêm phổi lúc 6 tháng"))
        #expect(rows["care_activities"]?[visit.id]?["follow_up_at"] == .date(visit.followUpDate))
        #expect(rows["care_activities"]?[meal.id]?["follow_up_at"] == nil)
        var tables: [String: [CloudRow]] = [:]
        for (entity, entityRows) in rows {
            tables[entity] = entityRows.map { id, row in
                row.merging(["id": .id(id), "baby_id": .id(baby.id), "version": .number(1), "deleted_at": .null]) { _, new in new }
            }
        }
        let decoded = try CloudMapping.decode(tables, revision: 1, selected: baby.id).database.selectedBaby
        #expect(decoded?.profile.medicalHistory == baby.medicalHistory)
        #expect(decoded?.activities.sorted { $0.date < $1.date } == [visit, meal])
        // Empty values are not sent, so a server without migration 0011 still accepts the rest…
        var plain = baby
        plain.medicalHistory = ""
        let unchanged = try CareDatabase().applying(.createBaby(plain))
        #expect(CloudMapping.rows(unchanged)["babies"]?[baby.id]?["medical_history"] == nil)
        // …and clearing a value sends its empty form explicitly instead of leaving the old one on the server.
        let before = CloudSnapshot(database: data, revision: 1)
        var clearedVisit = visit
        clearedVisit.followUpDate = nil
        let cleared = try data.applying(.updateBaby(plain)).applying(.saveActivities(babyID: baby.id, entries: [clearedVisit]))
        let sent = try CloudMapping.changes(from: before, to: cleared)
        #expect(sent.first { $0.entity == "babies" }?.data["medical_history"] == .string(""))
        #expect(sent.first { $0.entity == "care_activities" }?.data["follow_up_at"] == .null)
        // A server without migration 0011 returns neither column.
        tables["babies"]?[0].removeValue(forKey: "medical_history")
        tables["care_activities"] = tables["care_activities"]?.map { var row = $0; row.removeValue(forKey: "follow_up_at"); return row }
        let legacy = try CloudMapping.decode(tables, revision: 1, selected: baby.id).database.selectedBaby
        #expect(legacy?.profile.medicalHistory == "" && legacy?.activities.allSatisfy { $0.followUpDate == nil } == true)
    }

    @Test func storesCreatedByTheCurrentReleaseMigrateToV3() async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "BabyCare.store")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let baby = BabyData(profile: BabyProfile(name: "Bé V2", birthDate: Date().addingTimeInterval(-100 * 86_400)),
                            activities: [CareActivity(kind: .doctor, date: Date().addingTimeInterval(-3600), value: "Khám")])
        do {
            // Exactly what 1.0.x writes: the V2 schema without the side tables.
            let schema = Schema(versionedSchema: BabyCareSchemaV2.self)
            let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)])
            let context = ModelContext(container)
            let entity = BabyEntity(data: baby, sortOrder: 0)
            context.insert(entity)
            context.insert(try ActivityEntity(value: baby.activities[0], baby: entity))
            let metadata = CareMetadataEntity()
            metadata.selectedBabyID = baby.profile.id
            metadata.hasOnboarded = true
            metadata.didImportLegacyJSON = true
            context.insert(metadata)
            try context.save()
        }
        let provider = SwiftDataCareDataProvider(configuration: CarePersistenceConfiguration(storeURL: url))
        let loaded = try await provider.load()
        #expect(loaded.selectedBaby?.profile.name == "Bé V2" && loaded.selectedBaby?.activities.count == 1)
        var profile = try #require(loaded.selectedBaby?.profile)
        profile.medicalHistory = "Sinh non"
        _ = try await provider.apply(.updateBaby(profile))
        #expect(try await SwiftDataCareDataProvider(configuration: CarePersistenceConfiguration(storeURL: url)).load().selectedBaby?.profile.medicalHistory == "Sinh non")
    }

    @Test func localStoreKeepsHealthDetailsAcrossReopening() async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let configuration = CarePersistenceConfiguration(storeURL: folder.appending(path: "BabyCare.store"))
        var baby = BabyProfile(name: "Bé", birthDate: Date().addingTimeInterval(-300 * 86_400))
        baby.medicalHistory = "Sinh non"
        let visit = CareActivity(kind: .doctor, date: Date().addingTimeInterval(-3600), value: "Khám", followUpDate: Date().addingTimeInterval(7 * 86_400))
        let provider = SwiftDataCareDataProvider(configuration: configuration)
        _ = try await provider.apply(.createBaby(baby))
        _ = try await provider.apply(.saveActivities(babyID: baby.id, entries: [visit]))
        let reopened = try await SwiftDataCareDataProvider(configuration: configuration).load()
        #expect(reopened.selectedBaby?.profile.medicalHistory == "Sinh non")
        #expect(reopened.selectedBaby?.activities.first?.followUpDate == visit.followUpDate)

        var cleared = visit
        cleared.followUpDate = nil
        baby.medicalHistory = ""
        _ = try await provider.apply(.saveActivities(babyID: baby.id, entries: [cleared]))
        _ = try await provider.apply(.updateBaby(baby))
        let again = try await SwiftDataCareDataProvider(configuration: configuration).load()
        #expect(again.selectedBaby?.profile.medicalHistory == "" && again.selectedBaby?.activities.first?.followUpDate == nil)
    }
}
