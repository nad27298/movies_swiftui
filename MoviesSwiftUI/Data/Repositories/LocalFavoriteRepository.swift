//
//  LocalFavoriteRepository.swift
//  MoviesSwiftUI
//
//  Created by DaoNA3 on 01/10/2026.
//

import Foundation
import SwiftData

// Triển khai FavoriteRepository bằng một ModelContext riêng.
// autosaveEnabled = false buộc transaction chỉ hoàn tất tại try context.save().
// FetchDescriptor mô tả predicate/sort, gần NSFetchRequest của Core Data.
// #Predicate là macro tạo biểu thức truy vấn mà SwiftData hiểu, không phải closure lọc một mảng UI.
// Thao tác encode/fetch/mutate/save không có await, tránh xen ngang transaction.
// Lỗi gọi rollback để context trở lại dữ liệu đã lưu gần nhất.
// fetchFavorites decode snapshot và kiểm tra ID trước khi đưa value ra khỏi Data layer.
// Store mới là nơi cập nhật UI sau khi các hàm này thành công.


@MainActor final class LocalFavoriteRepository: FavoriteRepository {
    private let context: ModelContext

    // ModelContext riêng giới hạn thay đổi của repository này.
    // Tắt autosave để Save button hoặc action có mốc thành công rõ ràng.
    // Rollback của repository này không cần xóa thay đổi đang chờ của một repository khác.
    init(container: ModelContainer) {
        context = ModelContext(container)
        context.autosaveEnabled = false
    }

    // Sort bằng savedAt giảm dần, ID làm tie-breaker khi hai timestamp bằng nhau.
    // Decode movieData thành value và kiểm tra snapshot ID khớp khóa record.
    // Nếu dữ liệu local hỏng, throws lên store thay vì hiển thị danh sách rỗng như không có Favorite.
    func fetchFavorites() throws -> [FavoriteMovie] {
        try context.fetch(FetchDescriptor<FavoriteRecord>(sortBy: [SortDescriptor(\.savedAt, order: .reverse), SortDescriptor(\.movieID)])).map {
            let movie = try JSONDecoder().decode(Movie.self, from: $0.movieData)
            guard movie.id == $0.movieID, movie.id > 0 else { throw AppError.storage }
            return FavoriteMovie(movie: movie, savedAt: $0.savedAt)
        }
    }

    // Encode trước khi mutate entity để lỗi encode không tạo một record dở dang.
    // Predicate chọn đúng ID; có record thì cập nhật, chưa có thì insert.
    // context.save là mốc transaction local hoàn tất; context.rollback trong catch bỏ thay đổi chưa lưu.
    // Toàn bộ bước đồng bộ trên MainActor, không await ở giữa rồi cho action khác xen vào.
    func saveFavorite(_ favorite: FavoriteMovie) throws {
        do {
            let id = favorite.id
            let data = try JSONEncoder().encode(favorite.movie)
            let descriptor = FetchDescriptor<FavoriteRecord>(predicate: #Predicate { $0.movieID == id })
            if let record = try context.fetch(descriptor).first {
                record.movieData = data
                record.savedAt = favorite.savedAt
            } else {
                context.insert(FavoriteRecord(movieID: id, movieData: data, savedAt: favorite.savedAt))
            }
            try context.save()
        } catch {
            // Autosave bị tắt: rollback tránh ghi lại thay đổi đã báo thất bại ở lần sau.
            context.rollback()
            throw error
        }
    }

    // Xóa entity trong context mới chỉ là thay đổi pending, chưa phải dữ liệu đã xóa bền vững.
    // Chỉ sau context.save thành công thì store được bỏ row khỏi snapshot.
    // Nếu lỗi save, rollback phục hồi entity; UI vẫn giữ Favorite cũ.
    func deleteFavorite(movieID: Int) throws {
        do {
            let descriptor = FetchDescriptor<FavoriteRecord>(predicate: #Predicate { $0.movieID == movieID })
            for record in try context.fetch(descriptor) { context.delete(record) }
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}
