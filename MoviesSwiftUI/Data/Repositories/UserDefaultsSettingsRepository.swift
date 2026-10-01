//
//  UserDefaultsSettingsRepository.swift
//  MoviesSwiftUI
//
//  Created by DaoNA3 on 01/10/2026.
//

import Foundation

// Adapter UserDefaults lưu toàn bộ MovieSettings dưới dạng Codable Data.
// Key có version để thể hiện cấu trúc lưu hiện tại, không tái dùng key của app Objective-C.
// Không có data thì dùng default; có data sai cấu trúc thì throws để store cảnh báo.
// JSONEncoder/JSONDecoder được dùng cho dữ liệu local, không chỉ cho API JSON.
// Kiểm tra giá trị decode để dữ liệu ngoài phạm vi Slider không trở thành settings hợp lệ.
// UserDefaults.set nhận Data đã encode, không cung cấp transaction đảm bảo flush vật lý.
// Revision và tải lại Movies nằm ở SettingsStore, không đặt observer UI trong repository.


@MainActor final class UserDefaultsSettingsRepository: SettingsRepository {
    private let defaults: UserDefaults
    private let key = "settings.v1"
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func load() throws -> MovieSettings {
        guard let data = defaults.data(forKey: key) else { return MovieSettings() }
        let value = try JSONDecoder().decode(MovieSettings.self, from: data)
        guard value.minimumRating.isFinite, (0...10).contains(value.minimumRating),
              value.minimumReleaseDate >= .minimum else { throw AppError.storage }
        return value
    }

    func save(_ settings: MovieSettings) throws {
        defaults.set(try JSONEncoder().encode(settings), forKey: key)
    }
}
