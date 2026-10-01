//
//  SettingsRepository.swift
//  MoviesSwiftUI
//
//  Created by DaoNA3 on 01/10/2026.
//

import Foundation

// Contract đọc và lưu settings đã áp dụng.
// ViewModel sửa draft; chỉ Save mới gọi repository thông qua SettingsStore.
// load có thể lỗi decode nếu dữ liệu local hỏng hoặc không còn đúng cấu trúc.
// save có thể lỗi encode; UserDefaults.set không xác nhận flush vật lý xuống đĩa.
// Repository không quản lý revision hoặc refresh Movies; đó là trách nhiệm của store/ViewModel.
// Protocol này giúp Presentation không phụ thuộc trực tiếp UserDefaults.


@MainActor protocol SettingsRepository {
    func load() throws -> MovieSettings
    func save(_ settings: MovieSettings) throws
}
