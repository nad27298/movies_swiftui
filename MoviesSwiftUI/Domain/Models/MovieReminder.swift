//
//  MovieReminder.swift
//  MoviesSwiftUI
//
//  Created by DaoNA3 on 01/10/2026.
//

import Foundation

// Reminder giữ snapshot phim và một thời điểm Date để nhắc người dùng.
// createdAt mô tả lần tạo đầu; updatedAt thay đổi khi chỉnh lịch cho cùng phim.
// Mỗi phim có một reminder nên id được lấy từ movie.id.
// ReminderScheduleStatus là state đối chiếu với hệ thống, không được lưu như bool vĩnh viễn.
// Lịch đã qua không chứng minh notification đã được gửi hoặc đọc.
// ReminderSaveOutcome tách thành công toàn bộ với trường hợp local đã lưu nhưng notification chưa đặt được.
// Nhờ enum có associated value, nhánh lỗi scheduling mang được thông báo để UI giải thích đúng kết quả.


nonisolated struct MovieReminder: Identifiable, Sendable {
    let movie: Movie
    let scheduledAt: Date
    let createdAt: Date
    let updatedAt: Date
    var id: Int { movie.id }
}

nonisolated enum ReminderScheduleStatus: Equatable, Sendable {
    case scheduled, notScheduled, past
}

// Associated value mang nội dung cảnh báo cùng nhánh savedWithoutNotification.
// Caller phải switch outcome thay vì coi mọi return bình thường là notification đã được đặt.
// throws dành cho bước không lưu được local; outcome cảnh báo dành cho bước local đã thành công.
nonisolated enum ReminderSaveOutcome: Sendable {
    case scheduled
    case savedWithoutNotification(String)
}
