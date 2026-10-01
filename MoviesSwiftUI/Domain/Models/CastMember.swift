//
//  CastMember.swift
//  MoviesSwiftUI
//
//  Created by DaoNA3 on 01/10/2026.
//

import Foundation

// Thông tin diễn viên sau khi mapper chuyển JSON thành dữ liệu app.
// id phục vụ ForEach; name và character có ý nghĩa khác nhau: tên người và vai diễn.
// profilePath là đường dẫn ảnh tương đối của TMDB, có thể nil nếu server không có ảnh.
// Model không tự nối URL/tải ảnh; PosterView nhận đường dẫn để dựng giao diện.
// Không đưa crew vào model này vì API flow hiện tại chỉ sử dụng mảng cast.
// Sendable phù hợp vì tất cả thuộc tính đều là value không chia sẻ state mutable.


nonisolated struct CastMember: Identifiable, Sendable {
    let id: Int
    let name: String
    let character: String
    let profilePath: String?
}
