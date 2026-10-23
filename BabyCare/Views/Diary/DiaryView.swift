import SwiftUI

/// Stitch D — native view backed by the existing data provider.
struct DiaryView: View {
    @Environment(BabyCareViewModel.self) private var viewModel
    @State private var query = ""
    @State private var day = Date()
    @State private var group: ActivityGroup?
    @State private var allDates = false
    @State private var showingPicker = false
    @State private var showingDate = false
    @State private var draftDay = Date()
    @State private var scopeBeforeSearch = false
    /// Entry shown in the detail pane when the window is wide enough for list and detail side by side.
    @State private var selectedID: CareActivity.ID?
    /// Entry pushed full screen when the list is alone (phone, folded iPhone Duo).
    @State private var pushed: CareActivity?
    @State private var span: ClosedRange<CGFloat> = 0...0
    @Environment(\.careWindow) private var window
    @Environment(\.dynamicTypeSize) private var typeSize

    /// Width of the list pane, splitting at the hinge of an open iPhone Duo; nil keeps a single pane.
    private var listWidth: CGFloat? {
        CareColumnsPlan.paneSplit(width: span.upperBound - span.lowerBound, split: window.allowsColumns(typeSize: typeSize),
                                  fold: window.localFold(in: span))
    }
    private var selectedActivity: CareActivity? { selectedID.flatMap { id in viewModel.activities.first { $0.id == id } } }

    private var filtered: [CareActivity] {
        viewModel.activities.filter { activity in
            (allDates || Calendar.current.isDate(activity.date, inSameDayAs: day)) &&
            (group == nil || activity.kind.group == group) &&
            (query.isEmpty || [activity.kind.title, activity.formattedValue, activity.note, activity.displayDetail, activity.value, activity.detail].joined(separator: " ").localizedStandardContains(query))
        }.sorted { $0.date > $1.date }
    }
    @Environment(\.locale) private var appLocale
    var body: some View {
        let _ = appLocale
        let listWidth = listWidth
        HStack(spacing: 0) {
            list(isSplit: listWidth != nil)
                .safeAreaInset(edge: .bottom, alignment: .trailing) { addButton }
                .frame(width: listWidth)
            if listWidth != nil { detailPane }
        }
        .careHorizontalSpan($span)
        .onChange(of: query) { old, new in
            if old.isEmpty && !new.isEmpty { scopeBeforeSearch = allDates; allDates = true }
            else if !old.isEmpty && new.isEmpty { allDates = scopeBeforeSearch }
        }
        // Folding keeps the open entry on screen full size; unfolding moves it back beside the list.
        .onChange(of: listWidth != nil) { _, isSplit in
            if isSplit, let pushed { selectedID = pushed.id; self.pushed = nil }
            else if !isSplit, let selectedActivity { pushed = selectedActivity }
        }
        .onChange(of: pushed?.id) { _, id in if id == nil && listWidth == nil { selectedID = nil } }
        .navigationDestination(isPresented: Binding(get: { pushed != nil }, set: { if !$0 { pushed = nil } })) {
            if let pushed { ActivityDetailView(activity: pushed) }
        }
        .careScreen().toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .top, spacing: 0) { CareBabyHeaderView() }
        .sheet(isPresented: $showingPicker) { NavigationStack { ActivityPickerView(initialGroup: group ?? .medical) }.careToastBanner() }
        .sheet(isPresented: $showingDate) {
            NavigationStack {
                DatePicker(L10n.text("Chọn ngày"), selection: $draftDay, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.graphical).padding().navigationTitle(L10n.text("Ngày nhật ký"))
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L10n.text("Áp dụng")) { day = draftDay; allDates = false; showingDate = false } } }
            }.presentationDetents([.medium, .large])
        }
    }

    private func open(_ activity: CareActivity) {
        if listWidth != nil { selectedID = activity.id } else { pushed = activity }
    }

    private var addButton: some View {
        Button { showingPicker = true } label: {
            HStack(spacing: 8) {
                CareIcon(name: "Stitch_add", color: .white, size: 22)
                Text(L10n.text("Ghi hoạt động")).font(CareFont.headline).foregroundStyle(.white)
            }.padding(.horizontal, 20).frame(minHeight: 52).background(CareTheme.accent, in: .capsule)
        }.buttonStyle(.plain).padding(.horizontal, 20).padding(.bottom, 8)
    }

    @ViewBuilder private var detailPane: some View {
        Group {
            if let activity = selectedActivity {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(L10n.text("Chi tiết hoạt động")).font(CareFont.title3.bold())
                        ActivityDetailContent(activity: activity) { selectedID = nil }
                    }.padding(20).frame(maxWidth: 620).frame(maxWidth: .infinity)
                }.id(activity.id)
            } else {
                ContentUnavailableView {
                    Label(L10n.text("Chọn một hoạt động"), systemImage: "hand.point.up.left")
                } description: { Text(L10n.text("Chi tiết hiện ở đây, bên cạnh nhật ký.")) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .leading) { Rectangle().fill(CareTheme.border).frame(width: 0.5).ignoresSafeArea(edges: .bottom) }
    }

    private func list(isSplit: Bool) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(CareTheme.secondary)
                    TextField(L10n.text("Tìm hoạt động, thuốc, ghi chú…"), text: $query)
                        .accessibilityIdentifier("diarySearchField")
                    if !query.isEmpty {
                        Button(L10n.text("Xóa tìm kiếm"), systemImage: "xmark.circle.fill") { query = "" }.labelStyle(.iconOnly)
                    }
                    NavigationLink { VoiceEntryView() } label: { CareIcon(name: "Stitch_mic", color: CareTheme.secondary, size: 18) }
                        .accessibilityLabel(L10n.text("Nhập bằng giọng nói")).frame(minWidth: 44, minHeight: 44)
                }.padding(.leading, 12).background(CareTheme.border.opacity(0.55), in: .rect(cornerRadius: 12))
                HStack {
                    Menu {
                        Button(L10n.text("Ngày đang chọn")) { allDates = false }
                        Button(L10n.text("Tất cả thời gian")) { allDates = true }
                    } label: {
                        Text(L10n.text("Phạm vi: {0}", "\(allDates ? L10n.text("Tất cả thời gian") : "Theo ngày")")).font(CareFont.caption.weight(.medium))
                    }.frame(minHeight: 44)
                    Spacer()
                    CareBadge(title: L10n.count(filtered.count, one: "1 sự kiện", many: "{0} sự kiện"))
                }
                HStack {
                    Button(L10n.text("Ngày trước"), systemImage: "chevron.left") { moveDay(-1) }.labelStyle(.iconOnly).frame(width: 44, height: 44)
                    Spacer()
                    Button { draftDay = day; showingDate = true } label: {
                        Label(day.careFormatted(date: .numeric, time: .omitted), systemImage: "calendar").font(CareFont.subheadline.weight(.semibold))
                    }
                    Spacer()
                    Button(L10n.text("Ngày sau"), systemImage: "chevron.right") { moveDay(1) }.labelStyle(.iconOnly).frame(width: 44, height: 44)
                        .disabled(Calendar.current.isDateInToday(day))
                }.padding(4).background(CareTheme.surface, in: .rect(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(CareTheme.border))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        filterButton(L10n.text("Tất cả"), group: nil)
                        ForEach(ActivityGroup.allCases) { filterButton($0.title, group: $0) }
                    }
                }
                HStack {
                    Text(allDates ? L10n.text("Nhật ký") : Calendar.current.isDateInToday(day) ? L10n.text("Hôm nay") : L10n.text("Hoạt động trong ngày")).font(CareFont.title3.bold())
                    Spacer()
                }.padding(.top, 4)
                if filtered.isEmpty {
                    ContentUnavailableView {
                        Label(L10n.text("Chưa có ghi nhận"), systemImage: "book.closed")
                    } description: {
                        Text(query.isEmpty && group == nil ? L10n.text("Ghi hoạt động đầu tiên cho bé trong ngày này.") : L10n.text("Thử đổi từ khóa hoặc xóa bộ lọc."))
                    } actions: {
                        if !query.isEmpty || group != nil {
                            Button(L10n.text("Xóa bộ lọc")) { query = ""; group = nil; allDates = true }
                        } else { Button(L10n.text("Ghi hoạt động")) { showingPicker = true } }
                    }
                } else {
                    ForEach(filtered) { activity in
                        let selected = isSplit && activity.id == selectedID
                        Button { open(activity) } label: {
                            DiaryActivityCardView(activity: activity, showsDate: allDates, isSelected: selected)
                        }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
            }.padding(20).frame(maxWidth: 620).frame(maxWidth: .infinity)
        }
    }
    private func moveDay(_ amount: Int) {
        day = Calendar.current.date(byAdding: .day, value: amount, to: day) ?? day
        allDates = false
    }
    private func filterButton(_ title: String, group option: ActivityGroup?) -> some View {
        Button { group = option } label: {
            HStack(spacing: 5) {
                if let option {
                    CareIcon(name: option.assetName, color: group == option ? .white : option.color, size: 18)
                } else if group == nil { CareIcon(name: "Stitch_done", color: .white, size: 18) }
                Text(title)
            }.font(CareFont.subheadline.weight(.medium)).padding(.horizontal, 14).frame(minHeight: 44)
                .foregroundStyle(group == option ? .white : option?.color ?? CareTheme.accent)
                .background(group == option ? option?.color ?? CareTheme.accent : option?.background ?? CareTheme.surface, in: .capsule)
        }.buttonStyle(.plain).accessibilityAddTraits(group == option ? .isSelected : [])
    }
}

