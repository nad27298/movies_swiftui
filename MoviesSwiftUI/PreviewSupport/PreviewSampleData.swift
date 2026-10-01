//
//  PreviewSampleData.swift
//  MoviesSwiftUI
//
//  Created by DaoNA3 on 01/10/2026.
//

#if DEBUG
import Foundation

// Dữ liệu cố định để tập trung học layout, không cần API key hay kết nối TMDB.
// #if DEBUG loại các kiểu hỗ trợ Preview khỏi bản Release.
// Các model vẫn là Movie/CastMember thật của app: không tạo một model UI khác cho Preview.
// posterPath/profilePath nil khiến PosterView dùng placeholder và không tải ảnh từ mạng.
// Có cả tên dài, thiếu ngày và nội dung rỗng để bạn quan sát cách View bố trí dữ liệu.
enum PreviewSampleData {
    static let movie = Movie(
        id: 1, title: "Chuyến đi qua những vì sao",
        overview: "Một nhóm bạn bắt đầu chuyến hành trình khám phá bầu trời. Mỗi điểm dừng mang đến một câu chuyện mới về tình bạn và những lựa chọn trong cuộc sống.",
        posterPath: nil, rating: 8.5,
        releaseDate: MovieReleaseDate(year: 2026, month: 10, day: 1), isAdult: false
    )

    static let movies = [
        movie,
        Movie(id: 2, title: "Một bộ phim có tiêu đề dài để học cách bố trí chữ trên màn hình nhỏ",
              overview: "Bạn có thể tăng cỡ chữ trong Canvas để xem row có còn dễ đọc hay không.",
              posterPath: nil, rating: 7.2, releaseDate: nil, isAdult: true),
        Movie(id: 3, title: "Ngày bình yên", overview: "", posterPath: nil, rating: 6.8,
              releaseDate: MovieReleaseDate(year: 2025, month: 6, day: 15), isAdult: false)
    ]

    static let cast = [
        CastMember(id: 1, name: "Nguyễn Minh", character: "Người dẫn đường", profilePath: nil),
        CastMember(id: 2, name: "Lê An", character: "Nhà thiên văn", profilePath: nil),
        CastMember(id: 3, name: "Trần Hà", character: "Người bạn đồng hành", profilePath: nil)
    ]

    static let profile = UserProfile(
        name: "DaoNA3", birthday: MovieReleaseDate(year: 1995, month: 5, day: 15),
        email: "daona3@example.com", gender: .male
    )
}
#endif
