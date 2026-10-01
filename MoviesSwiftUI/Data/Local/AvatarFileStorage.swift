//
//  AvatarFileStorage.swift
//  MoviesSwiftUI
//
//  Created by DaoNA3 on 01/10/2026.
//

import Foundation

// Lưu bitmap avatar vào Application Support, nơi phù hợp cho dữ liệu app cần giữ.
// UserDefaults chỉ lưu tên file nên không phải chứa một blob ảnh lớn.
// Tên UUID tránh ghi đè file ảnh cũ trước khi Profile mới lưu thành công.
// Data.write(.atomic) ghi qua file tạm rồi thay thế tại đích, giảm nguy cơ file đang ghi bị dở dang.
// read/remove chỉ chấp nhận tên file đơn, không cho filename dẫn sang thư mục khác.
// ProfileStore quyết định thời điểm xóa ảnh cũ hoặc dọn ảnh mới thất bại.
// Storage này không xử lý resize UIImage hoặc quyền camera: đó là trách nhiệm Presentation.


@MainActor final class AvatarFileStorage {
    // FileManager tìm Application Support theo sandbox hiện tại, không hardcode đường dẫn máy.
    // createDirectory cho phép thư mục chưa có tại lần Save đầu tiên.
    // Hàm throws để lỗi filesystem có thể đi lên ProfileStore và UI, thay vì giả vờ ảnh đã lưu.
    private func directory() throws -> URL {
        let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                appropriateFor: nil, create: true)
        let url = base.appendingPathComponent("Avatars", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    // Tên mới mỗi lần giúp Profile vẫn trỏ ảnh cũ nếu bước Save tiếp theo thất bại.
    // .atomic giảm nguy cơ đọc một file chỉ mới ghi được một phần.
    // Chỉ trả filename sau khi write thành công; caller mới có thể lưu reference vào Profile.
    func write(_ data: Data) throws -> String {
        let filename = UUID().uuidString + ".jpg"
        try data.write(to: directory().appendingPathComponent(filename), options: .atomic)
        return filename
    }

    // read có thể nil vì không có ảnh, mất file hoặc không đọc được file.
    // UI có avatar mặc định nên không force unwrap bitmap.
    // Kiểm tra lastPathComponent hạn chế filename đi ra ngoài thư mục Avatars.
    func read(_ filename: String?) -> Data? {
        guard let filename, filename == URL(fileURLWithPath: filename).lastPathComponent,
              let directory = try? directory() else { return nil }
        return try? Data(contentsOf: directory.appendingPathComponent(filename))
    }

    func remove(_ filename: String?) {
        guard let filename, filename == URL(fileURLWithPath: filename).lastPathComponent,
              let directory = try? directory() else { return }
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(filename))
    }
}
