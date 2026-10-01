//
//  MovieSettings.swift
//  MoviesSwiftUI
//
//  Created by DaoNA3 on 01/10/2026.
//

import Foundation

// Các lựa chọn nghiệp vụ của màn Settings và danh sách Movies.
// Raw value MovieCategory trùng segment URL của TMDB; title là nhãn để người học dễ đối chiếu.
// CaseIterable cung cấp allCases cho Picker, Identifiable cung cấp id cho ForEach.
// Hashable cho phép dùng enum làm selection/tag; Codable lưu được lựa chọn vào UserDefaults.
// MovieSettings là struct nên tạo draft không chia sẻ biến mutable với settings đã áp dụng.
// Filter/sort của app chạy trên phim đã tải, không phải bộ lọc toàn bộ database TMDB.
// Default minimumReleaseDate biểu thị trạng thái chưa đặt một ngưỡng ngày cụ thể hơn.
// MainActor không cần bao quanh value model này; store mới là nơi quản lý việc cập nhật UI.


nonisolated enum MovieCategory: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case popular, topRated = "top_rated", upcoming, nowPlaying = "now_playing"
    var id: String { rawValue }
    var title: String {
        switch self {
        case .popular: "Popular"
        case .topRated: "Top Rated"
        case .upcoming: "Upcoming"
        case .nowPlaying: "Now Playing"
        }
    }
}

nonisolated enum MovieSort: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case none, releaseDateDescending, ratingDescending
    var id: String { rawValue }
    var title: String {
        switch self {
        case .none: "Không sắp xếp"
        case .releaseDateDescending: "Ngày phát hành giảm dần"
        case .ratingDescending: "Điểm giảm dần"
        }
    }
}

nonisolated struct MovieSettings: Codable, Equatable, Sendable {
    var category: MovieCategory = .popular
    var minimumRating: Double = 0
    var minimumReleaseDate: MovieReleaseDate = .minimum
    var sort: MovieSort = .none
}
