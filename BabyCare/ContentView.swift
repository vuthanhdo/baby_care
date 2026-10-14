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
                        NavigationStack { QuickLogView(selectedTab: $selectedTab).safeAreaInset(edge: .bottom, spacing: 0) { CareBottomTabs(selection: $selectedTab) } }
                    } label: { Label(L10n.text("Ghi nhanh"), systemImage: "bolt") }
                    Tab(value: .diary) {
                        NavigationStack { DiaryView().safeAreaInset(edge: .bottom, spacing: 0) { CareBottomTabs(selection: $selectedTab) } }
                    } label: { Label(L10n.text("Nhật ký"), systemImage: "book.pages") }
                    Tab(value: .statistics) {
                        NavigationStack {
                            StatisticsView()
                                .safeAreaInset(edge: .top, spacing: 0) { CareBabyHeaderView() }
                                .safeAreaInset(edge: .bottom, spacing: 0) { CareBottomTabs(selection: $selectedTab) }
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

/// Flat, full-width Stitch navigation; each root owns its inset so pushed forms hide it.
struct CareBottomTabs: View {
    @Binding var selection: CareTab
    @Environment(\.locale) private var appLocale
    var body: some View {
        let _ = appLocale
        HStack(spacing: 0) {
            tab(.quick, title: L10n.text("Ghi nhanh"), symbol: "bolt", identifier: "tab.quick")
            tab(.diary, title: L10n.text("Nhật ký"), symbol: "auto_stories", identifier: "tab.diary")
            tab(.statistics, title: L10n.text("Thống kê"), symbol: "bar_chart", identifier: "tab.statistics")
        }.padding(.top, 10).padding(.bottom, 4)
            .background(CareTheme.surface.ignoresSafeArea(edges: .bottom))
            .overlay(alignment: .top) { Rectangle().fill(CareTheme.border).frame(height: 0.5) }
    }
    private func tab(_ value: CareTab, title: String, symbol: String, identifier: String) -> some View {
        Button { selection = value } label: {
            VStack(spacing: 5) {
                CareIcon(name: "Stitch_" + symbol, color: selection == value ? CareTheme.accent : CareTheme.secondary, size: 26)
                Text(title).font(CareFont.caption).fontWeight(selection == value ? .bold : .medium)
            }.foregroundStyle(selection == value ? CareTheme.accent : CareTheme.secondary)
                .frame(maxWidth: .infinity, minHeight: 48)
                .contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityIdentifier(identifier)
            .accessibilityAddTraits(selection == value ? .isSelected : [])
    }
}
