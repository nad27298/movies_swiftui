//
//  ProfileStore.swift
//  MoviesSwiftUI
//
//  Created by DaoNA3 on 01/10/2026.
//

import Foundation
import Observation

// Shared state Profile đã lưu và ảnh hiện tại của menu/editor.
// Store nhận repository và file storage, không phụ thuộc View hoặc PhotosPicker.
// private(set) ngăn editor sửa trực tiếp Profile đã áp dụng; editor giữ draft riêng.
// Luồng Save phối hợp file và UserDefaults theo thứ tự để ảnh cũ còn dùng được khi lỗi.
// avatarData là dữ liệu ảnh đã đọc cho UI, không phải nguồn persistence độc lập.
// @Observable cập nhật menu khi profile/avatarData được công bố sau Save.
// Load lỗi tạo warning, không tự lưu defaults để che mất dữ liệu cũ.


@MainActor @Observable final class ProfileStore {
    private(set) var profile = UserProfile()
    private(set) var avatarData: Data?
    private(set) var loadWarning: String?
    private let repository: any ProfileRepository
    private let files: AvatarFileStorage

    init(repository: any ProfileRepository, files: AvatarFileStorage) {
        self.repository = repository
        self.files = files
        do {
            profile = try repository.load()
            avatarData = files.read(profile.avatarFilename)
        } catch { loadWarning = "Profile đã lưu không đọc được. App chưa ghi đè dữ liệu cũ." }
    }

    // Copy draft thành value có thể bổ sung filename ảnh mới mà không sửa draft ngoài ý muốn.
    // Ghi file mới trước; lưu Profile trỏ file mới; sau đó mới công bố state và xóa ảnh cũ.
    // Nếu lỗi trước mốc lưu Profile, dọn file mới và giữ reference/bitmap cũ.
    // Không có ảnh mới thì dùng filename hiện tại, không tạo một file UUID chỉ để Save tên/email.
    func save(_ draft: UserProfile, newAvatar: Data?) throws {
        var value = draft
        var newFilename: String?
        let oldFilename = profile.avatarFilename
        do {
            if let newAvatar {
                newFilename = try files.write(newAvatar)
                value.avatarFilename = newFilename
            }
            try repository.save(value)
            profile = value
            avatarData = newAvatar ?? files.read(value.avatarFilename)
            loadWarning = nil
            if newFilename != nil { files.remove(oldFilename) }
        } catch {
            files.remove(newFilename)
            throw error
        }
    }
}
