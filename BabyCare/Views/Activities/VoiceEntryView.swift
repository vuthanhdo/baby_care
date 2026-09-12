import SwiftUI

struct VoiceEntryView: View {
    @Environment(BabyCareViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var voice = VoiceInputViewModel()
    @State private var showDiscard = false
    @State private var recordingBabyID: UUID?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                CareCard {
                    VStack(spacing: 18) {
                        CareIcon(name: "Stitch_mic", color: CareTheme.accent, size: 32)
                            .frame(width: 88, height: 88)
                            .background(CareTheme.accent.opacity(0.08), in: .circle)
                        Text("Nói để ghi").font(CareFont.title2.bold())
                        Text("Ghi cho \(viewModel.baby.name)").font(CareFont.headline)
                        Text(voice.isListening ? "Đang nghe… Khi kết thúc, câu rõ và hợp lệ sẽ tự lưu vào nhật ký." : "Nói một hoạt động rõ ràng. App tự lưu khi phân tích thành công; câu không rõ sẽ báo lỗi.")
                            .font(CareFont.subheadline).foregroundStyle(CareTheme.secondary).multilineTextAlignment(.center)
                        CarePrimaryButton(title: voice.isFinishing ? "Đang hoàn tất…" : voice.isListening ? "Dừng và xử lý" : "Bắt đầu ghi âm") {
                            if voice.isListening { voice.stop() }
                            else {
                                recordingBabyID = viewModel.baby.id
                                Task { await voice.start() }
                            }
                        }.disabled(voice.isFinishing || voice.isSaving)
                        Text("Không nói thời gian: mọi hoạt động được ghi lúc hiện tại. Dùng “rồi” để tách nhiều hoạt động.")
                            .font(CareFont.footnote).foregroundStyle(CareTheme.secondary)
                    }.frame(maxWidth: .infinity).padding(.vertical, 10)
                }
                CareCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("NỘI DUNG CẦN GHI").font(CareFont.caption).foregroundStyle(CareTheme.secondary)
                        TextField("Ví dụ: Bé uống 120 ml sữa lúc 7 giờ sáng", text: Binding(get: { voice.transcript }, set: { voice.edit($0) }), axis: .vertical)
                            .lineLimit(4...8).font(CareFont.body)
                            .disabled(voice.isListening || voice.isSaving)
                        CarePrimaryButton(title: voice.isSaving ? "Đang lưu…" : "Phân tích và lưu") {
                            Task { await saveRecognized() }
                        }.disabled(voice.isListening || voice.isSaving || voice.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                if let message = voice.message {
                    Text(message).font(CareFont.subheadline).foregroundStyle(CareTheme.medical)
                        .accessibilityIdentifier("voiceError")
                }
                if !voice.savedActivities.isEmpty {
                    CareSectionTitle(title: "Đã lưu \(voice.savedActivities.count) hoạt động", subtitle: "Bạn có thể xem và chỉnh sửa trong Nhật ký.")
                    ForEach(voice.savedActivities) { entry in
                        CareCard { CareActivityRow(activity: entry) }
                    }
                }
                CareCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Bạn có thể nói tự nhiên").font(CareFont.headline)
                        Text("Mẹ vừa cho bé uống một trăm hai mươi ml sữa\nCon em uống nước được ba mươi ml\nBé bú mẹ mười lăm phút\nĐo nách được ba mươi bảy phẩy năm độ\nCon mình ngủ được một giờ rưỡi\nBé ngủ nửa tiếng\nThay bỉm cho bé xong\nBé uống sữa 120ml và bé tắm xong")
                            .font(CareFont.subheadline)
                        Text("Có thể nói “sáng nay bảy giờ rưỡi…”, “…hồi 7h30 sáng” hoặc “…mười phút trước”. Không cần đọc đúng câu mẫu; hãy nói rõ lượng và đơn vị. Nếu còn thiếu thông tin, app sẽ chỉ ra phần cần bổ sung. Âm thanh có thể được Apple xử lý khi thiết bị không hỗ trợ nhận dạng tại máy.")
                            .font(CareFont.footnote).foregroundStyle(CareTheme.secondary)
                    }
                }
            }.padding(20).frame(maxWidth: 620).frame(maxWidth: .infinity)
        }
        .careScreen().navigationTitle("Nói để ghi").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar).toolbar(.hidden, for: .tabBar)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Đóng", systemImage: "xmark") {
                    voice.cancel()
                    if voice.transcript.isEmpty { dismiss() } else { showDiscard = true }
                }.labelStyle(.iconOnly).disabled(voice.isSaving)
            }
        }
        .onChange(of: voice.completedRecognition) { _, _ in
            Task { await saveRecognized(expectedBabyID: recordingBabyID) }
        }
        .onDisappear { voice.cancel() }
        .onChange(of: scenePhase) { _, phase in if phase == .background { voice.cancel() } }
        .interactiveDismissDisabled(voice.isSaving || voice.isListening || !voice.transcript.isEmpty)
        .confirmationDialog("Bỏ nội dung chưa lưu?", isPresented: $showDiscard, titleVisibility: .visible) {
            Button("Bỏ nội dung", role: .destructive) { dismiss() }
            Button("Tiếp tục nhập", role: .cancel) { }
        }
    }

    private func saveRecognized(expectedBabyID: UUID? = nil) async {
        guard scenePhase == .active else { return }
        let babyID = expectedBabyID ?? viewModel.baby.id
        guard babyID == viewModel.baby.id else { voice.cancel(); return }
        await voice.parseAndSave(babyID: babyID) { entries in
            await viewModel.send(.commit(.saveActivities(babyID: babyID, entries: entries), message: "Đã lưu \(entries.count) hoạt động từ giọng nói"))
        }
    }
}
#Preview { NavigationStack { VoiceEntryView() }.environment(BabyCareViewModel.preview()) }
