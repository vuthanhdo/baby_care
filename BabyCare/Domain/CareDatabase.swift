import Foundation

/// Value types cross the provider boundary; neither Views nor ViewModels see @Model objects.
nonisolated struct BabyData: Codable, Sendable, Equatable {
    var profile: BabyProfile
    var activities: [CareActivity] = []
    var measurements: [BodyMeasurement] = []
    var medicationReminders: [MedicationReminder] = []
    var isTrackingIllness = false
    var illnessTitle = ""
    var illnessStartDate = Date()
    var sleepStartDate: Date?
    var vaccinations: [VaccinationRecord] = []
}

nonisolated struct CareDatabase: Codable, Sendable, Equatable {
    static let maximumBabies = 4
    var babies: [BabyData] = []
    var selectedBabyID: UUID?
    var hasOnboarded = false

    var selectedBaby: BabyData? {
        babies.first { $0.profile.id == selectedBabyID } ?? babies.first
    }

    /// A pure reducer shared by the local and in-memory providers.
    /// Cloud providers must apply the same mutations atomically on their backend.
    func applying(_ mutation: CareDataMutation) throws -> CareDatabase {
        var next = self
        switch mutation {
        case .createBaby(let profile):
            try CareValidation.profile(profile)
            if let existing = next.babies.first(where: { $0.profile.id == profile.id }) {
                guard existing.profile == profile else { throw CareDataError.conflict }
            } else {
                guard next.babies.count < Self.maximumBabies else {
                    throw CareDataError.invalidInput(L10n.text("Bạn chỉ có thể tạo tối đa 4 hồ sơ bé."))
                }
                next.babies.append(BabyData(profile: profile))
            }
            next.selectedBabyID = profile.id
            next.hasOnboarded = true
        case .deleteBaby(let id):
            guard next.babies.contains(where: { $0.profile.id == id }) else { throw CareDataError.babyNotFound }
            next.babies.removeAll { $0.profile.id == id }
            next.selectedBabyID = next.babies.first?.profile.id
            next.hasOnboarded = !next.babies.isEmpty
        case .selectBaby(let id):
            guard next.babies.contains(where: { $0.profile.id == id }) else { throw CareDataError.babyNotFound }
            next.selectedBabyID = id
        default:
            guard let babyID = mutation.babyID,
                  let index = next.babies.firstIndex(where: { $0.profile.id == babyID }) else { throw CareDataError.babyNotFound }
            var baby = next.babies[index]
            switch mutation {
            case .updateBaby(let profile):
                try CareValidation.profile(profile)
                let firstEntry = (baby.activities.map(\.date) + baby.measurements.map(\.date) + baby.vaccinations.map(\.date)).min() ?? Date()
                guard profile.birthDate <= firstEntry else { throw CareDataError.invalidInput(L10n.text("Ngày sinh không được sau dữ liệu đã ghi.")) }
                baby.profile = profile
            case .saveActivities(_, let entries, let finishingSleep, let reminderID):
                guard !entries.isEmpty, Set(entries.map(\.id)).count == entries.count else { throw CareDataError.invalidInput(L10n.text("Danh sách hoạt động không hợp lệ.")) }
                for entry in entries {
                    try CareValidation.activity(entry)
                    guard !next.babies.contains(where: { $0.profile.id != babyID && $0.activities.contains(where: { $0.id == entry.id }) }) else { throw CareDataError.conflict }
                    if let position = baby.activities.firstIndex(where: { $0.id == entry.id }) { baby.activities[position] = entry }
                    else { baby.activities.append(entry) }
                }
                baby.activities.sort { $0.date > $1.date }
                if let finishingSleep, baby.sleepStartDate == finishingSleep,
                   entries.contains(where: { $0.kind == .sleep && $0.date == finishingSleep }) { baby.sleepStartDate = nil }
                if let reminderID, let position = baby.medicationReminders.firstIndex(where: { $0.id == reminderID }) {
                    let reminder = baby.medicationReminders[position]
                    if entries.contains(where: { $0.kind == .medicine && $0.detail.localizedCaseInsensitiveCompare(reminder.name) == .orderedSame && $0.unit == reminder.unit && $0.numericValue == CareValidation.number(reminder.amount) }) {
                        baby.medicationReminders[position].enabled = false
                    }
                }
            case .deleteActivity(_, let id):
                baby.activities.removeAll { $0.id == id }
            case .saveMeasurement(_, let measurement):
                try CareValidation.measurement(measurement, birthDate: baby.profile.birthDate)
                guard !next.babies.contains(where: { $0.profile.id != babyID && $0.measurements.contains(where: { $0.id == measurement.id }) }) else { throw CareDataError.conflict }
                if let position = baby.measurements.firstIndex(where: { $0.id == measurement.id }) { baby.measurements[position] = measurement }
                else { baby.measurements.append(measurement) }
                baby.measurements.sort { $0.date > $1.date }
            case .saveVaccination(_, let record, let completingID):
                try CareValidation.vaccination(record, birthDate: baby.profile.birthDate)
                guard !next.babies.contains(where: { $0.profile.id != babyID && $0.vaccinations.contains(where: { $0.id == record.id }) }) else { throw CareDataError.conflict }
                if let completingID {
                    guard completingID != record.id,
                          let previous = baby.vaccinations.firstIndex(where: { $0.id == completingID }),
                          baby.vaccinations[previous].date <= record.date else { throw CareDataError.conflict }
                    baby.vaccinations[previous].reminderEnabled = false
                    baby.vaccinations[previous].nextDoseDate = nil
                    baby.vaccinations[previous].reminderDate = nil
                }
                if let position = baby.vaccinations.firstIndex(where: { $0.id == record.id }) { baby.vaccinations[position] = record }
                else { baby.vaccinations.append(record) }
                baby.vaccinations.sort { $0.date == $1.date ? $0.id.uuidString < $1.id.uuidString : $0.date > $1.date }
            case .deleteVaccination(_, let id):
                baby.vaccinations.removeAll { $0.id == id }
            case .startSleep(_, let date):
                guard date <= Date(), baby.sleepStartDate == nil || baby.sleepStartDate == date else { throw CareDataError.invalidInput(L10n.text("Bé đã có giấc ngủ đang diễn ra.")) }
                baby.sleepStartDate = date
            case .startIllness(_, let title, let date):
                guard date >= baby.profile.birthDate, date <= Date() else { throw CareDataError.invalidInput(L10n.text("Ngày bắt đầu theo dõi không hợp lệ.")) }
                baby.isTrackingIllness = true
                baby.illnessTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                baby.illnessStartDate = date
            case .endIllness:
                baby.isTrackingIllness = false
                for position in baby.medicationReminders.indices where baby.medicationReminders[position].episodeOnly {
                    baby.medicationReminders[position].enabled = false
                }
            case .saveReminder(_, let reminder):
                try CareValidation.reminder(reminder)
                guard !next.babies.contains(where: { $0.profile.id != babyID && $0.medicationReminders.contains(where: { $0.id == reminder.id }) }) else { throw CareDataError.conflict }
                if let position = baby.medicationReminders.firstIndex(where: { $0.id == reminder.id }) { baby.medicationReminders[position] = reminder }
                else { baby.medicationReminders.append(reminder) }
            case .deleteReminder(_, let id):
                baby.medicationReminders.removeAll { $0.id == id }
            case .createBaby, .deleteBaby, .selectBaby: break
            }
            next.babies[index] = baby
        }
        return next
    }
}

