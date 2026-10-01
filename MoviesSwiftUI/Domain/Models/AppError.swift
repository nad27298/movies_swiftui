//
//  AppError.swift
//  MoviesSwiftUI
//
//  Created by DaoNA3 on 01/10/2026.
//

import Foundation

// Các lỗi app hiểu được, độc lập với kiểu lỗi của từng thư viện.
// LocalizedError cung cấp errorDescription để error.localizedDescription trở thành thông báo có ý nghĩa.
// Enum có associated value cho HTTP status và nội dung validation.
// Không đưa AFError trực tiếp tới View; HTTPClient giữ lỗi gốc để chẩn đoán riêng.
// Cancellation được xử lý bằng CancellationError, không chuyển thành lỗi kết nối.
// Lỗi storage không được coi như danh sách rỗng hoặc thao tác Save thành công.


nonisolated enum AppError: LocalizedError, Sendable {
    case configuration, connection, http(Int), decoding, storage, invalidInput(String)
    var errorDescription: String? {
        switch self {
        case .configuration: "Chưa cấu hình TMDB API key. Xem hướng dẫn trong README."
        case .connection: "Không thể kết nối. Kiểm tra mạng rồi thử lại."
        case .http(let code): "TMDB trả lỗi HTTP \(code). Vui lòng thử lại."
        case .decoding: "Dữ liệu nhận được không đúng định dạng."
        case .storage: "Không thể đọc hoặc lưu dữ liệu trên thiết bị."
        case .invalidInput(let message): message
        }
    }
}
