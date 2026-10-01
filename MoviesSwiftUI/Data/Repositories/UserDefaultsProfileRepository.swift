//
//  UserDefaultsProfileRepository.swift
//  MoviesSwiftUI
//
//  Created by DaoNA3 on 01/10/2026.
//

import Foundation

// Adapter UserDefaults cho Profile đã lưu.
// Profile là struct Codable; JSON lưu các trường và tên file ảnh, không lưu UIImage.
// Không có dữ liệu thì trả default; decode lỗi phải báo lên ProfileStore.
// Không tự ghi lại default khi load lỗi để tránh phá dữ liệu cũ còn có thể khôi phục.
// File avatar được ProfileStore phối hợp riêng với AvatarFileStorage.
// Một lần set không phải một callback xác nhận ghi vật lý xuống đĩa.


@MainActor final class UserDefaultsProfileRepository: ProfileRepository {
    private let defaults: UserDefaults
    private let key = "profile.v1"
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func load() throws -> UserProfile {
        guard let data = defaults.data(forKey: key) else { return UserProfile() }
        return try JSONDecoder().decode(UserProfile.self, from: data)
    }

    func save(_ profile: UserProfile) throws {
        // set() không xác nhận dữ liệu đã được flush vật lý xuống ổ đĩa.
        defaults.set(try JSONEncoder().encode(profile), forKey: key)
    }
}