nonisolated enum CareDataMutation: Codable, Sendable, Equatable {
    case createBaby(BabyProfile)
    case deleteBaby(UUID)
    case updateBaby(BabyProfile)
    case selectBaby(UUID)
    case saveActivities(babyID: UUID, entries: [CareActivity], finishingSleep: Date? = nil, completingReminderID: UUID? = nil)
    case deleteActivity(babyID: UUID, activityID: UUID)
    case saveMeasurement(babyID: UUID, measurement: BodyMeasurement)
    case saveVaccination(babyID: UUID, record: VaccinationRecord, completingID: UUID? = nil)
    case deleteVaccination(babyID: UUID, vaccinationID: UUID)
    case startSleep(babyID: UUID, date: Date)
    case startIllness(babyID: UUID, title: String, date: Date)
    case endIllness(babyID: UUID)
    case saveReminder(babyID: UUID, reminder: MedicationReminder)
    case deleteReminder(babyID: UUID, reminderID: UUID)

    var babyID: UUID? {
        switch self {
        case .createBaby(let baby), .updateBaby(let baby): baby.id
        case .deleteBaby(let id), .selectBaby(let id), .endIllness(let id): id
        case .saveVaccination(let id, _, _), .deleteVaccination(let id, _): id
        case .saveActivities(let id, _, _, _), .deleteActivity(let id, _), .saveMeasurement(let id, _),
             .startSleep(let id, _), .startIllness(let id, _, _), .saveReminder(let id, _), .deleteReminder(let id, _): id
        }
    }
}

nonisolated enum CareDataError: Error, LocalizedError, Sendable {
    case babyNotFound, conflict, corruptData, invalidInput(String)
    var errorDescription: String? {
        switch self {
        case .babyNotFound: L10n.text("Không tìm thấy hồ sơ bé. Hãy tải lại dữ liệu.")
        case .conflict: L10n.text("Dữ liệu đã thay đổi hoặc trùng mã bản ghi. Hãy tải lại trước khi lưu.")
        case .corruptData: L10n.text("Không đọc được dữ liệu đã lưu. Dữ liệu gốc vẫn được giữ.")
        case .invalidInput(let message): message
        }
    }
}

