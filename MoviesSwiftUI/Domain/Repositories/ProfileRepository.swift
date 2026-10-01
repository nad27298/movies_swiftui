//
//  ProfileRepository.swift
//  MoviesSwiftUI
//
//  Created by DaoNA3 on 01/10/2026.
//

import Foundation

// Contract dữ liệu Profile; chỉ chứa thông tin và tên file avatar.
// Không đặt xử lý UIImage hoặc quyền camera trong Domain repository.
// ProfileStore phối hợp ghi ảnh qua file storage trước khi cập nhật Profile.
// load/save dùng throws để phân biệt dữ liệu hợp lệ với lỗi encode/decode.
// Presentation không tự truy cập key UserDefaults, nên tên key nằm trong implementation Data.
// Dữ liệu đọc ra là struct để editor có thể tạo draft độc lập.


@MainActor protocol ProfileRepository {
    func load() throws -> UserProfile
    func save(_ profile: UserProfile) throws
}
