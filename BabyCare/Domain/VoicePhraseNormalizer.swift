import Foundation

/// Normalizes known conversational variants without discarding unknown information.
nonisolated enum VoicePhraseNormalizer {
    static func normalize(_ raw: String) -> String {
        var text = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        for (pattern, replacement) in [
            ("(?:mi li lít|mi-li-lít|mililít|mililit|mi li lít|mi li lit|cc)", "ml"),
            ("mi li gam|miligam", "mg"),
            ("\\b([0-9]{1,2})h([0-9]{2})?\\b", "$1 giờ $2"),
            ("([0-9])(ml|mg|°c|h)\\b", "$1 $2"),
            ("\\b([0-9]{1,2}) h(?: ([0-9]{1,2}))?\\b", "$1 giờ $2"),
            ("nửa (?:tiếng|giờ)", "30 phút"),
            ("tiếng", "giờ")
        ] { text = text.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression) }
        text = normalizeNumbers(text)
        text = text.replacingOccurrences(of: "giờ rưỡi", with: "giờ 30")
        text = text.replacingOccurrences(of: "([0-9]+) phẩy ([0-9]+)", with: "$1,$2", options: .regularExpression)
        text = text.replacingOccurrences(of: "^(?:ghi lại|ghi nhận|lưu lại|ghi|lưu)(?: giúp (?:mình|tôi|em))?\\s+", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "(?: nhé| nha| ạ| rồi)$", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "^(?:(?:mẹ|mình|em|tôi) (?:vừa |đã )?cho (?:bé|con) |(?:bé nhà mình|bé nhà em|em bé|con em|con mình|bé|con) )", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "^(?:vừa mới|vừa|mới|đã) ", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "^(uống|bú|bú mẹ|ngủ)(?: được| hết| xong) ", with: "$1 ", options: .regularExpression)
        text = text.replacingOccurrences(of: "^(uống sữa|uống nước|bú sữa)(?: được| hết) ", with: "$1 ", options: .regularExpression)
        text = text.replacingOccurrences(of: "^bú (?!mẹ)(?:sữa )?", with: "uống sữa ", options: .regularExpression)
        text = text.replacingOccurrences(of: "^(?:đo được|đo thân nhiệt|thân nhiệt|nhiệt độ đo được|nhiệt độ là|đo nhiệt độ được) ", with: "nhiệt độ ", options: .regularExpression)
        text = text.replacingOccurrences(of: "^đo (nách|tai|trán) (?:được )?(.+)$", with: "nhiệt độ $2 ở $1", options: .regularExpression)
        text = text.replacingOccurrences(of: "^thay (tã|bỉm) (?:cho bé|cho con)(?: xong)?$", with: "thay $1", options: .regularExpression)
        text = text.replacingOccurrences(of: "^tắm (?:cho bé|cho con)(?: xong)?$", with: "tắm xong", options: .regularExpression)
        text = text.replacingOccurrences(of: "^ngủ (?:được )?", with: "ngủ ", options: .regularExpression)
        text = text.replacingOccurrences(of: " (?:vào lúc|hồi) ", with: " lúc ", options: .regularExpression)
        text = text.replacingOccurrences(of: " ([0-9]+ (?:phút|giờ)) trước$", with: " cách đây $1", options: .regularExpression)
        text = text.replacingOccurrences(of: "^(.+) (?:vào )?([0-9]{1,2} giờ(?: [0-9]{1,2})? (?:sáng|trưa|chiều|tối)(?: hôm qua| hôm nay)?)$", with: "$1 lúc $2", options: .regularExpression)
        // Move explicit time before the subject to the canonical suffix.
        text = text.replacingOccurrences(of: "^((?:sáng|trưa|chiều|tối)(?: nay| hôm qua)?) (?:lúc )?([0-9]{1,2} giờ(?: [0-9]{1,2})?) (.+)$", with: "$3 lúc $2 $1", options: .regularExpression)
        text = text.replacingOccurrences(of: "(sáng|trưa|chiều|tối) nay$", with: "$1 hôm nay", options: .regularExpression)
        return text.replacingOccurrences(of: " lúc lúc ", with: " lúc ").replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)
    }

    private static let digits: [String: Int] = ["không": 0, "một": 1, "mốt": 1, "hai": 2, "ba": 3, "bốn": 4, "tư": 4, "năm": 5, "lăm": 5, "sáu": 6, "bảy": 7, "tám": 8, "chín": 9]

    private static func integer(_ words: [String]) -> Int? {
        guard !words.isEmpty else { return nil }
        if words.count == 1 { return words[0] == "mười" ? 10 : (digits[words[0]] ?? Int(words[0])) }
        if let index = words.firstIndex(where: { ["nghìn", "ngàn"].contains($0) }) {
            guard let high = integer(Array(words[..<index])), high > 0, high < 1000 else { return nil }
            let tail = Array(words[(index + 1)...])
            guard tail.isEmpty || !tail.contains(where: { ["nghìn", "ngàn"].contains($0) }), let low = tail.isEmpty ? 0 : integer(tail), low < 1000 else { return nil }
            return high * 1000 + low
        }
        if words.count >= 2, words[1] == "trăm", let high = digits[words[0]] {
            var rest = Array(words.dropFirst(2))
            if rest.isEmpty { return high * 100 }
            if ["linh", "lẻ"].contains(rest[0]) { rest.removeFirst() }
            else if rest.count == 1 { return nil } // “một trăm hai” is ambiguous.
            guard let low = integer(rest), low < 100 else { return nil }
            return high * 100 + low
        }
        if words[0] == "mười" {
            if words.count == 1 { return 10 }
            guard words.count == 2, let unit = digits[words[1]] else { return nil }
            return 10 + unit
        }
        if words.count >= 2, words[1] == "mươi", let tens = digits[words[0]], tens >= 2 {
            if words.count == 2 { return tens * 10 }
            guard words.count == 3, let unit = digits[words[2]] else { return nil }
            return tens * 10 + unit
        }
        return nil
    }

    private static func normalizeNumbers(_ text: String) -> String {
        let vocabulary = "không|một|mốt|hai|ba|bốn|tư|năm|lăm|sáu|bảy|tám|chín|mười|mươi|trăm|nghìn|ngàn|linh|lẻ|phẩy|[0-9]+"
        let pattern = "(?<![\\p{L}0-9])((?:" + vocabulary + ")(?: (?:" + vocabulary + "))*)(?= (?:ml|mg|viên|giọt|phút|giờ|độ|°c)\\b)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        var result = text
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() {
            guard let range = Range(match.range(at: 1), in: result) else { continue }
            let words = result[range].split(separator: " ").map(String.init)
            var number: String?
            if let index = words.firstIndex(of: "phẩy") {
                let tail = Array(words[(index + 1)...])
                if let high = integer(Array(words[..<index])), !tail.isEmpty {
                    if tail.allSatisfy({ digits[$0] != nil }) {
                        number = String(high) + "," + tail.compactMap { digits[$0].map(String.init) }.joined()
                    } else if let low = integer(tail) { number = String(high) + "," + String(low) }
                }
            } else if let value = integer(words) { number = String(value) }
            if let number { result.replaceSubrange(range, with: number) }
        }
        return result
    }
}
