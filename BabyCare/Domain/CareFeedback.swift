import Foundation
#if canImport(UIKit)
import UIKit
#endif

nonisolated enum CareFeedbackKind: String, CaseIterable, Identifiable, Sendable {
    case bug, suggestion, other
    var id: Self { self }
    var title: String {
        switch self {
        case .bug: L10n.text("Báo lỗi")
        case .suggestion: L10n.text("Góp ý")
        case .other: L10n.text("Khác")
        }
    }
    var icon: String {
        switch self {
        case .bug: "Stitch_warning_amber"
        case .suggestion: "Stitch_lightbulb"
        case .other: "Stitch_help_outline"
        }
    }
    var prompt: String {
        switch self {
        case .bug: L10n.text("Bạn đang làm gì thì gặp lỗi? App hiện ra thế nào, và bạn mong nó làm gì?")
        case .suggestion: L10n.text("Bạn muốn Bé Khỏe có thêm gì, hoặc làm khác đi thế nào?")
        case .other: L10n.text("Câu hỏi hoặc thông tin bạn muốn gửi cho nhà phát triển.")
        }
    }
}

/// What the parent writes. The id is fixed when the screen opens, so retrying a send never creates a duplicate.
nonisolated struct CareFeedbackDraft: Equatable, Sendable {
    static let maximumLength = 4000
    static let maximumImages = 3
    var id = UUID()
    var kind: CareFeedbackKind = .bug
    var message = ""
    var allowContact = true
    /// JPEG data already normalised by `CareImageProcessor`.
    var images: [Data] = []

    var trimmedMessage: String { message.trimmingCharacters(in: .whitespacesAndNewlines) }
    var canSend: Bool { !trimmedMessage.isEmpty && trimmedMessage.count <= Self.maximumLength && images.count <= Self.maximumImages }
    /// Storage path of each screenshot: the sender's folder, then this feedback.
    func attachmentPaths(userID: UUID) -> [String] {
        images.indices.map { "\(userID.uuidString.lowercased())/\(id.uuidString.lowercased())/\($0).jpg" }
    }
}

/// Technical details sent with the message, shown to the parent before sending; nothing about the baby.
nonisolated struct CareFeedbackContext: Codable, Equatable, Sendable {
    var app_version: String
    var build: String
    var os_version: String
    var device: String
    var language: String
    var storage: String

    @MainActor static func current(storage: String) -> CareFeedbackContext {
        let info = Bundle.main.infoDictionary
        let os = ProcessInfo.processInfo.operatingSystemVersion
        return CareFeedbackContext(app_version: info?["CFBundleShortVersionString"] as? String ?? "?",
                                   build: info?["CFBundleVersion"] as? String ?? "?",
                                   os_version: "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)",
                                   device: machine, language: AppLanguage.current.rawValue, storage: storage)
    }

    /// Hardware model such as iPhone18,3 (the simulator reports the model it simulates).
    private static var machine: String {
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] { return simulated }
        var system = utsname()
        uname(&system)
        return withUnsafeBytes(of: &system.machine) { raw in
            String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
        }
    }

    var summary: String { "Bé Khỏe \(app_version) (\(build)) · iOS \(os_version) · \(device) · \(language) · \(storage)" }
}
