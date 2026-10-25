import Foundation

nonisolated enum GrowthMetric: String, CaseIterable, Identifiable, Sendable {
    case weight = "Cân nặng", height = "Chiều cao"
    var id: Self { self }
    var unit: String { self == .weight ? "kg" : "cm" }
    func value(_ item: BodyMeasurement) -> Double? {
        let value = self == .weight ? item.weight : item.height
        return value.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
    }
}

/// One row of an LMS growth table: Box-Cox power `l`, median `m` and coefficient of variation `s` at an age in months.
nonisolated struct GrowthLMS: Equatable, Sendable {
    let month: Double
    let l: Double
    let m: Double
    let s: Double

    init(_ month: Double, _ l: Double, _ m: Double, _ s: Double) {
        self.month = month
        self.l = l
        self.m = m
        self.s = s
    }

    /// The measurement at a z-score (WHO/CDC LMS method).
    func value(z: Double) -> Double { abs(l) < 1e-9 ? m * exp(s * z) : m * pow(1 + l * s * z, 1 / l) }
    func zScore(_ x: Double) -> Double { abs(l) < 1e-9 ? log(x / m) / s : (pow(x / m, l) - 1) / (l * s) }
}

/// Reference populations a family can compare with. Only the CDC 2000 reference (US public domain) ships:
/// the WHO 2006 tables are licensed for non-commercial use, so `.who` comes back only with WHO's permission
/// (see Tools/Growth/generate.py --with-who).
nonisolated enum GrowthStandard: String, CaseIterable, Identifiable, Sendable {
    case cdc
    static let preferenceKey = "care.growthStandard"
    var id: Self { self }
    var shortTitle: String { "CDC" }
    var title: String { L10n.text("CDC 2000 · tham chiếu của Mỹ") }
}

nonisolated enum GrowthReference {
    /// Lines drawn over the shaded P3–P97 band.
    enum Line: String, CaseIterable, Identifiable, Sendable {
        case p15, p50, p85
        var id: Self { self }
    }

    struct CurvePoint: Identifiable, Equatable, Sendable {
        let age: Double
        let p3: Double, p15: Double, p50: Double, p85: Double, p97: Double
        var id: Double { age }
        func value(_ line: Line) -> Double {
            switch line { case .p15: p15; case .p50: p50; case .p85: p85 }
        }
    }

    /// z-scores of the 3rd, 15th, 85th and 97th percentiles.
    static let z3 = 1.880794, z15 = 1.036433

    static func ageInMonths(from birth: Date, to date: Date) -> Double {
        max(0, date.timeIntervalSince(birth) / 86_400 / 30.4375)
    }

    static func table(_ standard: GrowthStandard, _ metric: GrowthMetric, _ gender: BabyGender) -> [GrowthLMS] {
        switch (standard, metric, gender) {
        case (_, _, .unspecified): []
        case (.cdc, .weight, .boy): GrowthReferenceData.cdcWeightBoys
        case (.cdc, .weight, .girl): GrowthReferenceData.cdcWeightGirls
        case (.cdc, .height, .boy): GrowthReferenceData.cdcHeightBoys
        case (.cdc, .height, .girl): GrowthReferenceData.cdcHeightGirls
        }
    }

    /// Percentile curves up to and including the first table row at or past `age` months.
    static func curves(standard: GrowthStandard, metric: GrowthMetric, gender: BabyGender, through age: Double) -> [CurvePoint] {
        let rows = table(standard, metric, gender)
        let end = rows.firstIndex { $0.month >= age } ?? rows.index(before: rows.endIndex)
        guard !rows.isEmpty else { return [] }
        return rows[...end].map { row in
            CurvePoint(age: row.month, p3: row.value(z: -z3), p15: row.value(z: -z15), p50: row.m, p85: row.value(z: z15), p97: row.value(z: z3))
        }
    }

    /// LMS at an exact age, interpolated between table rows; nil outside the table.
    static func lms(at age: Double, in rows: [GrowthLMS]) -> GrowthLMS? {
        guard let first = rows.first, let last = rows.last, age >= first.month, age <= last.month else { return nil }
        guard let upper = rows.firstIndex(where: { $0.month >= age }) else { return nil }
        let b = rows[upper]
        guard upper > 0, b.month > age else { return b }
        let a = rows[upper - 1], t = (age - a.month) / (b.month - a.month)
        return GrowthLMS(age, a.l + (b.l - a.l) * t, a.m + (b.m - a.m) * t, a.s + (b.s - a.s) * t)
    }

    /// Where a measurement sits in the reference population, 1–99; nil when the standard does not cover the age.
    static func percentile(of value: Double, ageInMonths age: Double, standard: GrowthStandard, metric: GrowthMetric, gender: BabyGender) -> Int? {
        guard value > 0, let lms = lms(at: age, in: table(standard, metric, gender)) else { return nil }
        let z = lms.zScore(value)
        guard z.isFinite else { return nil }
        let percentile = 50 * (1 + erf(z / 2.0.squareRoot()))
        return min(99, max(1, Int(percentile.rounded())))
    }
}
