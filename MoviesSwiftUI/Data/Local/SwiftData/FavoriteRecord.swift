//
//  FavoriteRecord.swift
//  MoviesSwiftUI
//
//  Created by DaoNA3 on 01/10/2026.
//

import Foundation
import SwiftData

// Entity lưu trữ của SwiftData, khác Movie value model mà Presentation sử dụng.
// @Model là macro sinh khả năng theo dõi/lưu các thuộc tính bằng SwiftData.
// @Attribute(.unique) xác định movieID là duy nhất trong entity, tránh Favorite trùng phim.
// movieData là JSON snapshot Movie; savedAt phục vụ thứ tự lưu gần nhất.
// Entity là class do context quản lý, nên ViewModel không nhận nó để sửa trực tiếp qua Binding.
// nonisolated dành cho conformance do framework sinh; repository vẫn giới hạn truy cập trên MainActor.
// Không suy ra entity an toàn để dùng đồng thời chỉ vì có modifier nonisolated.


// Entity có conformance do SwiftData sinh ra; repository kiểm soát truy cập trên MainActor.
@Model nonisolated final class FavoriteRecord {
    @Attribute(.unique) var movieID: Int
    var movieData: Data
    var savedAt: Date

    init(movieID: Int, movieData: Data, savedAt: Date) {
        self.movieID = movieID
        self.movieData = movieData
        self.savedAt = savedAt
    }
}
