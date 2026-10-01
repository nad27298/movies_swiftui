//
//  RemindersViewModel.swift
//  MoviesSwiftUI
//
//  Created by DaoNA3 on 01/10/2026.
//

import Foundation
import Observation

// Owner của mốc now để UI phân loại lịch sắp tới/đã qua.
// Date() trong computed property một mình không tự làm SwiftUI render lại theo thời gian.
// Vì vậy now là observable state được cập nhật bởi task khi đến mốc hoặc foreground.
// upcoming/past là computed snapshots, không sao chép reminder sang hai mảng mutable cần đồng bộ.
// Sort dùng thời điểm và ID làm tie-breaker để thứ tự ổn định.
// Task.sleep nhường execution trong lúc chờ, không dùng blocking sleep trên MainActor.
// View điều khiển task(id:) theo lịch và scene active; rời màn/background hủy công việc.
// Clock task không tự xóa dữ liệu hoặc xác nhận notification đã được nhận.


nonisolated struct ReminderClockID: Hashable {
    let dates: [Date]
    let isActive: Bool
}

@MainActor @Observable final class RemindersViewModel {
    private(set) var now = Date()
    private let library: MovieLibraryStore
    init(library: MovieLibraryStore) { self.library = library }

    var upcoming: [MovieReminder] {
        library.reminders.filter { $0.scheduledAt > now }.sorted {
            $0.scheduledAt == $1.scheduledAt ? $0.id < $1.id : $0.scheduledAt < $1.scheduledAt
        }
    }
    var past: [MovieReminder] {
        library.reminders.filter { $0.scheduledAt <= now }.sorted {
            $0.scheduledAt == $1.scheduledAt ? $0.id < $1.id : $0.scheduledAt > $1.scheduledAt
        }
    }

    func refreshClock() { now = Date() }

    // refreshClock trước vòng chờ để xử lý lần xuất hiện/foreground sau khi một lịch đã qua.
    // Chọn mốc upcoming gần nhất và chờ tối đa 60 giây để nhận thay đổi giờ hệ thống khi màn đang mở.
    // Task.sleep là suspension có thể bị hủy, không block MainActor như Thread.sleep.
    // Nếu không còn lịch tương lai thì kết thúc; dữ liệu/scene thay đổi sẽ tạo task mới từ View.
    func observeTime() async {
        refreshClock()
        // Chờ mốc tiếp theo, tối đa 60 giây để nhận thay đổi giờ hệ thống khi đang mở màn.
        // Scene inactive hoặc rời màn sẽ hủy task qua task(id:) của View.
        while let next = upcoming.first?.scheduledAt {
            do { try await Task.sleep(for: .seconds(min(60, max(0.1, next.timeIntervalSinceNow + 0.1)))) }
            catch { return }
            guard !Task.isCancelled else { return }
            refreshClock()
        }
    }
}
