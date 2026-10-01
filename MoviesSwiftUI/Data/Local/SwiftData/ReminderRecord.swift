//
//  ReminderRecord.swift
//  MoviesSwiftUI
//
//  Created by DaoNA3 on 01/10/2026.
//

import Foundation
import SwiftData

// Entity SwiftData cho reminder đã lưu, không phải notification của hệ điều hành.
// movieID duy nhất để Save cùng phim cập nhật một record thay vì chèn thêm.
// movieData giữ snapshot cho danh sách kể cả khi chưa tải lại API.
// scheduledAt là thời điểm nhắc, createdAt/updatedAt phục vụ lịch sử thao tác.
// Không lưu isScheduled vì pending request có thể thay đổi ngoài database.
// Repository map entity về MovieReminder value; UI không giữ reference tới model được context quản lý.
// nonisolated không thay thế việc kiểm soát truy cập ModelContext trên MainActor.


@Model nonisolated final class ReminderRecord {
    @Attribute(.unique) var movieID: Int
    var movieData: Data
    var scheduledAt: Date
    var createdAt: Date
    var updatedAt: Date

    init(movieID: Int, movieData: Data, scheduledAt: Date, createdAt: Date, updatedAt: Date) {
        self.movieID = movieID
        self.movieData = movieData
        self.scheduledAt = scheduledAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
