//
//  MovieDetailViewModel.swift
//  MoviesSwiftUI
//
//  Created by DaoNA3 on 01/10/2026.
//

import Foundation
import Observation

// State của một movie ID, với hai request độc lập cho phim và cast.
// ID cố định theo initializer; Movies/Favorites sở hữu instance bằng @State ở màn navigation cha.
// Đổi phim tạo model mới; Back giữ snapshot của model hiện tại để mở lại không tải phần đã có.
// Mỗi request có task/generation/loading/error riêng nên partial failure không xóa kết quả còn lại.
// loadIfNeeded không gọi lại phần đã thành công chỉ vì View xuất hiện lại.
// Retry một phần không reload phần khác, tránh duplicate API không cần thiết.
// Cancel tăng generation trước khi hủy task để chặn cả callback và defer cũ.
// @Observable chỉ theo dõi state mà UI cần; Task được loại khỏi Observation.
// MainActor bảo đảm state được cập nhật đúng miền UI, nhưng chờ API vẫn dùng await.


@MainActor @Observable final class MovieDetailViewModel {
    let movieID: Int
    private(set) var detail: MovieDetail?
    private(set) var cast: [CastMember] = []
    private(set) var isLoadingDetail = false
    private(set) var isLoadingCast = false
    private(set) var detailError: String?
    private(set) var castError: String?
    private var hasLoadedCast = false
    private var detailGeneration = 0
    private var castGeneration = 0
    private let repository: any MovieRepository
    @ObservationIgnored private var detailTask: Task<Void, Never>?
    @ObservationIgnored private var castTask: Task<Void, Never>?

    init(movieID: Int, repository: any MovieRepository) {
        self.movieID = movieID
        self.repository = repository
    }

    // Màn navigation cha gọi hàm này khi Detail của movieID thực sự active.
    // Hàm đồng bộ chỉ khởi động hai Task rồi trả về; request bên trong vẫn await API độc lập.
    // ViewModel giữ task handle để màn cha có thể hủy theo Back/đổi phim/đổi tab.
    // Không phụ thuộc .task hoặc onDisappear của View con trong NavigationSplitView.
    // Chỉ tải phần chưa có kết quả và chưa có lỗi; lỗi có nút retry tường minh.
    // Guard trong retry chặn request trùng nếu onAppear/onChange cùng yêu cầu tải.
    func loadIfNeeded() {
        if detail == nil, detailError == nil { retryDetail() }
        if !hasLoadedCast, castError == nil { retryCast() }
    }

    // Loading và generation riêng của Detail, không sửa state cast.
    // Sau await kiểm tra cancellation và generation trước khi gán snapshot.
    // Throws ngoài cancellation được chuyển thành detailError để phần phim có thể retry độc lập.
    func retryDetail() {
        guard !isLoadingDetail else { return }
        detailGeneration += 1
        let generation = detailGeneration
        isLoadingDetail = true
        detailError = nil
        detailTask = Task { [self] in
            defer { if generation == detailGeneration { isLoadingDetail = false; detailTask = nil } }
            do {
                let value = try await repository.fetchMovieDetail(id: movieID)
                try Task.checkCancellation()
                guard generation == detailGeneration else { return }
                detail = value
            } catch is CancellationError { }
            catch {
                guard generation == detailGeneration, !Task.isCancelled else { return }
                detailError = error.localizedDescription
            }
        }
    }

    // Một mảng cast rỗng vẫn có thể là kết quả tải thành công.
    // hasLoadedCast phân biệt rỗng thành công với chưa gọi API, tránh fetch lại mỗi lần xuất hiện.
    // Generation và defer riêng giữ loading cast không bị callback cũ ghi đè.
    func retryCast() {
        guard !isLoadingCast else { return }
        castGeneration += 1
        let generation = castGeneration
        isLoadingCast = true
        castError = nil
        castTask = Task { [self] in
            defer { if generation == castGeneration { isLoadingCast = false; castTask = nil } }
            do {
                let value = try await repository.fetchCast(movieID: movieID)
                try Task.checkCancellation()
                guard generation == castGeneration else { return }
                cast = value
                hasLoadedCast = true
            } catch is CancellationError { }
            catch {
                guard generation == castGeneration, !Task.isCancelled else { return }
                castError = error.localizedDescription
            }
        }
    }

    func cancel() {
        detailGeneration += 1
        castGeneration += 1
        detailTask?.cancel()
        castTask?.cancel()
        detailTask = nil
        castTask = nil
        isLoadingDetail = false
        isLoadingCast = false
    }
}
