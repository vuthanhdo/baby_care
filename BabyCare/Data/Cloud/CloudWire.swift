import Foundation

nonisolated enum CloudValue: Codable, Sendable, Equatable {
    case string(String), number(Double), bool(Bool), null
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let value = try? c.decode(Bool.self) { self = .bool(value) }
        else if let value = try? c.decode(Double.self) { self = .number(value) }
        else { self = .string(try c.decode(String.self)) }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let v): try c.encode(v)
        case .number(let v): try c.encode(v)
        case .bool(let v): try c.encode(v)
        case .null: try c.encodeNil()
        }
    }
    var text: String? { if case .string(let v) = self { v } else { nil } }
    var number: Double? { if case .number(let v) = self { v } else { nil } }
    var flag: Bool { self == .bool(true) }
    static func id(_ id: UUID) -> Self { .string(id.uuidString.lowercased()) }
    static func date(_ date: Date?) -> Self {
        guard let date else { return .null }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return .string(formatter.string(from: date))
    }
}

typealias CloudRow = [String: CloudValue]
nonisolated struct CloudChange: Codable, Sendable, Equatable {
    var entity: String
    var id: UUID
    var baby_id: UUID?
    var expected_version: Int
    var data: CloudRow
    var deleted: Bool = false
}
nonisolated struct CloudEnvelope: Codable, Sendable {
    var p_operation_id = UUID()
    var p_family_id: UUID
    var p_changes: [CloudChange]
    var p_api_version = 1
}
nonisolated struct CloudReceipt: Codable, Sendable {
    struct Record: Codable, Sendable { var entity: String; var id: UUID; var version: Int }
    var operation_id: UUID
    var revision: Int
    var records: [Record]
}
nonisolated struct CloudSnapshot: Codable, Sendable {
    var database = CareDatabase()
    var versions: [String: Int] = [:]
    var revision = 0
    var mediaAssets: [CloudMediaAsset]?
    var supportsVaccinations: Bool? = true
    static func key(_ entity: String, _ id: UUID) -> String { "\(entity):\(id.uuidString.lowercased())" }
}

