//
//  SettingsStore.swift
//  MoviesSwiftUI
//
//  Created by DaoNA3 on 01/10/2026.
//

import Foundation
import Observation

// Shared state của settings đã áp dụng, được inject cho các màn qua Environment.
// @Observable thông báo cho View đọc appliedSettings/revision khi chúng thay đổi.
// private(set) cho phép màn đọc nhưng buộc thao tác ghi đi qua save để giữ thứ tự persistence.
// Save repository trước, công bố settings mới sau; lỗi giữ giá trị cũ.
// revision là tín hiệu một lần Save, kể cả Save cùng giá trị như trước.
// Movies dùng revision để làm mới đúng thế hệ dữ liệu mà không cần NotificationCenter reload.
// loadWarning giải thích fallback trong bộ nhớ; dữ liệu lỗi chưa bị tự động ghi đè.


@MainActor @Observable final class SettingsStore {
    private(set) var appliedSettings = MovieSettings()
    private(set) var revision = 0
    private(set) var loadWarning: String?
    private let repository: any SettingsRepository

    init(repository: any SettingsRepository) {
        self.repository = repository
        do { appliedSettings = try repository.load() }
        catch { loadWarning = "Settings đã lưu không đọc được. App đang dùng giá trị mặc định và chưa ghi đè dữ liệu cũ." }
    }

    // Thứ tự quan trọng: repository Save trước, state/revision sau.
    // Nếu throws, các dòng sau không chạy nên Movies vẫn dùng settings đã lưu trước đó.
    // revision tăng cả khi Equatable cho rằng hai settings bằng nhau, vì Save vẫn là yêu cầu refresh.
    func save(_ settings: MovieSettings) throws {
        try repository.save(settings)
        appliedSettings = settings
        revision += 1
        loadWarning = nil
    }
}
