//
//  MovieMapper.swift
//  MoviesSwiftUI
//
//  Created by DaoNA3 on 01/10/2026.
//

import Foundation

// Mapper là ranh giới giữa hình dạng JSON và dữ liệu mà app sử dụng.
// Ở đây kiểm tra ID/rating, đổi release_date thành ngày lịch và đặt fallback cho trường optional.
// Không để View tự xử lý tên snake_case hoặc giá trị null của server ở mọi màn.
// Một dữ liệu bắt buộc không hợp lệ throws, thay vì âm thầm biến toàn bộ response thành thành công.
// Mapper chỉ biến đổi value, không gọi API, không lưu database và không cập nhật loading.
// nonisolated phù hợp vì không chạm state MainActor hoặc framework UI.


nonisolated enum MovieMapper {
    // Kiểm tra giá trị bắt buộc trước khi dựng Movie value hợp lệ.
    // Optional rating dùng 0, còn NaN/infinity là dữ liệu không thể dùng để sort/hiển thị nên throws.
    // Clamp điểm trong 0...10 và giữ ảnh/ngày optional thay vì force unwrap dữ liệu server.
    // Mapper giữ nguyên ý nghĩa Domain, không có action Favorite hoặc state loading.
    static func movie(_ dto: MovieDTO) throws -> Movie {
        guard dto.id > 0 else { throw AppError.decoding }
        let rating = dto.voteAverage ?? 0
        guard rating.isFinite else { throw AppError.decoding }
        return Movie(id: dto.id, title: dto.title ?? "Chưa có tên phim", overview: dto.overview ?? "",
                     posterPath: dto.posterPath, rating: min(10, max(0, rating)),
                     releaseDate: MovieReleaseDate(apiValue: dto.releaseDate), isAdult: dto.adult ?? false)
    }

    static func cast(_ dto: CastDTO) -> CastMember {
        CastMember(id: dto.id, name: dto.name ?? "Chưa có tên", character: dto.character ?? "", profilePath: dto.profilePath)
    }
}
