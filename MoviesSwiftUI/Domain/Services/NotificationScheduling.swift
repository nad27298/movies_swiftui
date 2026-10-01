//
//  NotificationScheduling.swift
//  MoviesSwiftUI
//
//  Created by DaoNA3 on 01/10/2026.
//

import Foundation

// Contract của side effect notification, tách framework UserNotifications khỏi Domain.
// schedule trả kết quả có thể biểu thị đã lưu local nhưng chưa đặt được thông báo.
// reconcile đối chiếu reminder local với pending requests thực tế của hệ thống.
// Cả hai thao tác async vì quyền và danh sách notification được hệ thống trả về bất đồng bộ.
// Caller không cần biết UNCalendarNotificationTrigger hoặc identifier được tạo thế nào.
// MainActor giúp điều phối với shared store, không biến việc chờ hệ thống thành blocking.


@MainActor protocol NotificationScheduling {
    func schedule(_ reminder: MovieReminder) async -> ReminderSaveOutcome
    func reconcile(_ reminders: [MovieReminder]) async -> [Int: ReminderScheduleStatus]
}
