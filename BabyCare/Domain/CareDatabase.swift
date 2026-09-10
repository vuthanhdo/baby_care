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
}

nonisolated struct CareDatabase: Codable, Sendable, Equatable {
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
            } else { next.babies.append(BabyData(profile: profile)) }
            next.selectedBabyID = profile.id
            next.hasOnboarded = true
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
                let firstEntry = (baby.activities.map(\.date) + baby.measurements.map(\.date)).min() ?? Date()
                guard profile.birthDate <= firstEntry else { throw CareDataError.invalidInput("Ngày sinh không được sau dữ liệu đã ghi.") }
                baby.profile = profile
            case .saveActivities(_, let entries, let finishingSleep, let reminderID):
                guard !entries.isEmpty, Set(entries.map(\.id)).count == entries.count else { throw CareDataError.invalidInput("Danh sách hoạt động không hợp lệ.") }
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
            case .startSleep(_, let date):
                guard date <= Date(), baby.sleepStartDate == nil || baby.sleepStartDate == date else { throw CareDataError.invalidInput("Bé đã có giấc ngủ đang diễn ra.") }
                baby.sleepStartDate = date
            case .startIllness(_, let title, let date):
                guard date >= baby.profile.birthDate, date <= Date() else { throw CareDataError.invalidInput("Ngày bắt đầu theo dõi không hợp lệ.") }
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
            case .createBaby, .selectBaby: break
            }
            next.babies[index] = baby
        }
        return next
    }
}

nonisolated enum CareDataMutation: Codable, Sendable, Equatable {
    case createBaby(BabyProfile)
    case updateBaby(BabyProfile)
    case selectBaby(UUID)
    case saveActivities(babyID: UUID, entries: [CareActivity], finishingSleep: Date? = nil, completingReminderID: UUID? = nil)
    case deleteActivity(babyID: UUID, activityID: UUID)
    case saveMeasurement(babyID: UUID, measurement: BodyMeasurement)
    case startSleep(babyID: UUID, date: Date)
    case startIllness(babyID: UUID, title: String, date: Date)
    case endIllness(babyID: UUID)
    case saveReminder(babyID: UUID, reminder: MedicationReminder)
    case deleteReminder(babyID: UUID, reminderID: UUID)

    var babyID: UUID? {
        switch self {
        case .createBaby(let baby), .updateBaby(let baby): baby.id
        case .selectBaby(let id), .endIllness(let id): id
        case .saveActivities(let id, _, _, _), .deleteActivity(let id, _), .saveMeasurement(let id, _),
             .startSleep(let id, _), .startIllness(let id, _, _), .saveReminder(let id, _), .deleteReminder(let id, _): id
        }
    }
}

nonisolated enum CareDataError: Error, LocalizedError, Sendable {
    case babyNotFound, conflict, corruptData, invalidInput(String)
    var errorDescription: String? {
        switch self {
        case .babyNotFound: "Không tìm thấy hồ sơ bé. Hãy tải lại dữ liệu."
        case .conflict: "Dữ liệu đã thay đổi hoặc trùng mã bản ghi. Hãy tải lại trước khi lưu."
        case .corruptData: "Không đọc được dữ liệu đã lưu. Dữ liệu gốc vẫn được giữ."
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
        guard !profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, profile.birthDate <= Date() else { throw CareDataError.invalidInput("Nhập tên và ngày sinh hợp lệ.") }
    }
    static func activity(_ entry: CareActivity) throws {
        guard entry.date <= Date(), !entry.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw CareDataError.invalidInput("Nhập nội dung và thời điểm hợp lệ.") }
        if [.temperature, .medicine, .milk, .water, .sleep].contains(entry.kind) {
            guard let value = number(entry.value), value > 0, !entry.unit.isEmpty else { throw CareDataError.invalidInput("Nhập số dương và đơn vị để lưu.") }
            if entry.kind == .sleep && entry.detail != CareActivity.recordedSleepDetail && entry.date.addingTimeInterval(value * 60) > Date().addingTimeInterval(60) { throw CareDataError.invalidInput("Giấc ngủ không được kết thúc trong tương lai.") }
        }
        if entry.kind == .medicine && entry.detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { throw CareDataError.invalidInput("Nhập tên thuốc đã dùng.") }
        guard entry.attachments.count <= 3 else { throw CareDataError.invalidInput("Mỗi hoạt động tối đa 3 ảnh.") }
    }
    static func measurement(_ entry: BodyMeasurement, birthDate: Date) throws {
        let values = [entry.weight, entry.height, entry.headCircumference].compactMap { $0 }
        guard !values.isEmpty, values.allSatisfy({ $0.isFinite && $0 > 0 }), entry.date >= birthDate, entry.date <= Date() else { throw CareDataError.invalidInput("Nhập ít nhất một số đo dương và thời điểm hợp lệ.") }
    }
    static func reminder(_ reminder: MedicationReminder) throws {
        guard !reminder.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              (number(reminder.amount) ?? 0) > 0, !reminder.unit.isEmpty,
              !reminder.enabled || reminder.nextDate > Date() else { throw CareDataError.invalidInput("Nhập tên thuốc, lượng dương và mốc nhắc hợp lệ.") }
    }
}
