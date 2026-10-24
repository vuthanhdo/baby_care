import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Home card: outdoor weather where the parent is and what to dress the baby in to go out.
struct WeatherCardView: View {
    let weather: WeatherViewModel
    let baby: BabyProfile
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    @Environment(\.locale) private var appLocale

    var body: some View {
        let _ = appLocale
        CareCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.text("THỜI TIẾT & TRANG PHỤC")).font(CareFont.caption.weight(.semibold)).foregroundStyle(CareTheme.secondary)
                switch weather.phase {
                case .loaded(let current): loaded(current)
                case .loading:
                    HStack(spacing: 10) { ProgressView(); Text(L10n.text("Đang lấy thời tiết…")).font(CareFont.subheadline) }
                        .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
                case .needsPermission:
                    prompt(L10n.text("Xem thời tiết nơi bạn ở và gợi ý trang phục cho bé khi ra ngoài."),
                           button: L10n.text("Xem thời tiết")) { Task { await weather.enable() } }
                case .denied:
                    prompt(L10n.text("Bé Khỏe cần quyền vị trí để lấy thời tiết. Bạn có thể bật trong Cài đặt."),
                           button: L10n.text("Mở Cài đặt")) {
                        #if canImport(UIKit)
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        #endif
                    }
                case .failed:
                    prompt(L10n.text("Chưa lấy được thời tiết. Kiểm tra mạng rồi thử lại."),
                           button: L10n.text("Thử lại")) { Task { await weather.enable() } }
                    if let failure = weather.failure {
                        Text(failure).font(CareFont.caption2).foregroundStyle(CareTheme.secondary).textSelection(.enabled)
                    }
                }
            }
        }
        .accessibilityIdentifier("weather.card")
        .task { await weather.refreshIfNeeded() }
    }

    @ViewBuilder private func loaded(_ current: CareWeather) -> some View {
        HStack(alignment: .center, spacing: 14) {
            // A sky tint behind the symbol keeps its white clouds visible on the white card.
            Image(systemName: current.symbolName).symbolRenderingMode(.multicolor).font(.system(size: 34))
                .frame(width: 60, height: 60).background(CareTheme.feedingBackground, in: .circle).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(degrees(current.temperature)).font(CareFont.largeTitle.bold()).monospacedDigit()
                Text(current.condition.title).font(CareFont.subheadline.weight(.semibold))
                Text(details(current)).font(CareFont.caption).foregroundStyle(CareTheme.secondary)
            }
            Spacer(minLength: 0)
        }.accessibilityElement(children: .combine)
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.text("Gợi ý trang phục khi ra ngoài")).font(CareFont.subheadline.weight(.semibold))
            let months = Calendar.current.dateComponents([.month], from: baby.birthDate, to: Date()).month ?? 0
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 8)], alignment: .leading, spacing: 10) {
                ForEach(OutfitAdvice.items(for: current, ageInMonths: months), id: \.self) { item in
                    VStack(spacing: 4) {
                        Text(item.icon).font(.system(size: 30)).frame(width: 56, height: 56)
                            .background(CareTheme.accent.opacity(0.08), in: .circle)
                        Text(L10n.text(item.label)).font(CareFont.caption2.weight(.semibold)).foregroundStyle(CareTheme.secondary)
                            .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.85)
                    }.frame(maxWidth: .infinity).accessibilityElement(children: .ignore).accessibilityLabel(L10n.text(item.label))
                }
            }.accessibilityIdentifier("weather.outfit")
        }
        attributionRow
    }

    @ViewBuilder private var attributionRow: some View {
        if weather.isSample {
            Text(L10n.text("Thời tiết mẫu")).font(CareFont.caption2).foregroundStyle(CareTheme.secondary)
        } else if let attribution = weather.attribution {
            HStack(spacing: 8) {
                AsyncImage(url: colorScheme == .dark ? attribution.darkMark : attribution.lightMark) { image in
                    image.resizable().scaledToFit()
                } placeholder: { Text(" Weather").font(CareFont.caption2) }
                    .frame(height: 12).accessibilityLabel("Apple Weather")
                Link(L10n.text("Nguồn dữ liệu"), destination: attribution.legalPage).font(CareFont.caption2)
            }
        }
    }

    private func prompt(_ text: String, button: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "cloud.sun").font(.title2).foregroundStyle(CareTheme.accent).accessibilityHidden(true)
                Text(text).font(CareFont.subheadline).foregroundStyle(CareTheme.secondary)
            }
            Button(button, action: action).font(CareFont.subheadline.weight(.semibold)).frame(minHeight: 44)
                .accessibilityIdentifier("weather.action")
        }
    }

    private func degrees(_ value: Double) -> String { "\(Int(value.rounded()))°C" }
    private func details(_ current: CareWeather) -> String {
        var parts = [L10n.text("Cảm giác như {0}", degrees(current.apparentTemperature))]
        if let high = current.high, let low = current.low {
            parts.append(L10n.text("Cao {0} · Thấp {1}", "\(Int(high.rounded()))°", "\(Int(low.rounded()))°"))
        }
        return parts.joined(separator: " · ")
    }
}
