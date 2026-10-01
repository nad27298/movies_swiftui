//
//  MoviePage.swift
//  MoviesSwiftUI
//
//  Created by DaoNA3 on 01/10/2026.
//

import Foundation

// Kết quả một trang API, gồm phim và metadata phân trang.
// page là trang server thực sự trả về; totalPages là giới hạn để dừng load-more.
// Không dùng số lượng row sau filter để kết luận server đã hết trang.
// Một trang có thể chứa phim nhưng UI lọc hết; app vẫn có thể tải trang tiếp theo.
// ViewModel chỉ tăng nextPage sau khi kết quả của trang hiện tại thành công và còn hợp lệ.
// Model này không chứa loading/error vì đó là state của màn Movies.


nonisolated struct MoviePage: Sendable {
    let movies: [Movie]
    let page: Int
    let totalPages: Int
}
