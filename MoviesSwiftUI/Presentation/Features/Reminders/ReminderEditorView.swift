//
//  ReminderEditorView.swift
//  MoviesSwiftUI
//
//  Created by DaoNA3 on 01/10/2026.
//

import SwiftUI

// Sheet native dùng NavigationStack, Form và DatePicker ngày/giờ.
// @Bindable tạo binding của selectedDate vào draft ViewModel.
// DatePicker hạn chế input theo UI, nhưng ViewModel vẫn kiểm tra lại lúc Save.
// Toolbar cancellation/confirmation gần nút Cancel/Done của modal UIKit.
// interactiveDismissDisabled ngăn vuốt đóng trong khi lưu, không thay thế guard chống Save lặp.
// Một alert hiển thị lỗi hoặc cảnh báo để tránh hai presentation cạnh tranh.
// Tác vụ async chờ outcome; chỉ khi thành công toàn bộ mới dismiss tự động.


struct ReminderEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: ReminderEditorViewModel
    private let library: MovieLibraryStore

    init(movie: Movie, library: MovieLibraryStore) {
        self.library = library
        _model = State(initialValue: ReminderEditorViewModel(movie: movie, library: library))
    }

    var body: some View {
        // DatePicker đọc/ghi selectedDate của model qua Binding.
        // @Bindable không biến date thành persistence: chỉ Save mới gọi store/use case.
        // State UI và dữ liệu đã lưu khác nhau, nên Hủy không cần rollback một record bị sửa trực tiếp.
        @Bindable var model = model
        NavigationStack {
            Form {
                DatePicker("Thời điểm nhắc", selection: $model.selectedDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                if model.isSaving { ProgressView("Đang lưu và đặt thông báo…") }
                Text("Lịch đã qua vẫn được giữ trong lịch sử.").font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: AppTheme.contentWidth).frame(maxWidth: .infinity)
            .disabled(model.isSaving)
            .navigationTitle("Đặt lịch nhắc")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Hủy") { dismiss() }.disabled(model.isSaving) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") { Task { if await model.save() { dismiss() } } }
                        .disabled(model.isSaving || library.isReminderBusy)
                }
            }
            .alert(model.warningMessage == nil ? "Thông báo" : "Lịch đã lưu", isPresented: Binding(get: {
                model.errorMessage != nil || model.warningMessage != nil
            }, set: {
                if !$0 { model.errorMessage = nil; model.warningMessage = nil }
            })) {
                Button("Đóng", role: .cancel) { model.errorMessage = nil; model.warningMessage = nil }
            } message: {
                Text(model.errorMessage ?? model.warningMessage ?? "")
            }
        }
        .interactiveDismissDisabled(model.isSaving)
    }
}

#if DEBUG
// Sheet này tự có NavigationStack; Preview không cần bọc thêm.
// Có thể đổi DatePicker và thử Save: scheduler mẫu trả kết quả, không đặt notification thật.
#Preview("Chỉnh lịch nhắc") {
    PreviewHost { context in
        ReminderEditorView(movie: PreviewSampleData.movie, library: context.library)
    }
}
#endif
