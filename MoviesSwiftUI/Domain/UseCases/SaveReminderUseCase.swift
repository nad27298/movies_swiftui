//
//  SaveReminderUseCase.swift
//  MoviesSwiftUI
//
//  Created by DaoNA3 on 01/10/2026.
//

import Foundation

// Nghiệp vụ có nhiều bước: kiểm tra thời điểm, lưu local, rồi đặt notification.
// Use case cần thiết ở đây vì hai nguồn dữ liệu không có transaction chung.
// Repository save thành công là mốc có thể công bố reminder mới cho UI.
// didPersist là callback nội bộ để store cập nhật snapshot đúng tại mốc đó.
// Callback không thay Observation: Observation tiếp tục đảm nhiệm việc UI phản ứng với snapshot mới.
// Nếu lưu local throws, schedule không chạy và notification cũ còn nguyên.
// Nếu scheduling thất bại, outcome phải nói rõ local đã lưu thay vì báo mọi bước thất bại.


@MainActor struct SaveReminderUseCase {
    let repository: any ReminderRepository
    let scheduler: any NotificationScheduling

    // Thứ tự có ý nghĩa nghiệp vụ: kiểm tra → Save local → callback snapshot → await scheduler.
    // Không đặt notification trước rồi mới Save vì lỗi database sẽ để lại một lịch không có record local.
    // Throws ở repository dừng hàm, nên scheduler không thay request cũ trong trường hợp đó.
    // Sau didPersist, scheduling có thể thất bại nhưng dữ liệu local vẫn phải được giữ và giải thích đúng.
    func execute(_ reminder: MovieReminder, didPersist: (MovieReminder) -> Void) async throws -> ReminderSaveOutcome {
        guard reminder.scheduledAt > Date() else { throw AppError.invalidInput("Vui lòng chọn thời điểm trong tương lai.") }
        // Không có transaction chung giữa database và hệ thống notification.
        try repository.saveReminder(reminder)
        didPersist(reminder)
        return await scheduler.schedule(reminder)
    }
}
