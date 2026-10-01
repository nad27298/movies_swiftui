//
//  RemindersView.swift
//  MoviesSwiftUI
//
//  Created by DaoNA3 on 01/10/2026.
//

import SwiftUI

// Danh sách native với hai Section: Sắp tới và Đã qua.
// Shared store giữ reminder đã lưu; ViewModel chỉ tính nhóm theo thời gian hiện tại.
// ForEach dùng movie ID vì một phim có một reminder.
// .task(id:) hủy task cũ và tạo task mới khi lịch hoặc trạng thái scene thay đổi.
// onChange foreground cập nhật now, không reload API hoặc tạo lại database.
// Chọn row queue movie ID cho router; dismissal và mở phim được AppRoot điều phối.
// Trạng thái chưa đặt notification chỉ mô tả pending request, không phủ nhận record local đã lưu.


struct RemindersView: View {
    @Environment(MovieLibraryStore.self) private var library
    @Environment(AppRouter.self) private var router
    @Environment(\.scenePhase) private var scenePhase
    @State private var model: RemindersViewModel

    init(library: MovieLibraryStore) { _model = State(initialValue: RemindersViewModel(library: library)) }

    var body: some View {
        List {
            if !model.upcoming.isEmpty {
                Section("Sắp tới") { ForEach(model.upcoming) { reminderRow($0) } }
            }
            if !model.past.isEmpty {
                Section("Đã qua") { ForEach(model.past) { reminderRow($0) } }
            }
        }
        .overlay {
            if !library.isLoaded {
                ErrorStateView(message: library.loadError ?? "Chưa đọc được lịch nhắc.") { library.load() }
            } else if library.reminders.isEmpty {
                EmptyStateView(title: "Chưa có lịch nhắc", symbol: "bell")
            }
        }
        .navigationTitle("Reminders")
        // Hashable identity gồm danh sách thời điểm và scene active.
        // Khi một phần identity đổi, SwiftUI cancel task trước rồi khởi động task mới.
        // Scene không active không chạy clock loop, tránh công việc theo dõi UI ở background.
        // Task vẫn cần xử lý cancellation bên trong sleep để cleanup đúng.
        .task(id: ReminderClockID(dates: library.reminders.map(\.scheduledAt), isActive: scenePhase == .active)) {
            if scenePhase == .active { await model.observeTime() }
        }
        .onChange(of: scenePhase) { _, phase in if phase == .active { model.refreshClock() } }
    }

    private func reminderRow(_ reminder: MovieReminder) -> some View {
        Button { router.queueMovie(reminder.id) } label: {
            VStack(alignment: .leading, spacing: 8) {
                MovieRow(movie: reminder.movie)
                Label(reminder.scheduledAt.formatted(date: .abbreviated, time: .shortened), systemImage: "bell")
                    .font(.subheadline).foregroundStyle(.secondary)
                if reminder.scheduledAt > model.now, library.scheduleStatuses[reminder.id] != .scheduled {
                    Text("Chưa đặt được thông báo").font(.caption).foregroundStyle(.orange)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
