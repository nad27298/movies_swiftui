//
//  NotificationScheduler.swift
//  MoviesSwiftUI
//
//  Created by DaoNA3 on 01/10/2026.
//

import Foundation
import UserNotifications

// Adapter của UserNotifications, không biết View nào đang mở.
// Mỗi movie ID có identifier ổn định để lịch mới thay request cũ thay vì nhân đôi.
// Quyền được hỏi ở hành vi lưu reminder, không hỏi ngay tại launch.
// UNCalendarNotificationTrigger dùng ngày/giờ/phút và repeats false cho một lần nhắc.
// Local và notification không có transaction chung; outcome phải mô tả từng phần đúng.
// Nếu local đã đổi giờ mà scheduling thất bại, bỏ request cũ để không gửi sai giờ.
// reconcile đọc pending requests thực tế, đối chiếu ID/thời điểm và loại lịch hệ thống không còn khớp.
// Không lưu bool scheduled như một sự thật vĩnh viễn; không tự xin quyền/đặt lại mọi lịch ở foreground.


@MainActor final class NotificationScheduler: NotificationScheduling {
    private let center = UNUserNotificationCenter.current()
    private let prefix = "movie-reminder-"

    private func identifier(_ id: Int) -> String { prefix + String(id) }

    // Đọc trạng thái quyền trước; chỉ requestAuthorization nếu hệ thống chưa có quyết định.
    // Sau dialog quyền, đọc lại status và kiểm tra thời điểm một lần nữa vì người dùng có thể chờ lâu.
    // Dùng cùng identifier để notification mới thay cho phim đó, không thêm lịch trùng.
    // Mọi lỗi ở đây trả savedWithoutNotification vì use case đã lưu local trước khi gọi.
    func schedule(_ reminder: MovieReminder) async -> ReminderSaveOutcome {
        let id = identifier(reminder.id)
        do {
            var settings = await center.notificationSettings()
            if settings.authorizationStatus == .notDetermined {
                _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                settings = await center.notificationSettings()
            }
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
                    || settings.authorizationStatus == .ephemeral else {
                center.removePendingNotificationRequests(withIdentifiers: [id])
                return .savedWithoutNotification("Đã lưu lịch, chưa thể gửi thông báo. Bạn có thể cấp quyền trong Cài đặt hệ thống.")
            }
            guard reminder.scheduledAt > Date() else {
                center.removePendingNotificationRequests(withIdentifiers: [id])
                return .savedWithoutNotification("Đã lưu lịch nhưng giờ đã qua trong lúc chờ quyền. Vui lòng chọn giờ mới.")
            }
            let content = UNMutableNotificationContent()
            content.title = "Movie Reminder"
            content.body = "Đến giờ xem \(reminder.movie.title)."
            content.sound = .default
            content.userInfo = ["movieID": reminder.id]
            // Chuyển thời điểm tuyệt đối thành calendar components mà trigger yêu cầu.
            // Gắn calendar/timeZone rõ ràng để không đoán lịch/múi giờ khi hệ thống dựng thời điểm.
            // Kiểm tra nextTriggerDate khớp thời điểm local, nhất là các giờ không tồn tại/lặp lại khi đổi DST.
            // Không dùng repeats true vì reminder chỉ nhắc một lần.
            var components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.scheduledAt)
            components.calendar = Calendar.current
            components.timeZone = .current
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            guard let fireDate = trigger.nextTriggerDate(), abs(fireDate.timeIntervalSince(reminder.scheduledAt)) < 1 else {
                center.removePendingNotificationRequests(withIdentifiers: [id])
                return .savedWithoutNotification("Đã lưu lịch nhưng hệ thống không xác định được đúng giờ này. Vui lòng chọn giờ khác.")
            }
            try await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
            return .scheduled
        } catch {
            // Local đã lưu giờ mới: bỏ lịch hệ thống cũ để không gửi sai giờ.
            center.removePendingNotificationRequests(withIdentifiers: [id])
            return .savedWithoutNotification("Đã lưu lịch nhưng không đặt được thông báo. Vui lòng thử lại.")
        }
    }

    // Đối chiếu pending requests, không lấy delivered notifications để kết luận người dùng đã đọc.
    // Chỉ xử lý request có prefix của tính năng này, không hủy notification không thuộc app flow.
    // Request thiếu record, giờ đã qua hoặc giờ không khớp bị coi là stale.
    // Trả dictionary status cho store sau khi đối chiếu, không sửa database reminder.
    func reconcile(_ reminders: [MovieReminder]) async -> [Int: ReminderScheduleStatus] {
        let requests = await center.pendingNotificationRequests()
        let byID = Dictionary(uniqueKeysWithValues: reminders.map { (identifier($0.id), $0) })
        var matched = Set<Int>()
        var stale: [String] = []
        for request in requests where request.identifier.hasPrefix(prefix) {
            guard let reminder = byID[request.identifier], reminder.scheduledAt > Date(),
                  let trigger = request.trigger as? UNCalendarNotificationTrigger,
                  let fireDate = trigger.nextTriggerDate(), abs(fireDate.timeIntervalSince(reminder.scheduledAt)) < 1 else {
                stale.append(request.identifier)
                continue
            }
            matched.insert(reminder.id)
        }
        center.removePendingNotificationRequests(withIdentifiers: stale)
        return Dictionary(uniqueKeysWithValues: reminders.map {
            ($0.id, $0.scheduledAt <= Date() ? .past : matched.contains($0.id) ? .scheduled : .notScheduled)
        })
    }
}
