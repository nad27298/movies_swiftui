//
//  RemoteMovieRepository.swift
//  MoviesSwiftUI
//
//  Created by DaoNA3 on 01/10/2026.
//

import Foundation

// Triển khai MovieRepository bằng TMDBService.
// Repository chuyển DTO sang Domain model để Presentation không phụ thuộc JSON.
// Kiểm tra page/id trả về để tránh dùng một response không khớp yêu cầu.
// Cast được loại ID trùng trước ForEach; cùng một id không nên tạo hai row có identity giống nhau.
// Repository không quản lý refresh/pagination state; MoviesViewModel sở hữu nextPage/generation.
// Không cache Detail như một dữ liệu offline đầy đủ trong migration này.


@MainActor final class RemoteMovieRepository: MovieRepository {
    private let service: TMDBService
    init(service: TMDBService) { self.service = service }

    // Chờ DTO, kiểm tra đúng page yêu cầu rồi map từng phim.
    // map có thể throws nếu một phần tử không có dữ liệu hợp lệ; không bỏ lỗi để trả một trang thành công giả.
    // nextPage nằm ở ViewModel, repository không tự tăng hoặc giữ state phân trang.
    func fetchMovies(category: MovieCategory, page: Int) async throws -> MoviePage {
        let dto = try await service.movies(category: category, page: page)
        guard dto.page == page, dto.totalPages >= 0 else { throw AppError.decoding }
        return MoviePage(movies: try dto.results.map(MovieMapper.movie), page: dto.page, totalPages: dto.totalPages)
    }

    func fetchMovieDetail(id: Int) async throws -> MovieDetail {
        let dto = try await service.detail(id: id)
        guard dto.id == id else { throw AppError.decoding }
        return MovieDetail(movie: try MovieMapper.movie(dto))
    }

    // Set ghi các ID đã thấy; insert(...).inserted chỉ true tại lần xuất hiện đầu.
    // filter giữ thứ tự server cho những ID hợp lệ, rồi map sang CastMember.
    // Điều này tránh hai item có cùng identity trong ForEach của SwiftUI.
    func fetchCast(movieID: Int) async throws -> [CastMember] {
        let dto = try await service.credits(id: movieID)
        var seen = Set<Int>()
        return dto.cast.filter { $0.id > 0 && seen.insert($0.id).inserted }.map(MovieMapper.cast)
    }
}
