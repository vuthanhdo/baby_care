import SwiftUI

enum CareTab: Hashable { case quick, diary, statistics }

struct ContentView: View {
    @Environment(BabyCareViewModel.self) private var viewModel
    @Environment(\.dynamicTypeSize) private var systemTextSize
    @AppStorage("care.textSize") private var textSize = "system"
    @State private var selectedTab: CareTab = .quick

    @Environment(\.locale) private var appLocale
    var body: some View {
        let _ = appLocale
        Group {
            if viewModel.state.phase == .idle || viewModel.state.phase == .loading {
                CareSplashView()
            } else if viewModel.state.phase == .failed {
                ContentUnavailableView {
                    Label(L10n.text("Không đọc được dữ liệu"), systemImage: "externaldrive.badge.exclamationmark")
                } description: { Text(viewModel.state.error ?? L10n.text("Hãy thử lại.")) }
                actions: { Button(L10n.text("Thử lại")) { Task { await viewModel.send(.load) } } }
            } else if viewModel.hasOnboarded {
                TabView(selection: $selectedTab) {
                    Tab(value: .quick) {
                        NavigationStack { QuickLogView(selectedTab: $selectedTab).careTabs($selectedTab) }
                    } label: { Label(L10n.text("Ghi nhanh"), systemImage: "bolt") }
                    Tab(value: .diary) {
                        NavigationStack { DiaryView().careTabs($selectedTab) }
                    } label: { Label(L10n.text("Nhật ký"), systemImage: "book.pages") }
                    Tab(value: .statistics) {
                        NavigationStack {
                            StatisticsView()
                                .safeAreaInset(edge: .top, spacing: 0) { CareBabyHeaderView() }
                                .careTabs($selectedTab)
                        }
                    } label: { Label(L10n.text("Thống kê"), systemImage: "chart.bar") }
                }
                .toolbar(.hidden, for: .tabBar)
                .id(viewModel.baby.id)
                .onChange(of: viewModel.baby.id) { _, _ in selectedTab = .quick }
            } else {
                NavigationStack { OnboardingView() }
            }
        }
        .font(CareFont.body)
        .disabled(viewModel.state.isSaving)
//        .safeAreaInset(edge: .bottom) {
//            if let message = viewModel.state.storage.message {
//                HStack {
//                    Text(message).font(CareFont.caption)
//                    Spacer()
//                    Button("Tải lại") { Task { await viewModel.send(.load) } }.font(CareFont.caption)
//                }.padding(8).background(.bar)
//            }
//        }
        .task { if viewModel.state.phase == .idle { await viewModel.send(.load) } }
        .alert(L10n.text("Chưa hoàn tất thao tác"), isPresented: Binding(
            get: { viewModel.state.phase == .ready && viewModel.state.error != nil },
            set: { if !$0 { Task { await viewModel.send(.dismissError) } } }
        )) {
            Button(L10n.text("Đóng"), role: .cancel) { Task { await viewModel.send(.dismissError) } }
        } message: { Text(viewModel.state.error ?? L10n.text("Hãy thử lại.")) }
        .dynamicTypeSize(textSize == "largest" ? .accessibility1 : textSize == "large" ? .xxxLarge : systemTextSize)
        .preferredColorScheme(.light)
        .careToastBanner()
        // Announce once here; sheets attach their own banner but must not repeat the announcement.
        .onChange(of: viewModel.toast) { _, toast in
            if let toast { AccessibilityNotification.Announcement(toast).post() }
        }
    }
}
#Preview { ContentView().environment(BabyCareViewModel.preview()) }

extension View {
    /// Attaches the app tabs to a tab root: a bottom bar on phones and the folded iPhone Duo, a leading rail when the
    /// window is wide (open Duo, iPad landscape) so no tab sits on the hinge and the content keeps its height.
    /// Each root owns its inset so pushed screens hide the tabs.
    func careTabs(_ selection: Binding<CareTab>) -> some View { modifier(CareTabsInset(selection: selection)) }
}

private struct CareTabsInset: ViewModifier {
    @Binding var selection: CareTab
    @Environment(\.careWindow) private var window
    func body(content: Content) -> some View {
        let rail = window.usesSideTabs
        content
            .safeAreaInset(edge: .leading, spacing: 0) { if rail { CareBottomTabs(selection: $selection, axis: .vertical) } }
            .safeAreaInset(edge: .bottom, spacing: 0) { if !rail { CareBottomTabs(selection: $selection) } }
    }
}

/// Flat Stitch navigation: full-width bar along the bottom, or a slim rail along the leading edge.
struct CareBottomTabs: View {
    @Binding var selection: CareTab
    var axis: Axis = .horizontal
    @Environment(\.locale) private var appLocale
    var body: some View {
        let _ = appLocale
        if axis == .horizontal {
            // The background runs under the iPhone Duo's side safe area (status cluster strip); the tabs stay clear of it.
            HStack(spacing: 0) { tabs }
                .frame(maxWidth: 620).frame(maxWidth: .infinity).padding(.top, 10).padding(.bottom, 4)
                .background(CareTheme.surface.ignoresSafeArea(edges: [.bottom, .horizontal]))
                .overlay(alignment: .top) { Rectangle().fill(CareTheme.border).frame(height: 0.5).ignoresSafeArea(edges: .horizontal) }
        } else {
            VStack(spacing: 6) { tabs; Spacer(minLength: 0) }
                .frame(width: 84).padding(.top, 12)
                .background(CareTheme.surface.ignoresSafeArea(edges: [.leading, .vertical]))
                .overlay(alignment: .trailing) { Rectangle().fill(CareTheme.border).frame(width: 0.5).ignoresSafeArea(edges: .vertical) }
        }
    }
    @ViewBuilder private var tabs: some View {
        tab(.quick, title: L10n.text("Ghi nhanh"), symbol: "bolt", identifier: "tab.quick")
        tab(.diary, title: L10n.text("Nhật ký"), symbol: "auto_stories", identifier: "tab.diary")
        tab(.statistics, title: L10n.text("Thống kê"), symbol: "bar_chart", identifier: "tab.statistics")
    }
    private func tab(_ value: CareTab, title: String, symbol: String, identifier: String) -> some View {
        Button { selection = value } label: {
            VStack(spacing: 5) {
                CareIcon(name: "Stitch_" + symbol, color: selection == value ? CareTheme.accent : CareTheme.secondary, size: 26)
                Text(title).font(CareFont.caption).fontWeight(selection == value ? .bold : .medium)
                    .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.8)
            }.foregroundStyle(selection == value ? CareTheme.accent : CareTheme.secondary)
                .frame(maxWidth: axis == .horizontal ? .infinity : nil, minHeight: axis == .horizontal ? 48 : 64)
                .frame(width: axis == .vertical ? 76 : nil)
                .background(axis == .vertical && selection == value ? CareTheme.accent.opacity(0.08) : .clear, in: .rect(cornerRadius: 14))
                .contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityIdentifier(identifier)
            .accessibilityAddTraits(selection == value ? .isSelected : [])
    }
}
