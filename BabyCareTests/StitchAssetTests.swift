import Testing
import UIKit
@testable import BabyCare

@MainActor struct StitchAssetTests {
    nonisolated static let symbols: [String] = ["accessibility_new", "account_circle", "add", "add_a_photo", "add_circle", "add_circle_outline", "airline_seat_flat", "alarm", "arrow_back_ios_new", "arrow_downward", "arrow_drop_down", "arrow_forward", "arrow_forward_ios", "assignment", "auto_awesome", "auto_stories", "baby_changing_station", "badge", "bar_chart", "bathtub", "bed", "bedtime", "block", "bolt", "cached", "calendar_clock", "calendar_month", "calendar_today", "call", "cancel", "check", "check_circle", "chevron_left", "chevron_right", "child_care", "clinical_notes", "close", "contact_mail", "delete", "delete_outline", "device_thermostat", "done", "edit", "edit_calendar", "edit_note", "expand_more", "face", "face_6", "favorite", "fingerprint", "flag", "format_list_bulleted", "format_quote", "format_size", "front_hand", "healing", "health_and_safety", "hearing", "help_outline", "history", "hourglass_top", "ios_share", "lightbulb", "link", "local_hospital", "lock", "manage_search", "medical_information", "medical_services", "medication", "medication_liquid", "menu_book", "mic", "monitor_weight", "more_horiz", "nightlight_round", "notifications", "notifications_active", "nutrition", "open_in_new", "pace", "person", "photo_camera", "picture_as_pdf", "play_arrow", "prescriptions", "print", "qr_code_2", "query_stats", "radio_button_unchecked", "ramen_dining", "remove", "restaurant", "scale", "schedule", "sd_storage", "search", "sensors", "settings", "share", "share_location", "shield", "show_chart", "sick", "spa", "stethoscope", "straighten", "sync", "task_alt", "thermostat", "touch_app", "trending_down", "trending_up", "tune", "update", "verified", "verified_user", "visibility", "visibility_off", "warning", "warning_amber", "water_bottle", "water_drop"]

    @Test(arguments: symbols)
    func stitchIconIsBundledAndPaintsVisiblePixels(_ symbol: String) throws {
        let image = try #require(UIImage(named: "Stitch_" + symbol))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let rendered = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 32), format: format).image { _ in
            image.withTintColor(.black, renderingMode: .alwaysOriginal).draw(in: CGRect(x: 0, y: 0, width: 32, height: 32))
        }
        let cg = try #require(rendered.cgImage)
        var pixels = [UInt8](repeating: 0, count: 32 * 32 * 4)
        let painted = pixels.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(data: bytes.baseAddress, width: 32, height: 32,
                bitsPerComponent: 8, bytesPerRow: 128, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(cg, in: CGRect(x: 0, y: 0, width: 32, height: 32))
            return stride(from: 3, to: bytes.count, by: 4).contains { bytes[$0] > 0 }
        }
        #expect(painted, "Icon renders blank: \(symbol)")
    }

    @Test func everyActivityHasItsOwnBundledIcon() throws {
        let names = ActivityKind.allCases.map(\.assetName)
        #expect(Set(names).count == ActivityKind.allCases.count)
        for name in names { #expect(UIImage(named: name) != nil) }
    }
}
