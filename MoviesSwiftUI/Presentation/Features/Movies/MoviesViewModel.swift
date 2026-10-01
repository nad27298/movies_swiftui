//
//  MoviesViewModel.swift
//  MoviesSwiftUI
//
//  Created by DaoNA3 on 01/10/2026.
//

import Foundation
import Observation

// State owner của danh sách Movies, không dựng View và không cầm navigation controller.
// movies là phim đã tải trước filter; visibleMovies là dữ liệu tính ra để hiển thị.
// activeSettings mô tả bộ dữ liệu đang thấy; desiredSettings là lựa chọn cần tải tiếp theo.
// Revision phân biệt Save Settings mới với dữ liệu đang có, kể cả giá trị settings giống nhau.
// nextPage chỉ tăng sau thành công; totalPages từ server quyết định điểm dừng.
// Loading đầu, refresh và load-more tách nhau để UI không xóa row cũ khi chỉ tải thêm.
// Task cancellation giảm công việc, generation chặn response/defer cũ ghi đè state mới.
// @Observable cập nhật View theo state; requestTask không phải dữ liệu UI nên được ObservationIgnored.
// MainActor giữ cập nhật state tuần tự; await mạng cho phép actor làm công việc khác trong lúc chờ.


@MainActor @Observable final class MoviesViewModel {
    enum DisplayMode: String, CaseIterable { case list, grid }
    var displayMode: DisplayMode = .list
    private(set) var movies: [Movie] = []
    private(set) var isLoading = false
    private(set) var isRefreshing = false
    private(set) var isLoadingMore = false
    private(set) var errorMessage: String?
    private(set) var loadMoreError: String?
    private(set) var nextPage = 1
    private(set) var totalPages = 0
    private(set) var hasLoaded = false
    // active mô tả movies hiện có; desired mô tả yêu cầu người dùng mới nhất.
    // Khi refresh lỗi, row cũ vẫn dùng filter/sort của activeSettings, không giả vờ là dữ liệu mới.
    // appliedRevision được ghi sau response thành công; desiredRevision đổi ngay khi nhận yêu cầu mới.
    private var activeSettings = MovieSettings()
    private var appliedRevision = -1
    private var desiredRevision = -1
    private var desiredSettings = MovieSettings()
    private var isVisible = false
    private var requestGeneration = 0
    private let repository: any MovieRepository
    @ObservationIgnored private var requestTask: Task<Void, Never>?

    init(repository: any MovieRepository) { self.repository = repository }

    // Không tải trang tiếp của bộ dữ liệu thuộc revision cũ trong lúc đang cần một settings mới.
    // nextPage <= totalPages dựa metadata server, không dựa số row sau filter.
    // Guard trong loadMore tiếp tục kiểm tra loading dù UI đang hiện nút tải tiếp.
    var canLoadMore: Bool { hasLoaded && appliedRevision == desiredRevision && nextPage <= totalPages }

    // Computed property lọc từ bộ dữ liệu gốc, không làm mất các phim bị filter trong mảng movies.
    // Khi chưa đặt ngưỡng ngày cụ thể, giữ phim chưa có ngày; khi ngưỡng active, phim thiếu ngày không thể đạt filter.
    // Sort dùng vị trí ban đầu làm tie-breaker để kết quả cùng rating/ngày không nhảy thứ tự.
    // Giá trị tính ra không được lưu thêm thành một mảng mutable cần đồng bộ thủ công.
    var visibleMovies: [Movie] {
        let filtered = movies.filter {
            $0.rating >= activeSettings.minimumRating &&
            (activeSettings.minimumReleaseDate == .minimum || ($0.releaseDate.map { $0 >= activeSettings.minimumReleaseDate } ?? false))
        }
        // Dùng index server làm tie-breaker, không dùng comparator chỉ trả 0/1 như app cũ.
        return filtered.enumerated().sorted { lhs, rhs in
            switch activeSettings.sort {
            case .none: return lhs.offset < rhs.offset
            case .ratingDescending:
                return lhs.element.rating == rhs.element.rating ? lhs.offset < rhs.offset : lhs.element.rating > rhs.element.rating
            case .releaseDateDescending:
                let left = lhs.element.releaseDate
                let right = rhs.element.releaseDate
                if left == right { return lhs.offset < rhs.offset }
                guard let left else { return false }
                guard let right else { return true }
                return left > right
            }
        }.map(\.element)
    }

    // Đánh dấu list đang hiển thị và ghi yêu cầu settings hiện tại.
    // Nếu request cùng settings/revision đang chạy, chờ nó thay vì hủy rồi gửi một request giống hệt.
    // Chỉ refresh khi chưa load được hoặc dữ liệu thuộc revision khác.
    // Trở lại từ Detail với revision không đổi không bắt buộc tải lại Movies.
    func appear(settings: MovieSettings, revision: Int) async {
        isVisible = true
        let matchesCurrentRequest = desiredRevision == revision && desiredSettings == settings
        desiredSettings = settings
        desiredRevision = revision
        if matchesCurrentRequest, isLoading || isRefreshing {
            await requestTask?.value
            return
        }
        if !hasLoaded || appliedRevision != revision { await refresh(settings: settings, revision: revision) }
    }

