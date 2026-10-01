//
//  UserProfile.swift
//  MoviesSwiftUI
//
//  Created by DaoNA3 on 01/10/2026.
//

import Foundation

// Profile là dữ liệu đã lưu hoặc bản draft được sao chép để chỉnh sửa.
// Dùng enum giới tính để tránh một Bool mà true/false không nói rõ ý nghĩa.
// Ngày sinh dùng ngày lịch; avatarFilename chỉ là tên file, không chứa bitmap trong UserDefaults.
// Codable cho phép encode/decode toàn bộ Profile thành Data bằng JSONEncoder/JSONDecoder.
// Giá trị mặc định không có nghĩa người dùng đã điền thông tin hợp lệ.
// ProfileEditViewModel kiểm tra dữ liệu trước Save; ProfileStore chỉ công bố dữ liệu sau lưu.
// Ảnh hiện tại được đọc qua AvatarFileStorage, không phải trách nhiệm của Domain model.


nonisolated enum ProfileGender: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case female, male
    var id: String { rawValue }
    var title: String { self == .female ? "Female" : "Male" }
}

nonisolated struct UserProfile: Codable, Equatable, Sendable {
    var name = ""
    var birthday: MovieReleaseDate?
    var email = ""
    var gender: ProfileGender = .female
    var avatarFilename: String?
}
