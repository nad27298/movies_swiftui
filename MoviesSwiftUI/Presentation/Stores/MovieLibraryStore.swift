//
//  MovieLibraryStore.swift
//  MoviesSwiftUI
//
//  Created by DaoNA3 on 01/10/2026.
//

import Foundation
import Observation

// Nguồn state dùng chung cho Favorites và Reminders ở nhiều màn.
// Store giữ value snapshots, không đưa ModelContext/@Model vào cây View.
// @Observable giúp icon Favorite ở Movies/Detail và danh sách Favorites cùng phản ứng với dữ liệu mới.
// private(set) buộc thay đổi đi qua các thao tác có kiểm tra persistence.
// isLoaded phân biệt chưa đọc được local với một danh sách thực sự rỗng.
// scheduleStatuses chỉ phản ánh đối chiếu hệ thống hiện tại, không phải dữ liệu lưu vĩnh viễn.
// reminderTasks được store giữ để sheet đóng không hủy nửa luồng local-save/scheduling.
// Khóa reminder/reconcile tránh đối chiếu một snapshot cũ rồi hủy request vừa đặt.
// @ObservationIgnored loại các Task điều phối khỏi tracking UI, còn các cờ loading vẫn observable.


@MainActor @Observable final class MovieLibraryStore {
    private(set) var favorites: [FavoriteMovie] = []
    private(set) var reminders: [MovieReminder] = []
    private(set) var scheduleStatuses: [Int: ReminderScheduleStatus] = [:]
    private(set) var isLoaded = false
    private(set) var loadError: String?
    private(set) var savingReminderIDs: Set<Int> = []
    private(set) var isReconciling = false
    private let favoritesRepository: any FavoriteRepository
    private let remindersRepository: any ReminderRepository
    private let scheduler: any NotificationScheduling
    @ObservationIgnored private var reminderTasks: [Int: Task<ReminderSaveOutcome, Error>] = [:]

    // Computed flag tổng hợp thao tác lưu và đối chiếu hệ thống.
    // Một Bool riêng có thể bị đặt false trong khi một công việc khác còn chạy.
    // UI đọc flag này để disable Save; hàm saveReminder vẫn guard vì UI disable không phải khóa nghiệp vụ.
    var isReminderBusy: Bool { isReconciling || !savingReminderIDs.isEmpty }

    init(favorites: any FavoriteRepository, reminders: any ReminderRepository, scheduler: any NotificationScheduling) {
        favoritesRepository = favorites
        remindersRepository = reminders
        self.scheduler = scheduler
    }

    // Đọc hai tập dữ liệu vào biến tạm trước khi công bố bất kỳ snapshot nào.
    // Nếu một fetch throws, tránh trạng thái một nửa mới/một nửa cũ.
    // isLoaded chỉ true sau khi cả hai thành công; lỗi giữ snapshot hiện có nếu đã từng load.
    func load() {
        do {
            let favorites = try favoritesRepository.fetchFavorites()
            let reminders = try remindersRepository.fetchReminders()
            self.favorites = favorites
            self.reminders = reminders
            isLoaded = true
            loadError = nil
        } catch { loadError = AppError.storage.localizedDescription }
    }

    func isFavorite(_ id: Int) -> Bool { favorites.contains { $0.id == id } }
    func reminder(for id: Int) -> MovieReminder? { reminders.first { $0.id == id } }

    // Dùng shared snapshot để quyết định lưu hay xóa, không dùng Bool riêng từ row.
    // Persistence hoàn tất trước khi insert/remove snapshot; mọi màn sau đó thấy cùng kết quả.
    // Không await trong thao tác này nên hai lần bấm không xen vào một transaction local đang dở.
    // Nếu lỗi, icon và danh sách giữ trạng thái đã lưu trước đó.
    func toggleFavorite(_ movie: Movie) throws {
        guard isLoaded else { throw AppError.storage }
        do {
            if isFavorite(movie.id) {
                try favoritesRepository.deleteFavorite(movieID: movie.id)
                favorites.removeAll { $0.id == movie.id }
            } else {
                let favorite = FavoriteMovie(movie: movie, savedAt: Date())
                try favoritesRepository.saveFavorite(favorite)
                favorites.insert(favorite, at: 0)
            }
        } catch { throw AppError.storage }
    }

    func deleteFavorite(_ id: Int) throws {
        guard isLoaded else { throw AppError.storage }
        do {
            try favoritesRepository.deleteFavorite(movieID: id)
            favorites.removeAll { $0.id == id }
        } catch { throw AppError.storage }
    }

    // Khóa thao tác trước khi tạo Task để lần Save khác không lọt vào lúc đang chờ hệ thống.
    // Tạo reminder mới với createdAt cũ nếu cùng phim đã có lịch.
    // Task do store sở hữu là unstructured task, không phụ thuộc lifecycle task của sheet.
    // Caller await outcome; việc một View ngừng chờ không tự hủy phần scheduling sau Save local.
    // defer dọn task/ID tại cả đường thành công và throws.
    func saveReminder(movie: Movie, date: Date) async throws -> ReminderSaveOutcome {
        guard isLoaded else { throw AppError.storage }
        guard !isReminderBusy else { throw AppError.invalidInput("Đang xử lý lịch nhắc. Vui lòng thử lại sau.") }
        let now = Date()
        let reminder = MovieReminder(movie: movie, scheduledAt: date,
                                     createdAt: self.reminder(for: movie.id)?.createdAt ?? now, updatedAt: now)
        savingReminderIDs.insert(movie.id)
        let useCase = SaveReminderUseCase(repository: remindersRepository, scheduler: scheduler)
        // Task do store giữ: đóng sheet không hủy giữa bước lưu local và đặt thông báo.
        // didPersist chạy ngay sau save local, trước khi await quyền/scheduling.
        // Snapshot lúc này đã lưu thật, nhưng scheduleStatuses vẫn notScheduled cho tới outcome phù hợp.
        // Không đặt scheduled sớm rồi phải cố đoán rollback khi notification thất bại.
        let task = Task {
            try await useCase.execute(reminder) { [self] value in
                reminders.removeAll { $0.id == value.id }
                reminders.append(value)
                scheduleStatuses[value.id] = .notScheduled
            }
        }
        reminderTasks[movie.id] = task
        defer {
            savingReminderIDs.remove(movie.id)
            reminderTasks[movie.id] = nil
        }
        let outcome: ReminderSaveOutcome
        do { outcome = try await task.value }
        catch let error as AppError { throw error }
        catch { throw AppError.storage }
        if case .scheduled = outcome { scheduleStatuses[movie.id] = .scheduled }
        return outcome
    }

    // Không đối chiếu trong lúc Save để snapshot cũ không hủy notification mới.
    // Set isReconciling trước await, guard của Save đọc ngay được khóa này.
    // defer mở khóa dù View lifecycle thay đổi trong lúc chờ danh sách pending requests.
    // Chỉ đọc/đối chiếu, không xin quyền hoặc tự đặt lại mọi reminder.
    func reconcileNotifications() async {
        guard isLoaded, !isReminderBusy else { return }
        // Khóa thao tác lưu trong lúc đối chiếu để không hủy notification mới bằng snapshot cũ.
        isReconciling = true
        defer { isReconciling = false }
        scheduleStatuses = await scheduler.reconcile(reminders)
    }
}
