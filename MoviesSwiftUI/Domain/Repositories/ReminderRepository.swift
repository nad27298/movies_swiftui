//
//  ReminderRepository.swift
//  MoviesSwiftUI
//
//  Created by DaoNA3 on 01/10/2026.
//

import Foundation

// Contract lưu reminder local, tách khỏi việc đặt notification của hệ thống.
// Một lần save không hứa notification đã được đặt; SaveReminderUseCase phối hợp bước tiếp theo.
// fetchReminders trả value snapshots để ViewModel không sửa trực tiếp SwiftData model.
// throws giữ ranh giới thành công/thất bại rõ ràng trước khi cập nhật shared state.
// App giữ lịch đã qua nên contract không tự cleanup theo thời gian.
// MainActor và thao tác đồng bộ tránh await xen giữa lúc context có thay đổi chưa lưu.


@MainActor protocol ReminderRepository {
    func fetchReminders() throws -> [MovieReminder]
    func saveReminder(_ reminder: MovieReminder) throws
}