    // Nhận revision mới, hủy thế hệ request cũ trước khi cân nhắc tải page 1.
    // Nếu list đang offscreen, chỉ giữ desired settings; appear sẽ tải khi cần.
    // Không đổi movie selection hoặc pop Detail chỉ vì Settings được Save.
    func settingsChanged(_ settings: MovieSettings, revision: Int) {
        desiredSettings = settings
        desiredRevision = revision
        cancel()
        if isVisible { startFirstPage(settings: settings, revision: revision) }
    }

    func disappear() {
        isVisible = false
        cancel()
    }

    func refresh(settings: MovieSettings, revision: Int) async {
        desiredSettings = settings
        desiredRevision = revision
        startFirstPage(settings: settings, revision: revision)
        await requestTask?.value
    }

    func retry() { startFirstPage(settings: desiredSettings, revision: desiredRevision) }

    // Refresh bắt đầu một generation mới, giữ movies cũ tới khi có page 1 hợp lệ.
    // Phân biệt spinner initial với refresh bằng hasLoaded.
    // Closure Task đọc một bản settings/revision của yêu cầu này, không lấy giá trị đã bị đổi khi await xong.
    // Mỗi cập nhật kết quả/defer phải khớp generation hiện tại.
    private func startFirstPage(settings: MovieSettings, revision: Int) {
        cancel()
        let generation = requestGeneration
        isLoading = !hasLoaded
        isRefreshing = hasLoaded
        errorMessage = nil
        loadMoreError = nil
        requestTask = Task { [self] in
            // defer luôn chạy khi Task kết thúc, kể cả throws/cancellation.
            // Nếu task cũ bị hủy trong khi request mới đã chạy, defer cũ không được tắt loading mới hoặc xóa task mới.
            // Vì vậy kiểm tra generation trong defer cũng quan trọng như kiểm tra trước gán dữ liệu.
            defer {
                if generation == requestGeneration {
                    isLoading = false
                    isRefreshing = false
                    requestTask = nil
                }
            }
            do {
                let result = try await repository.fetchMovies(category: settings.category, page: 1)
                try Task.checkCancellation()
                guard generation == requestGeneration else { return }
                var seen = Set<Int>()
                movies = result.movies.filter { seen.insert($0.id).inserted }
                activeSettings = settings
                appliedRevision = revision
                totalPages = result.totalPages
                nextPage = 2
                hasLoaded = true
            } catch is CancellationError { }
            catch {
                guard generation == requestGeneration, !Task.isCancelled else { return }
                errorMessage = error.localizedDescription
            }
        }
    }

    // Guard nhiều điều kiện vì onAppear của row có thể gọi liên tiếp khi SwiftUI cập nhật layout.
    // Chụp page/category/generation trước await để request gắn với đúng bộ dữ liệu.
    // Chỉ append ID chưa có và chỉ tăng nextPage sau thành công.
    // Lỗi giữ nguyên page cần tải, nên Retry không nhảy mất một trang.
    func loadMore() {
        guard canLoadMore, !isLoading, !isRefreshing, !isLoadingMore, appliedRevision == desiredRevision else { return }
        let page = nextPage
        let generation = requestGeneration
        let category = activeSettings.category
        isLoadingMore = true
        loadMoreError = nil
        requestTask = Task { [self] in
            defer {
                if generation == requestGeneration {
                    isLoadingMore = false
                    requestTask = nil
                }
            }
            do {
                let result = try await repository.fetchMovies(category: category, page: page)
                try Task.checkCancellation()
                guard generation == requestGeneration else { return }
                var seen = Set(movies.map(\.id))
                movies.append(contentsOf: result.movies.filter { seen.insert($0.id).inserted })
                totalPages = result.totalPages
                nextPage = page + 1
            } catch is CancellationError { }
            catch {
                guard generation == requestGeneration, !Task.isCancelled else { return }
                loadMoreError = error.localizedDescription
            }
        }
    }

    // Tăng generation trước cancel để mọi callback cũ trở thành không hợp lệ ngay lập tức.
    // Task cancellation là cooperative: công việc có thể đã trả kết quả gần thời điểm cancel.
    // Reset loading cho thế hệ bị bỏ; request mới tự bật loading tương ứng.
    // Không xóa movies/hasLoaded để UI có thể giữ dữ liệu cũ và quay lại không fetch vô cớ.
    private func cancel() {
        // Hủy request giảm công việc; generation vẫn cần để chặn callback cũ tới muộn.
        requestGeneration += 1
        requestTask?.cancel()
        requestTask = nil
        isLoading = false
        isRefreshing = false
        isLoadingMore = false
    }
}
