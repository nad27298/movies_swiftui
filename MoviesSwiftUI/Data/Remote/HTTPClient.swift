//
//  HTTPClient.swift
//  MoviesSwiftUI
//
//  Created by DaoNA3 on 01/10/2026.
//

import Foundation
import Alamofire

// Adapter networking dùng Alamofire, không biết màn Movies/Detail đang hiển thị thế nào.
// Một Session được tái sử dụng, tránh tạo URLSession cho từng request.
// Generic Response cho phép cùng get decode nhiều DTO nhưng vẫn giữ kiểu dữ liệu cụ thể.
// Decodable mô tả cách đọc JSON; Sendable phù hợp với xử lý bất đồng bộ của serializer.
// validate kiểm tra HTTP trước khi chấp nhận payload như kết quả thành công.
// serializingDecodable trả công việc bất đồng bộ; await không block UI chờ mạng.
// automaticallyCancelling nối cancellation của Task với request Alamofire.
// UI nhận AppError, còn lỗi thư viện gốc được giữ để chẩn đoán mà không log API key.


@MainActor final class HTTPClient {
    private let session: Session
    private(set) var lastUnderlyingError: Error?

    // URLSessionConfiguration đặt timeout ở tầng network, không phải một Timer trong View.
    // Session được giữ trong client để tái sử dụng connection và cấu hình giữa các endpoint.
    // Không cấu hình retry tự động vì app hiện yêu cầu người dùng retry đúng phần lỗi.
    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        session = Session(configuration: configuration)
    }

    // Response là generic type caller lựa chọn, ví dụ MoviePageDTO hoặc CreditsDTO.
    // Decodable buộc type biết đọc JSON; Sendable phù hợp với kết quả qua công việc serializer.
    // Check cancellation trước khi gửi và sau khi await để không tiếp tục sử dụng kết quả đã bỏ.
    // Caller nhận value hoặc throws; không phải ghép success/failure closure cho mỗi endpoint.
    func get<Response: Decodable & Sendable>(_ url: URL, parameters: [String: String],
                                             as type: Response.Type) async throws -> Response {
        try Task.checkCancellation()
        // validate chặn status ngoài 2xx trước khi chấp nhận payload như dữ liệu thành công.
        // serializingDecodable gom response thành type đã truyền, sử dụng conformance Decodable.
        // automaticallyCancelling yêu cầu Alamofire hủy request khi Task chờ bị hủy.
        // await cho phép MainActor xử lý UI khác trong lúc chờ, không đồng nghĩa mọi dòng hàm đều chạy background.
        let response = await session.request(url, parameters: parameters)
            .validate(statusCode: 200..<300)
            .serializingDecodable(type, automaticallyCancelling: true).response
        try Task.checkCancellation()
        // Ưu tiên cancellation để không hiện lỗi mạng khi người dùng rời màn.
        // HTTP status lỗi và lỗi decode là hai nhánh khác nhau dù đều có thể nhận response từ server.
        // Không lấy localizedDescription của thư viện để log toàn bộ URL chứa key.
        // Giữ underlying error trong client và chỉ đưa AppError đã map lên Presentation.
        if let error = response.error {
            // Giữ lỗi gốc để chẩn đoán, không log URL vì query chứa API key.
            lastUnderlyingError = error
            if error.isExplicitlyCancelledError { throw CancellationError() }
            if let status = response.response?.statusCode, !(200..<300).contains(status) {
                throw AppError.http(status)
            }
            if error.isResponseSerializationError { throw AppError.decoding }
            throw AppError.connection
        }
        guard let value = response.value else { throw AppError.decoding }
        return value
    }
}
