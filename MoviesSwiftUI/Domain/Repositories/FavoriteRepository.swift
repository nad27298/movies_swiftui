//
//  FavoriteRepository.swift
//  MoviesSwiftUI
//
//  Created by DaoNA3 on 01/10/2026.
//

import Foundation

// Contract đọc/lưu/xóa snapshot Favorite local.
// Caller không biết dữ liệu được lưu bằng SwiftData và không cầm ModelContext.
// Các thao tác hiện tại đồng bộ, không có await giữa một transaction local.
// throws cho phép store giữ snapshot cũ khi persistence thất bại.
// MainActor bảo đảm context của implementation được truy cập trong miền đã chọn.
// Không thêm generic CRUD vì chức năng này chỉ cần ba thao tác rõ nghĩa.


@MainActor protocol FavoriteRepository {
    func fetchFavorites() throws -> [FavoriteMovie]
    func saveFavorite(_ favorite: FavoriteMovie) throws
    func deleteFavorite(movieID: Int) throws
}
