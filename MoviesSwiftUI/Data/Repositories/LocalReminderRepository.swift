//
//  LocalReminderRepository.swift
//  MoviesSwiftUI
//
//  Created by DaoNA3 on 01/10/2026.
//

import Foundation
import SwiftData

// Triển khai lưu reminder bằng SwiftData, không làm việc với UserNotifications.
// Fetch theo movieID: có record thì sửa giờ/snapshot; chưa có thì insert.
// Khi cập nhật, createdAt được giữ, updatedAt đổi theo lần Save mới.
// Context riêng và autosave tắt giữ transaction local tách khỏi luồng await scheduling.
// Nếu save lỗi, rollback; caller không được công bố snapshot mới như đã lưu.
// fetch trả MovieReminder value, không trả entity để ViewModel sửa trực tiếp.
// Một transaction local thành công vẫn chưa bảo đảm thông báo hệ thống đã được đặt.


@MainActor final class LocalReminderRepository: ReminderRepository {
    private let context: ModelContext

    init(container: ModelContainer) {
        context = ModelContext(container)
        context.autosaveEnabled = false
    }

    func fetchReminders() throws -> [MovieReminder] {
        try context.fetch(FetchDescriptor<ReminderRecord>()).map {
            let movie = try JSONDecoder().decode(Movie.self, from: $0.movieData)
            guard movie.id == $0.movieID, movie.id > 0 else { throw AppError.storage }
            return MovieReminder(movie: movie, scheduledAt: $0.scheduledAt, createdAt: $0.createdAt, updatedAt: $0.updatedAt)
        }
    }

    // Cập nhật record cùng phim thay vì xóa rồi insert một lịch mới mỗi lần.
    // Nhánh update không sửa createdAt để giữ lần tạo đầu; updatedAt/scheduledAt phản ánh Save mới.
    // Không đặt notification tại đây vì context.save và hệ thống scheduling không chung transaction.
    // Use case chỉ gọi scheduler sau khi hàm này trả về thành công.
    func saveReminder(_ reminder: MovieReminder) throws {
        do {
            let id = reminder.id
            let data = try JSONEncoder().encode(reminder.movie)
            let descriptor = FetchDescriptor<ReminderRecord>(predicate: #Predicate { $0.movieID == id })
            if let record = try context.fetch(descriptor).first {
                record.movieData = data
                record.scheduledAt = reminder.scheduledAt
                record.updatedAt = reminder.updatedAt
            } else {
                context.insert(ReminderRecord(movieID: id, movieData: data, scheduledAt: reminder.scheduledAt,
                                              createdAt: reminder.createdAt, updatedAt: reminder.updatedAt))
            }
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}
