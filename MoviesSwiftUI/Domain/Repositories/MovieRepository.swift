//
//  MovieRepository.swift
//  MoviesSwiftUI
//
//  Created by DaoNA3 on 01/10/2026.
//

import Foundation

// Contract dữ liệu phim mà Presentation sử dụng.
// Protocol mô tả khả năng cần có, không chỉ định Alamofire, URLSession hoặc cấu trúc JSON.
// async cho phép chờ kết quả mà không block luồng UI; throws buộc caller xử lý thất bại.
// Kết quả là Domain value model, không phải DTO hoặc response của thư viện.
// MainActor xác định miền điều phối của repository app này; request network vẫn bất đồng bộ.
// Implementation RemoteMovieRepository được inject tại AppDependencies.
// Tách fetchDetail và fetchCast để ViewModel có thể retry từng phần độc lập.


@MainActor protocol MovieRepository {
    func fetchMovies(category: MovieCategory, page: Int) async throws -> MoviePage
    func fetchMovieDetail(id: Int) async throws -> MovieDetail
    func fetchCast(movieID: Int) async throws -> [CastMember]
}
