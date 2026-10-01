//
//  TMDBDTO.swift
//  MoviesSwiftUI
//
//  Created by DaoNA3 on 01/10/2026.
//

import Foundation

// DTO phản ánh JSON của server, không chứa state hoặc hàm điều khiển UI.
// Decodable sinh cách đọc JSON từ tên thuộc tính và CodingKeys.
// CodingKeys nối posterPath/voteAverage với poster_path/vote_average của TMDB.
// Optional biểu thị server có thể thiếu/null một trường; mapper quyết định fallback cho app.
// Các trường cấu trúc bắt buộc như results/page/total_pages không optional để response sai trở thành lỗi.
// nonisolated tránh actor isolation mặc định của target áp vào conformance decode.
// Sendable cho phép kết quả value đi qua serializer/task; không dùng @Observable để parse dữ liệu.
// Đây vẫn là kỹ thuật Codable dùng được trong UIKit Swift, không phải cơ chế riêng của SwiftUI.


// DTO là cấu trúc JSON của server. nonisolated + Sendable cho phép serializer xử lý
// ngoài MainActor; @Observable chỉ dùng cho state UI, không dùng để parse JSON.
nonisolated struct MovieDTO: Decodable, Sendable {
    let id: Int
    let title: String?
    let overview: String?
    let posterPath: String?
    let voteAverage: Double?
    let releaseDate: String?
    let adult: Bool?

    // Tên case bên trái là thuộc tính Swift; raw value bên phải là key JSON chính xác.
    // Các key không đổi tên chỉ cần khai báo case, không lặp lại raw value.
    // Synthesized Decodable dùng danh sách này, không phải property wrapper của SwiftUI.
    enum CodingKeys: String, CodingKey {
        case id, title, overview, adult
        case posterPath = "poster_path"
        case voteAverage = "vote_average"
        case releaseDate = "release_date"
    }
}

nonisolated struct MoviePageDTO: Decodable, Sendable {
    let results: [MovieDTO]
    let page: Int
    let totalPages: Int
    enum CodingKeys: String, CodingKey {
        case results, page
        case totalPages = "total_pages"
    }
}

nonisolated struct CreditsDTO: Decodable, Sendable {
    let cast: [CastDTO]
}

nonisolated struct CastDTO: Decodable, Sendable {
    let id: Int
    let name: String?
    let character: String?
    let profilePath: String?
    enum CodingKeys: String, CodingKey {
        case id, name, character
        case profilePath = "profile_path"
    }
}
