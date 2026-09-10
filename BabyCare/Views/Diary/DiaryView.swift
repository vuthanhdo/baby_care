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

    private var filtered: [CareActivity] {
        viewModel.activities.filter { activity in
            (allDates || Calendar.current.isDate(activity.date, inSameDayAs: day)) &&
            (group == nil || activity.kind.group == group) &&
            (query.isEmpty || [activity.kind.title, activity.value, activity.note, activity.detail].joined(separator: " ").localizedStandardContains(query))
        }.sorted { $0.date > $1.date }
    }
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(CareTheme.secondary)
                    TextField("Tìm hoạt động, thuốc, ghi chú…", text: $query)
                        .accessibilityIdentifier("diarySearchField")
                    if !query.isEmpty {
                        Button("Xóa tìm kiếm", systemImage: "xmark.circle.fill") { query = "" }.labelStyle(.iconOnly)
                    }
                    NavigationLink { VoiceEntryView() } label: { CareIcon(name: "HomeIcon18", color: CareTheme.secondary, size: 18) }
                        .accessibilityLabel("Nhập bằng giọng nói").frame(minWidth: 44, minHeight: 44)
                }.padding(.leading, 12).background(CareTheme.border.opacity(0.55), in: .rect(cornerRadius: 12))
                HStack {
                    Menu {
                        Button("Ngày đang chọn") { allDates = false }
                        Button("Tất cả thời gian") { allDates = true }
                    } label: {
                        Text("Phạm vi: \(allDates ? "Tất cả thời gian" : "Theo ngày")").font(CareFont.caption.weight(.medium))
                    }.frame(minHeight: 44)
                    Spacer()
                    CareBadge(title: "\(filtered.count) sự kiện")
                }
                HStack {
                    Button("Ngày trước", systemImage: "chevron.left") { moveDay(-1) }.labelStyle(.iconOnly).frame(width: 44, height: 44)
                    Spacer()
                    Button { draftDay = day; showingDate = true } label: {
                        Label(day.careFormatted(date: .numeric, time: .omitted), systemImage: "calendar").font(CareFont.subheadline.weight(.semibold))
                    }
                    Spacer()
                    Button("Ngày sau", systemImage: "chevron.right") { moveDay(1) }.labelStyle(.iconOnly).frame(width: 44, height: 44)
                        .disabled(Calendar.current.isDateInToday(day))
                }.padding(4).background(CareTheme.surface, in: .rect(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(CareTheme.border))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        filterButton("Tất cả", group: nil)
                        ForEach(ActivityGroup.allCases) { filterButton($0.title, group: $0) }
                    }
                }
                HStack {
                    Text(allDates ? "Nhật ký" : Calendar.current.isDateInToday(day) ? "Hôm nay" : "Hoạt động trong ngày").font(CareFont.title3.bold())
                    Spacer()
                }.padding(.top, 4)
                if filtered.isEmpty {
                    ContentUnavailableView {
                        Label("Chưa có ghi nhận", systemImage: "book.closed")
                    } description: {
                        Text(query.isEmpty && group == nil ? "Ghi hoạt động đầu tiên cho bé trong ngày này." : "Thử đổi từ khóa hoặc xóa bộ lọc.")
                    } actions: {
                        if !query.isEmpty || group != nil {
                            Button("Xóa bộ lọc") { query = ""; group = nil; allDates = true }
                        } else { Button("Ghi hoạt động") { showingPicker = true } }
                    }
                } else {
                    ForEach(filtered) { activity in
                        NavigationLink { ActivityDetailView(activity: activity) } label: {
                            DiaryActivityCardView(activity: activity, showsDate: allDates)
                        }.buttonStyle(.plain)
                    }
                }
            }.padding(20).frame(maxWidth: 620).frame(maxWidth: .infinity)
        }
        .onChange(of: query) { old, new in
            if old.isEmpty && !new.isEmpty { scopeBeforeSearch = allDates; allDates = true }
            else if !old.isEmpty && new.isEmpty { allDates = scopeBeforeSearch }
        }
        .careScreen().toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top, spacing: 0) { CareBabyHeaderView() }
        .safeAreaInset(edge: .bottom, alignment: .trailing) {
            Button { showingPicker = true } label: { Label("Ghi hoạt động", systemImage: "plus").font(CareFont.headline).padding(.vertical, 6) }
                .buttonStyle(.borderedProminent).buttonBorderShape(.capsule).padding(.horizontal, 20).padding(.bottom, 8)
        }
        .sheet(isPresented: $showingPicker) { NavigationStack { ActivityPickerView(initialGroup: group ?? .medical) } }
        .sheet(isPresented: $showingDate) {
            NavigationStack {
                DatePicker("Chọn ngày", selection: $draftDay, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.graphical).padding().navigationTitle("Ngày nhật ký")
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Áp dụng") { day = draftDay; allDates = false; showingDate = false } } }
            }.presentationDetents([.medium, .large])
        }
    }
    private func moveDay(_ amount: Int) {
        day = Calendar.current.date(byAdding: .day, value: amount, to: day) ?? day
        allDates = false
    }
    private func filterButton(_ title: String, group option: ActivityGroup?) -> some View {
        Button { group = option } label: {
            HStack(spacing: 5) {
                if group == option { Image(systemName: "checkmark") }
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
    var body: some View {
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
                Text(activity.formattedValue.isEmpty ? "Đã ghi nhận" : activity.formattedValue)
                    .font(activity.numericValue != nil ? CareFont.title2.bold() : CareFont.subheadline.weight(.semibold))
                    .foregroundStyle(activity.kind.group.color).frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12).background(activity.kind.group.background.opacity(0.65), in: .rect(cornerRadius: 12))
                if !activity.note.isEmpty || !activity.detail.isEmpty {
                    Text([activity.detail, activity.note].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(CareFont.caption).foregroundStyle(CareTheme.secondary)
                }
                if showsDate { Text(activity.date, format: .dateTime.day().month().year()).font(CareFont.caption).foregroundStyle(CareTheme.secondary) }
            }
        }.foregroundStyle(CareTheme.text)
    }
}
#Preview { NavigationStack { DiaryView() }.environment(BabyCareViewModel.preview()) }
