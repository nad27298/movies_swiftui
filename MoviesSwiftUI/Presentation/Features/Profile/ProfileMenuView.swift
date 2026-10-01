//
//  ProfileMenuView.swift
//  MoviesSwiftUI
//
//  Created by DaoNA3 on 01/10/2026.
//

import SwiftUI

// Menu native thay drawer UIKit bên thứ ba, được AppRoot mở bằng sheet.
// NavigationStack bên trong sheet cho phép mở editor và danh sách reminder mà không tạo root app mới.
// ProfileStore là nguồn Profile đã lưu; không tự refresh UserDefaults khi menu render.
// RemindersViewModel tính hai nhóm theo now, menu chỉ chọn hai lịch sắp tới gần nhất.
// Task có identity từ lịch và scenePhase nên thay lịch/đổi scene sẽ hủy task cũ.
// Chọn một reminder gửi route pending để AppRoot chờ sheet đóng rồi mới mở Movies.
// Không push trực tiếp trong action đóng sheet vì dismissal có lifecycle/animation riêng.


struct ProfileMenuView: View {
    @Environment(MovieLibraryStore.self) private var library
    @Environment(ProfileStore.self) private var profile
    @Environment(AppRouter.self) private var router
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @State private var clock: RemindersViewModel

    init(library: MovieLibraryStore) { _clock = State(initialValue: RemindersViewModel(library: library)) }

    var body: some View {
        NavigationStack {
            List {
                Section("Profile") {
                    AvatarView(data: profile.avatarData, size: 90).frame(maxWidth: .infinity)
                    Text(profile.profile.name.isEmpty ? "Chưa có tên" : profile.profile.name).font(.headline)
                    Text(profile.profile.birthday?.displayText ?? "Chưa có ngày sinh")
                    Text(profile.profile.email.isEmpty ? "Chưa có email" : profile.profile.email)
                    Text(profile.profile.gender.title)
                    if let warning = profile.loadWarning { Text(warning).foregroundStyle(.orange) }
                    NavigationLink("Edit Profile") { ProfileEditView(store: profile) }
                }
                Section("Lịch nhắc sắp tới") {
                    if !library.isLoaded {
                        ErrorStateView(message: library.loadError ?? "Chưa tải được lịch.") { library.load() }
                    } else if clock.upcoming.isEmpty {
                        Text("Không có lịch sắp tới.").foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(clock.upcoming.prefix(2))) { reminder in
                            // Menu chỉ queue ID; AppRoot nhận thay đổi và bắt đầu đóng sheet.
                            // Không gọi openMovie ngay tại đây vì menu vẫn còn đang present.
                            // ID mở ở Movies là hành vi native đã chốt trong migration.
                            Button { router.queueMovie(reminder.id) } label: {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(reminder.movie.title).font(.headline)
                                    Text(reminder.scheduledAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.subheadline).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    if !library.reminders.isEmpty {
                        NavigationLink("Show All") { RemindersView(library: library) }
                    }
                }
            }
            .navigationTitle("Hồ sơ & lịch nhắc")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Đóng") { dismiss() } } }
            .task(id: ReminderClockID(dates: library.reminders.map(\.scheduledAt), isActive: scenePhase == .active)) {
                if scenePhase == .active { await clock.observeTime() }
            }
            .onChange(of: scenePhase) { _, phase in if phase == .active { clock.refreshClock() } }
        }
        .interactiveDismissDisabled(library.isReminderBusy)
    }
}