struct DiaryActivityCardView: View {
    let activity: CareActivity
    var showsDate = false
    /// Highlights the entry open in the detail pane.
    var isSelected = false
    @Environment(\.locale) private var appLocale
    var body: some View {
        let _ = appLocale
        CareCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    CareIcon(name: activity.kind.assetName, color: activity.kind.group.color)
                        .frame(width: 44, height: 44).background(activity.kind.group.background, in: .circle)
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(activity.date, format: .dateTime.hour().minute()).font(CareFont.caption).foregroundStyle(CareTheme.secondary)
                            CareBadge(title: activity.kind.group.title, color: activity.kind.group.color)
                        }
                        Text(activity.kind.title).font(CareFont.headline)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(CareFont.caption).foregroundStyle(CareTheme.secondary)
                }
                Text(activity.formattedValue.isEmpty ? L10n.text("Đã ghi nhận") : activity.formattedValue)
                    .font(activity.numericValue != nil ? CareFont.title2.bold() : CareFont.subheadline.weight(.semibold))
                    .foregroundStyle(activity.kind.group.color).frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12).background(activity.kind.group.background.opacity(0.65), in: .rect(cornerRadius: 12))
                if !activity.note.isEmpty || !activity.detail.isEmpty {
                    Text([activity.displayDetail, activity.note].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(CareFont.caption).foregroundStyle(CareTheme.secondary)
                }
                if showsDate { Text(activity.date, format: .dateTime.day().month().year()).font(CareFont.caption).foregroundStyle(CareTheme.secondary) }
            }
        }.foregroundStyle(CareTheme.text)
            .overlay { if isSelected { RoundedRectangle(cornerRadius: 16).strokeBorder(activity.kind.group.color, lineWidth: 2) } }
    }
}
#Preview { NavigationStack { DiaryView() }.environment(BabyCareViewModel.preview()) }
