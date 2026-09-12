import Foundation

/// Deliberately matches complete statements, never a keyword inside a longer sentence.
nonisolated struct VoiceActivityParser {
    struct ParseError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    func parse(_ transcript: String, now: Date = Date(), calendar: Calendar = .current) throws -> [CareActivity] {
        let separated = transcript.replacingOccurrences(of: "(?i)\\s+(?:rồi|sau đó|tiếp đó|và)\\s+(?=(?:bé|con|em bé|uống|bú|ngủ|tắm|thay|đo|nhiệt độ)\\b)", with: ";", options: .regularExpression)
            .replacingOccurrences(of: "[.!]\\s+(?=[\\p{L}])", with: ";", options: .regularExpression)
        let clauses = separated.components(separatedBy: CharacterSet(charactersIn: ";\n"))
        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, clauses.count <= 10 else {
            throw ParseError(message: L10n.text("Chưa nghe rõ nội dung hoặc câu quá dài. Hãy nói lại từng hoạt động."))
        }
        return try clauses.enumerated().map { index, raw in
            do { return try parseOne(raw, now: now, calendar: calendar) }
            catch { throw ParseError(message: L10n.text("Câu {0}: {1} Chưa lưu hoạt động nào.", "\(index + 1)", "\(error.localizedDescription)")) }
        }
    }

    private func captures(_ pattern: String, _ text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: "^(?:" + pattern + ")$"),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        return (1..<match.numberOfRanges).map { Range(match.range(at: $0), in: text).map { String(text[$0]) } ?? "" }
    }

    private func parseOne(_ raw: String, now: Date, calendar: Calendar) throws -> CareActivity {
        let lowered = raw.lowercased()
        if lowered.range(of: "\\b(không(?! (?:phẩy|trăm))|chưa|đừng|sẽ|nên|cần|hoặc|hay là|định)\\b", options: .regularExpression) != nil {
            throw ParseError(message: L10n.text("Câu có phủ định, dự định hoặc lựa chọn chưa rõ. Hãy nói hoạt động đã xảy ra."))
        }
        var text = VoicePhraseNormalizer.normalize(raw)
        if text.hasSuffix(".") { text.removeLast() }
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        for prefix in ["ghi nhận ", "ghi "] where text.hasPrefix(prefix) { text.removeFirst(prefix.count) }
        if text.hasPrefix("bé ") { text.removeFirst(3) }
        if text.hasPrefix("đã ") { text.removeFirst(3) }
        text = text.replacingOccurrences(of: "mililít", with: "ml").replacingOccurrences(of: "mi li lít", with: "ml")
        text = text.replacingOccurrences(of: " phẩy ", with: ",")
        var date = now
        var explicitTime = false
        if let parts = captures("(.+) (?:cách đây|cách) ([0-9]+) (phút|giờ)", text) {
            guard let amount = Double(parts[1]), amount > 0, amount <= 1440 else { throw invalidTime() }
            date = now.addingTimeInterval(-amount * (parts[2] == "giờ" ? 3600 : 60))
            text = parts[0]; explicitTime = true
        } else if let parts = captures("(.+) lúc ([0-9]{1,2})(?::([0-9]{2})| giờ(?: ([0-9]{1,2})(?: phút)?)?)(?: (sáng|trưa|chiều|tối))?(?: (hôm nay|hôm qua))?", text) {
            guard var hour = Int(parts[1]), hour <= 23 else { throw invalidTime() }
            let minute = Int(parts[2].isEmpty ? parts[3] : parts[2]) ?? 0
            guard minute <= 59 else { throw invalidTime() }
            let period = parts[4]
            if !period.isEmpty {
                guard (1...12).contains(hour) else { throw invalidTime() }
                if period == "trưa" {
                    guard [11, 12, 1].contains(hour) else { throw invalidTime() }
                    if hour == 1 { hour = 13 }
                } else if ["chiều", "tối"].contains(period) {
                    guard hour != 12 || period == "chiều" else { throw invalidTime() }
                    if hour < 12 { hour += 12 }
                } else if hour == 12 {
                    // “12 giờ sáng” is ambiguous; require 00:00 or 12:00.
                    throw invalidTime()
                }
            }
            guard let day = parts[5] == "hôm qua" ? calendar.date(byAdding: .day, value: -1, to: now) : now else { throw invalidTime() }
            var components = calendar.dateComponents([.year, .month, .day], from: day)
            components.hour = hour; components.minute = minute; components.second = 0
            guard let value = calendar.date(from: components), value <= now else { throw invalidTime() }
            date = value; text = parts[0]; explicitTime = true
        } else if text.hasSuffix(" bây giờ") {
            text.removeLast(" bây giờ".count)
        }
        let number = "([0-9]+(?:[,.][0-9]+)?)"
        var entry: CareActivity?
        if let p = captures("uống " + number + " ml (sữa|nước)", text) {
            entry = CareActivity(kind: p[1] == "sữa" ? .milk : .water, value: p[0], unit: "ml", detail: p[1] == "sữa" ? "Chưa rõ loại sữa" : "")
        } else if let p = captures("uống (sữa|nước) " + number + " ml", text) {
            entry = CareActivity(kind: p[0] == "sữa" ? .milk : .water, value: p[1], unit: "ml", detail: p[0] == "sữa" ? "Chưa rõ loại sữa" : "")
        } else if let p = captures("bú mẹ " + number + " phút", text) {
            entry = CareActivity(kind: .milk, value: p[0], unit: "phút", detail: "Bú mẹ")
        } else if let p = captures("(?:đo nhiệt độ|nhiệt độ) " + number + " (?:độ(?: c)?|°c)(?: (?:ở |tại )?(nách|tai|trán))?", text) {
            entry = CareActivity(kind: .temperature, value: p[0], unit: "°C", detail: p[1].isEmpty ? "Chưa rõ" : p[1].capitalized)
        } else if let p = captures("uống thuốc ([\\p{L}][\\p{L}0-9 -]*?) " + number + " (ml|mg|viên|giọt)", text) {
            // Reject conjunctions, negation and instructions inside a putative drug name.
            let blocked = ["không", "chưa", "đừng", "sẽ", "nên", "cần", "hay", "hoặc", "và", "rồi", "khoảng"]
            guard !p[0].split(separator: " ").contains(where: { blocked.contains(String($0)) }) else { throw unrecognized() }
            entry = CareActivity(kind: .medicine, value: p[1], unit: p[2], detail: p[0])
        } else if let p = captures("ngủ " + number + " (phút|giờ)(?: ([0-9]+)(?: phút)?)?", text) {
            guard let value = Double(p[0].replacingOccurrences(of: ",", with: ".")) else { throw unrecognized() }
            let extra = Double(p[2]) ?? 0
            guard p[2].isEmpty || (p[1] == "giờ" && extra < 60) else { throw unrecognized() }
            let minutes = value * (p[1] == "giờ" ? 60 : 1) + extra
            guard minutes > 0, minutes <= 1440 else { throw unrecognized() }
            if explicitTime && date.addingTimeInterval(minutes * 60) > now.addingTimeInterval(1) { throw invalidTime() }
            entry = CareActivity(kind: .sleep, value: String(minutes), unit: "phút",
                                 detail: explicitTime ? "" : CareActivity.recordedSleepDetail)
        } else if captures("(?:tắm|tắm xong)", text) != nil {
            entry = CareActivity(kind: .bath, value: "Đã ghi nhận")
        } else if let p = captures("thay (?:tã|bỉm)(?: (ướt|bẩn|khô))?", text) {
            entry = CareActivity(kind: .diaper, value: p[0].isEmpty ? "Đã ghi nhận" : p[0])
        }
        guard var result = entry else {
            if text.contains("sữa") || text.contains("nước") || text.contains("bú") {
                throw ParseError(message: L10n.text("Đã nghe hoạt động ăn uống nhưng chưa rõ lượng hoặc đơn vị. Bạn có thể nói: Uống sữa một trăm hai mươi ml, hoặc bú mẹ mười phút."))
            }
            if text.contains("thuốc") { throw ParseError(message: L10n.text("Cần tên thuốc, lượng thực tế và đơn vị, ví dụ ml hoặc viên. Không tự suy ra liều thuốc.")) }
            if text.contains("ngủ") { throw ParseError(message: L10n.text("Đã nghe hoạt động ngủ. Hãy bổ sung thời lượng, chẳng hạn ngủ nửa tiếng hoặc ngủ một giờ rưỡi.")) }
            throw unrecognized()
        }
        if let value = result.numericValue {
            guard value.isFinite, value > 0 else { throw unrecognized() }
        }
        result.date = date
        result.note = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return result
    }

    private func invalidTime() -> ParseError {
        ParseError(message: L10n.text("Thời điểm không hợp lệ hoặc nằm ở tương lai. Hãy nói rõ giờ và ngày; với giấc ngủ, giờ là lúc bắt đầu."))
    }
    private func unrecognized() -> ParseError {
        ParseError(message: L10n.text("Không xác định đủ hoạt động, số lượng và đơn vị. Ví dụ: Bé uống 120 ml sữa; Bé đo nhiệt độ 37,5 độ; Bé thay tã."))
    }
}
