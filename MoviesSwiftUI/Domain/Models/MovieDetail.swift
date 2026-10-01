//
//  MovieDetail.swift
//  MoviesSwiftUI
//
//  Created by DaoNA3 on 01/10/2026.
//

import Foundation

// Domain model của kết quả tải thông tin chi tiết.
// MovieDetail giữ Movie snapshot; dữ liệu cast được tải riêng và có state lỗi/loading riêng.
// Việc tách hai kết quả giúp request cast thất bại không xóa phần phim đã tải thành công.
// Đây là value type, không chứa SwiftUI state, Alamofire response hoặc SwiftData entity.
// Sendable/nonisolated cho phép đi qua luồng async mà không ép parsing vào MainActor.
// ViewModel chịu trách nhiệm nhận kết quả và cập nhật UI, model không tự gọi API.


// Snapshot này chỉ chứa thông tin phim; cast có request và trạng thái tải riêng.
nonisolated struct MovieDetail: Sendable {
    let movie: Movie
}