/// Explicit SQL column mapping: domain Codable never becomes the server contract.
nonisolated enum CloudMapping {
    static let entities = ["babies", "care_activities", "body_measurements", "baby_care_states", "medication_reminders", "media_assets", "vaccinations"]
    static func rows(_ database: CareDatabase) -> [String: [UUID: CloudRow]] {
        var result: [String: [UUID: CloudRow]] = [:]
        for b in database.babies {
            let p = b.profile
            result["babies", default: [:]][p.id] = ["name": .string(p.name), "birth_date": .date(p.birthDate), "gender": .string(p.gender.rawValue), "blood_type": .string(p.bloodType), "allergies": .string(p.allergies), "health_notes": .string(p.healthNotes)]
            result["baby_care_states", default: [:]][p.id] = ["is_tracking_illness": .bool(b.isTrackingIllness), "illness_title": .string(b.illnessTitle), "illness_start_date": .date(b.isTrackingIllness ? b.illnessStartDate : nil), "sleep_start_date": .date(b.sleepStartDate)]
            for a in b.activities {
                result["care_activities", default: [:]][a.id] = ["kind": .string(a.kind.rawValue), "occurred_at": .date(a.date), "value": .string(a.value), "unit": .string(a.unit), "note": .string(a.note), "detail": .string(a.detail)]
            }
            for m in b.measurements {
                result["body_measurements", default: [:]][m.id] = ["measured_at": .date(m.date), "weight": m.weight.map(CloudValue.number) ?? .null, "height": m.height.map(CloudValue.number) ?? .null, "head_circumference": m.headCircumference.map(CloudValue.number) ?? .null, "method": .string(m.method), "notes": .string(m.notes)]
            }
            for v in b.vaccinations {
                result["vaccinations", default: [:]][v.id] = ["vaccine_name": .string(v.vaccineName), "vaccinated_at": .date(v.date), "dose_number": .number(Double(v.doseNumber)), "next_dose_date": .date(v.nextDoseDate), "clinic": .string(v.clinic), "notes": .string(v.notes), "reminder_enabled": .bool(v.reminderEnabled), "reminder_date": .date(v.reminderDate)]
            }
            for r in b.medicationReminders {
                result["medication_reminders", default: [:]][r.id] = ["name": .string(r.name), "amount": .number(CareValidation.number(r.amount) ?? 0), "unit": .string(r.unit), "next_date": .date(r.nextDate), "note": .string(r.note), "enabled": .bool(r.enabled), "episode_only": .bool(r.episodeOnly)]
            }
        }
        return result
    }

    static func changes(from old: CloudSnapshot, to next: CareDatabase) throws -> [CloudChange] {
        let before = rows(old.database), after = rows(next)
        var changes: [CloudChange] = []
        for entity in entities {
            let a = before[entity] ?? [:], b = after[entity] ?? [:]
            for id in Set(a.keys).union(b.keys).sorted(by: { $0.uuidString < $1.uuidString }) where a[id] != b[id] {
                let babyID = (next.babies + old.database.babies).first { baby in
                    switch entity {
                    case "babies", "baby_care_states": baby.profile.id == id
                    case "care_activities": baby.activities.contains { $0.id == id }
                    case "body_measurements": baby.measurements.contains { $0.id == id }
                    case "vaccinations": baby.vaccinations.contains { $0.id == id }
                    case "medication_reminders": baby.medicationReminders.contains { $0.id == id }
                    default: false
                    }
                }?.profile.id
                changes.append(CloudChange(entity: entity, id: id, baby_id: entity == "babies" ? nil : babyID,
                    expected_version: old.versions[CloudSnapshot.key(entity, id)] ?? 0, data: b[id] ?? [:], deleted: b[id] == nil))
            }
        }
        guard changes.count <= 100 else { throw CareDataError.invalidInput(L10n.text("Thao tác vượt quá 100 bản ghi. Hãy chia thành các lần lưu nhỏ hơn.")) }
        return changes
    }

    static func decode(_ tables: [String: [CloudRow]], revision: Int, selected: UUID?) throws -> CloudSnapshot {
        func text(_ r: CloudRow, _ k: String) throws -> String {
            guard let v = r[k]?.text else { throw CareDataError.corruptData }; return v
        }
        func id(_ r: CloudRow, _ k: String = "id") throws -> UUID {
            guard let v = UUID(uuidString: try text(r,k)) else { throw CareDataError.corruptData }; return v
        }
        func date(_ r: CloudRow, _ k: String) throws -> Date {
            let value = try text(r,k)
            let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = formatter.date(from: value) { return d }
            formatter.formatOptions = [.withInternetDateTime]
            guard let d = formatter.date(from: value) else { throw CareDataError.corruptData }; return d
        }
        var snapshot = CloudSnapshot(revision: revision)
        var live: [String: [CloudRow]] = [:]
        for (entity, rows) in tables {
            for r in rows {
                guard let rawVersion = r["version"]?.number, let version = Int(exactly: rawVersion), version >= 1 else { throw CareDataError.corruptData }
                let key = CloudSnapshot.key(entity, try id(r))
                guard snapshot.versions[key] == nil else { throw CareDataError.corruptData }
                snapshot.versions[key] = version
                if r["deleted_at"] == .null { live[entity, default: []].append(r) }
            }
        }
        snapshot.mediaAssets = try (live["media_assets"] ?? []).map { row in
            guard let purpose = CloudMediaPurpose(rawValue: try text(row, "purpose")),
                  let mimeType = row["mime_type"]?.text,
                  let objectPath = row["object_path"]?.text,
                  let rawByteCount = row["byte_count"]?.number, let byteCount = Int(exactly: rawByteCount),
                  (1...CloudMediaPlan.maximumBytes).contains(byteCount),
                  let rawVersion = row["version"]?.number, let version = Int(exactly: rawVersion) else { throw CareDataError.corruptData }
            let activityID = row["activity_id"] == .null ? nil : try id(row, "activity_id")
            return CloudMediaAsset(id: try id(row), babyID: try id(row, "baby_id"), activityID: activityID,
                                   purpose: purpose, objectPath: objectPath, mimeType: mimeType,
                                   byteCount: byteCount, version: version, status: try text(row, "status"))
        }
        for r in live["babies"] ?? [] {
            let babyID = try id(r)
            guard let gender = BabyGender(rawValue: try text(r,"gender")) else { throw CareDataError.corruptData }
            let profile = try BabyProfile(id: babyID, name: text(r,"name"), birthDate: date(r,"birth_date"), gender: gender, bloodType: text(r,"blood_type"), allergies: text(r,"allergies"), healthNotes: text(r,"health_notes"))
            var baby = BabyData(profile: profile)
            for a in live["care_activities"] ?? [] where try id(a,"baby_id") == babyID {
                guard let kind = ActivityKind(rawValue: try text(a,"kind")) else { throw CareDataError.corruptData }
                baby.activities.append(try CareActivity(id: id(a), kind: kind, date: date(a,"occurred_at"), value: text(a,"value"), unit: text(a,"unit"), note: text(a,"note"), detail: text(a,"detail")))
            }
            for m in live["body_measurements"] ?? [] where try id(m,"baby_id") == babyID {
                baby.measurements.append(try BodyMeasurement(id: id(m), date: date(m,"measured_at"), weight: m["weight"]?.number, height: m["height"]?.number, headCircumference: m["head_circumference"]?.number, method: text(m,"method"), notes: text(m,"notes")))
            }
            for v in live["vaccinations"] ?? [] where try id(v,"baby_id") == babyID {
                guard let raw = v["dose_number"]?.number, let dose = Int(exactly: raw),
                      let enabledValue = v["reminder_enabled"], case .bool(let enabled) = enabledValue else { throw CareDataError.corruptData }
                let record = try VaccinationRecord(id: id(v), vaccineName: text(v,"vaccine_name"), date: date(v,"vaccinated_at"), doseNumber: dose,
                    nextDoseDate: v["next_dose_date"] == .null ? nil : date(v,"next_dose_date"), clinic: text(v,"clinic"), notes: text(v,"notes"),
                    reminderEnabled: enabled, reminderDate: v["reminder_date"] == .null ? nil : date(v,"reminder_date"))
                try CareValidation.vaccination(record, birthDate: profile.birthDate)
                baby.vaccinations.append(record)
            }
            baby.vaccinations.sort { $0.date > $1.date }
            for m in live["medication_reminders"] ?? [] where try id(m,"baby_id") == babyID {
                guard let amount = m["amount"]?.number else { throw CareDataError.corruptData }
                baby.medicationReminders.append(try MedicationReminder(id: id(m), name: text(m,"name"), amount: String(amount), unit: text(m,"unit"), nextDate: date(m,"next_date"), note: text(m,"note"), enabled: m["enabled"]?.flag ?? false, episodeOnly: m["episode_only"]?.flag ?? false))
            }
            if let s = try live["baby_care_states"]?.first(where: { try id($0,"baby_id") == babyID }) {
                baby.isTrackingIllness = s["is_tracking_illness"]?.flag ?? false
                baby.illnessTitle = try text(s,"illness_title")
                baby.illnessStartDate = s["illness_start_date"] == .null ? profile.birthDate : try date(s,"illness_start_date")
                baby.sleepStartDate = s["sleep_start_date"] == .null ? nil : try date(s,"sleep_start_date")
            }
            baby.activities.sort { $0.date > $1.date }; baby.measurements.sort { $0.date > $1.date }
            snapshot.database.babies.append(baby)
        }
        snapshot.database.babies.sort { $0.profile.id.uuidString < $1.profile.id.uuidString }
        snapshot.database.selectedBabyID = snapshot.database.babies.contains { $0.profile.id == selected } ? selected : snapshot.database.babies.first?.profile.id
        snapshot.database.hasOnboarded = !snapshot.database.babies.isEmpty
        return snapshot
    }
}
