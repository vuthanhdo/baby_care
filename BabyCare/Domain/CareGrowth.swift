import Foundation

/// The app's App Store page, with a campaign token so App Store Connect counts installs per channel
/// (tokens in AppStore/CAMPAIGNS.md).
nonisolated enum CareAppStore {
    static let appID = "6824822487"
    static let providerToken = "129617549"

    static func link(campaign: String) -> URL {
        var components = URLComponents(string: "https://apps.apple.com/app/apple-store/id\(appID)")!
        components.queryItems = [.init(name: "pt", value: providerToken), .init(name: "ct", value: campaign), .init(name: "mt", value: "8")]
        return components.url!
    }
}

/// When to ask for an App Store rating: only parents who have used the app for a while, right after something
/// went well, and at most once per app version. iOS still decides whether the prompt shows (three times a year at most).
nonisolated struct CareReviewPolicy: Codable, Equatable, Sendable {
    enum Moment: Sendable { case illnessEnded, reportShared }

    static let minimumEntries = 15
    static let minimumDays = 3

    var savedEntries = 0
    var activeDays = 0
    var lastActiveDay: Date?
    var askedVersion: String?

    /// Counts logged entries and the distinct days they were logged on.
    mutating func recordSaved(entries: Int, at date: Date, calendar: Calendar = .current) {
        guard entries > 0 else { return }
        savedEntries += entries
        let day = calendar.startOfDay(for: date)
        if lastActiveDay != day { activeDays += 1; lastActiveDay = day }
    }

    /// True once per version when the parent is engaged enough; marks the version as asked.
    mutating func shouldAsk(after moment: Moment, version: String) -> Bool {
        guard savedEntries >= Self.minimumEntries, activeDays >= Self.minimumDays, askedVersion != version else { return false }
        askedVersion = version
        return true
    }
}

/// Keeps `CareReviewPolicy` in UserDefaults for the app.
@MainActor final class CareReviewTracker {
    static let key = "care.review.policy"
    private let defaults: UserDefaults
    private let version: String
    private(set) var policy: CareReviewPolicy

    init(defaults: UserDefaults = .standard,
         version: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0") {
        self.defaults = defaults
        self.version = version
        policy = defaults.data(forKey: Self.key).flatMap { try? JSONDecoder().decode(CareReviewPolicy.self, from: $0) } ?? CareReviewPolicy()
    }

    /// Records a committed change and tells whether it is a good moment to ask.
    func didCommit(_ mutation: CareDataMutation, at date: Date = Date()) -> Bool {
        switch mutation {
        case .saveActivities(_, let entries, _, _):
            policy.recordSaved(entries: entries.count, at: date)
            save()
            return false
        case .endIllness:
            return ask(after: .illnessEnded)
        default:
            return false
        }
    }

    func ask(after moment: CareReviewPolicy.Moment) -> Bool {
        let ask = policy.shouldAsk(after: moment, version: version)
        save()
        return ask
    }

    private func save() {
        if let data = try? JSONEncoder().encode(policy) { defaults.set(data, forKey: Self.key) }
    }
}