nonisolated enum CareValidation {
    static func number(_ text: String) -> Double? {
        guard let number = Double(text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")), number.isFinite else { return nil }
        return number
    }
    static func profile(_ profile: BabyProfile) throws {
        guard !profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, profile.birthDate <= Date() else { throw CareDataError.invalidInput(L10n.text("Nhập tên và ngày sinh hợp lệ.")) }
    }
    static func activity(_ entry: CareActivity) throws {
        guard entry.date <= Date(), !entry.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw CareDataError.invalidInput(L10n.text("Nhập nội dung và thời điểm hợp lệ.")) }
        if [.temperature, .medicine, .milk, .water, .sleep].contains(entry.kind) {
            guard let value = number(entry.value), value > 0, !entry.unit.isEmpty else { throw CareDataError.invalidInput(L10n.text("Nhập số dương và đơn vị để lưu.")) }
            if entry.kind == .sleep && entry.detail != CareActivity.recordedSleepDetail && entry.date.addingTimeInterval(value * 60) > Date().addingTimeInterval(60) { throw CareDataError.invalidInput(L10n.text("Giấc ngủ không được kết thúc trong tương lai.")) }
        }
        if entry.kind == .medicine && entry.detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { throw CareDataError.invalidInput(L10n.text("Nhập tên thuốc đã dùng.")) }
        guard entry.attachments.count <= 3 else { throw CareDataError.invalidInput(L10n.text("Mỗi hoạt động tối đa 3 ảnh.")) }
    }
    static func measurement(_ entry: BodyMeasurement, birthDate: Date) throws {
        let values = [entry.weight, entry.height, entry.headCircumference].compactMap { $0 }
        guard !values.isEmpty, values.allSatisfy({ $0.isFinite && $0 > 0 }), entry.date >= birthDate, entry.date <= Date() else { throw CareDataError.invalidInput(L10n.text("Nhập ít nhất một số đo dương và thời điểm hợp lệ.")) }
    }
    static func vaccination(_ record: VaccinationRecord, birthDate: Date) throws {
        guard !record.vaccineName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              record.vaccineName.count <= 200, record.doseNumber > 0, record.doseNumber <= 1000,
              record.date.timeIntervalSince1970.isFinite, record.date >= birthDate, record.date <= Date(),
              record.nextDoseDate.map({ $0.timeIntervalSince1970.isFinite && $0 > record.date }) ?? true,
              record.reminderDate.map({ date in date.timeIntervalSince1970.isFinite && record.nextDoseDate.map { date < $0 } == true }) ?? true,
              !record.reminderEnabled || (record.nextDoseDate != nil && record.reminderDate != nil) else {
            throw CareDataError.invalidInput(L10n.text("Thông tin tiêm chủng hoặc lịch nhắc không hợp lệ."))
        }
        // Do not reject elapsed reminders: durable offline mutations must remain replayable.
    }
    static func reminder(_ reminder: MedicationReminder) throws {
        guard !reminder.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              (number(reminder.amount) ?? 0) > 0, !reminder.unit.isEmpty,
              !reminder.enabled || reminder.nextDate > Date() else { throw CareDataError.invalidInput(L10n.text("Nhập tên thuốc, lượng dương và mốc nhắc hợp lệ.")) }
    }
}

// Old cloud snapshots and queued proposals predate vaccinations. Keep all old
// required fields strict; only the new collection has a missing-key default.
extension BabyData {
    nonisolated enum CodingKeys: String, CodingKey {
        case profile, activities, measurements, medicationReminders, isTrackingIllness
        case illnessTitle, illnessStartDate, sleepStartDate, vaccinations
    }
    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        profile = try c.decode(BabyProfile.self, forKey: .profile)
        activities = try c.decode([CareActivity].self, forKey: .activities)
        measurements = try c.decode([BodyMeasurement].self, forKey: .measurements)
        medicationReminders = try c.decode([MedicationReminder].self, forKey: .medicationReminders)
        isTrackingIllness = try c.decode(Bool.self, forKey: .isTrackingIllness)
        illnessTitle = try c.decode(String.self, forKey: .illnessTitle)
        illnessStartDate = try c.decode(Date.self, forKey: .illnessStartDate)
        sleepStartDate = try c.decodeIfPresent(Date.self, forKey: .sleepStartDate)
        vaccinations = c.contains(.vaccinations) ? try c.decode([VaccinationRecord].self, forKey: .vaccinations) : []
    }
}
