import SwiftUI

enum CareTab: Hashable { case quick, diary, statistics }

struct ContentView: View {
    @Environment(BabyCareViewModel.self) private var viewModel
    @Environment(\.dynamicTypeSize) private var systemTextSize
    @AppStorage("care.textSize") private var textSize = "system"
    @State private var selectedTab: CareTab = .quick

    var body: some View {
        Group {
            if viewModel.state.phase == .idle || viewModel.state.phase == .loading {
                CareSplashView()
            } else if viewModel.state.phase == .failed {
                ContentUnavailableView {
                    Label("Không đọc được dữ liệu", systemImage: "externaldrive.badge.exclamationmark")
                } description: { Text(viewModel.state.error ?? "Hãy thử lại.") }
                actions: { Button("Thử lại") { Task { await viewModel.send(.load) } } }
            } else if viewModel.hasOnboarded {
                TabView(selection: $selectedTab) {
                    Tab(value: .quick) {
                        NavigationStack { QuickLogView(selectedTab: $selectedTab) }
                    } label: { Label("Ghi nhanh", systemImage: "bolt") }
                    Tab(value: .diary) {
                        NavigationStack { DiaryView() }
                    } label: { Label("Nhật ký", systemImage: "book.pages") }
                    Tab(value: .statistics) {
                        NavigationStack {
                            StatisticsView()
                                .safeAreaInset(edge: .top, spacing: 0) { CareBabyHeaderView() }
                        }
                    } label: { Label("Thống kê", systemImage: "chart.bar") }
                }
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
        .alert("Chưa hoàn tất thao tác", isPresented: Binding(
            get: { viewModel.state.phase == .ready && viewModel.state.error != nil },
            set: { if !$0 { Task { await viewModel.send(.dismissError) } } }
        )) {
            Button("Đóng", role: .cancel) { Task { await viewModel.send(.dismissError) } }
        } message: { Text(viewModel.state.error ?? "Hãy thử lại.") }
        .environment(\.locale, Locale(identifier: "vi_VN"))
        .dynamicTypeSize(textSize == "largest" ? .accessibility1 : textSize == "large" ? .xxxLarge : systemTextSize)
        .preferredColorScheme(.light)
        .overlay(alignment: .bottom) {
            if let toast = viewModel.toast {
                Text(toast).font(CareFont.subheadline.weight(.semibold))
                    .padding().foregroundStyle(.white)
                    .background(CareTheme.text, in: .capsule)
                    .padding(.horizontal, 20).padding(.bottom, viewModel.hasOnboarded ? 80 : 16)
                    .accessibilityAddTraits(.updatesFrequently)
                    .allowsHitTesting(false)
            }
        }
    }
}
#Preview { ContentView().environment(BabyCareViewModel.preview()) }
