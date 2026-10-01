//
//  TMDBService.swift
//  MoviesSwiftUI
//
//  Created by DaoNA3 on 01/10/2026.
//

import Foundation

// Mô tả các endpoint và tham số TMDB cụ thể.
// HTTPClient lo request/serializer; TMDBService lo path, api_key và page.
// Key lấy từ bundle sau khi xcconfig/Info.plist được Xcode thay build setting.
// Thiếu key/placeholder là lỗi cấu hình; không gửi request để rồi nhầm với lỗi mạng.
// Không gọi endpoint tìm kiếm vì app chỉ lấy danh sách category như bản mẫu.
// Các hàm trả DTO, chưa phải model app; repository và mapper thực hiện bước chuyển đổi.
// Không log URL hoàn chỉnh vì query chứa api_key.


@MainActor final class TMDBService {
    private let client: HTTPClient
    private let baseURL = URL(string: "https://api.themoviedb.org/3/movie/")!
    private let apiKey: String

    // Dependency client đi qua initializer; bundle cung cấp cấu hình riêng của bản build.
    // trimming loại khoảng trắng vô tình có trong file xcconfig.
    // Không hardcode key trong source Swift hoặc yêu cầu View tự nối tham số api_key.
    init(client: HTTPClient, bundle: Bundle = .main) {
        self.client = client
        apiKey = (bundle.object(forInfoDictionaryKey: "TMDBAPIKey") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Hàm helper dùng chung giữ cấu hình query nhất quán giữa ba endpoint.
    // Chuỗi build setting chưa được thay hoặc mẫu YOUR_ không phải key dùng được.
    // page chỉ thêm cho request danh sách; Detail/Credits không gửi một page không có ý nghĩa.
    private func parameters(page: Int? = nil) throws -> [String: String] {
        guard !apiKey.isEmpty, !apiKey.contains("$("), !apiKey.contains("YOUR_") else { throw AppError.configuration }
        var parameters = ["api_key": apiKey]
        if let page { parameters["page"] = String(page) }
        return parameters
    }

    func movies(category: MovieCategory, page: Int) async throws -> MoviePageDTO {
        try await client.get(baseURL.appendingPathComponent(category.rawValue),
                             parameters: parameters(page: page), as: MoviePageDTO.self)
    }

    func detail(id: Int) async throws -> MovieDTO {
        try await client.get(baseURL.appendingPathComponent(String(id)), parameters: parameters(), as: MovieDTO.self)
    }

    func credits(id: Int) async throws -> CreditsDTO {
        try await client.get(baseURL.appendingPathComponent("\(id)/credits"), parameters: parameters(), as: CreditsDTO.self)
    }
}
