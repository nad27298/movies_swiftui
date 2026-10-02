//
//  FavoritesView.swift
//  MoviesSwiftUI
//
//  Created by DaoNA3 on 01/10/2026.
//

import SwiftUI

// Màn Favorite đọc snapshot local và ViewModel tìm kiếm.
// searchable nhận Binding<String>, tương ứng control search nhưng không cần delegate gõ từng ký tự.
// onChange gửi input sang pipeline Combine; onAppear reset theo hành vi app cũ.
// onDisappear hủy subscription để input cũ không áp dụng sau khi rời màn.
// NavigationSplitView chia list/detail khi rộng và dùng cùng selection khi collapse.
// Swipe action yêu cầu xác nhận trước xóa, store mới là nơi quyết định persistence thành công.
// Lỗi xóa hiển thị inline để không mở alert thứ hai trong lúc alert xác nhận đang đóng.
// Empty state phân biệt dữ liệu rỗng với lỗi chưa đọc được thư viện local.


struct FavoritesView: View {
    @Environment(MovieLibraryStore.self) private var library
    @Environment(AppRouter.self) private var router
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var model: FavoritesViewModel
    // Favorites sở hữu model Detail riêng, không dùng chung instance với tab Movies.
    // View con chỉ đọc model; callback chuyển cột không quyết định hủy request của owner này.
    @State private var detailModel: MovieDetailViewModel?
    @State private var deletingID: Int?
    @State private var actionError: String?
    private let repository: any MovieRepository

    init(repository: any MovieRepository, library: MovieLibraryStore) {
        self.repository = repository
        _model = State(initialValue: FavoritesViewModel(library: library))
    }

    var body: some View {
        @Bindable var router = router
        @Bindable var model = model
        NavigationSplitView(preferredCompactColumn: $router.favoriteCompactColumn) {
            List {
                ForEach(model.visibleFavorites) { favorite in
                    Button { router.openMovie(favorite.id, in: .favorites) } label: { MovieRow(movie: favorite.movie) }
                        .buttonStyle(.plain)
                        .swipeActions {
                            Button("Xóa", role: .destructive) { deletingID = favorite.id }
                        }
                }
            }
            .listStyle(.plain)
            .overlay {
                if !library.isLoaded {
                    ErrorStateView(message: library.loadError ?? "Chưa tải được thư viện local.") { library.load() }
                } else if model.visibleFavorites.isEmpty {
                    EmptyStateView(title: model.appliedQuery.isEmpty ? "Chưa có phim yêu thích" : "Không có kết quả",
                                   message: "Bạn có thể lưu phim từ Movies hoặc Detail.", symbol: "heart")
                }
            }
            // Binding cập nhật searchText ngay khi người dùng nhập.
            // onChange chuyển input sang subject; appliedQuery chỉ cập nhật sau debounce.
            // Nếu chỉ binding searchText rồi filter trực tiếp, sẽ không có bài học debounce ở đây.
            .searchable(text: $model.searchText, prompt: "Tìm tên phim đã lưu")
            .onChange(of: model.searchText) { _, _ in model.searchChanged() }
            .onAppear { model.reset() }
            .onDisappear { model.disappear() }
            .navigationTitle("Favorites")
            .navigationSplitViewColumnWidth(min: 320, ideal: 420, max: 560)
            .toolbar { MenuToolbar(router: router) }
        } detail: {
            if let id = router.favoriteMovieID {
                if let detailModel, detailModel.movieID == id {
                    MovieDetailView(model: detailModel).id(id)
                } else {
                    // Chờ owner cấp đúng model thay vì hiển thị Detail của selection trước.
                    LoadingStateView().navigationTitle("Chi tiết phim").navigationBarTitleDisplayMode(.inline)
                }
            } else {
                EmptyStateView(title: "Chọn phim yêu thích", symbol: "heart")
            }
        }
        // Cùng quy tắc ownership với Movies; Combine/search vẫn thuộc FavoritesViewModel.
        .onChange(of: activeDetailID, initial: true) { _, _ in synchronizeDetail() }
        .onAppear { synchronizeDetail() }
        .onDisappear {
            if activeDetailID == nil { detailModel?.cancel() }
        }
        .alert("Xóa phim yêu thích?", isPresented: Binding(get: { deletingID != nil }, set: { if !$0 { deletingID = nil } })) {
            Button("Xóa", role: .destructive) {
                actionError = nil
                if let id = deletingID {
                    do { try library.deleteFavorite(id) }
                    catch { actionError = error.localizedDescription }
                }
                deletingID = nil
            }
            Button("Hủy", role: .cancel) { deletingID = nil }
        }
        // Lỗi lưu hiện inline sau xác nhận, tránh mở alert mới trong lúc alert xóa đang đóng.
        .safeAreaInset(edge: .bottom) {
            if let actionError {
                HStack {
                    Text(actionError).font(.subheadline)
                    Spacer()
                    Button("Đóng") { self.actionError = nil }
                }
                .padding().background(.regularMaterial)
            }
        }
    }

    private var activeDetailID: Int? {
        guard router.selectedTab == .favorites else { return nil }
        // iPhone cần cột Detail đang được chọn; iPad regular cho phép hai cột cùng hiển thị.
        guard sizeClass != .compact || router.favoriteCompactColumn == .detail else { return nil }
        return router.favoriteMovieID
    }

    private func synchronizeDetail() {
        guard let id = activeDetailID else {
            detailModel?.cancel()
            return
        }
        if detailModel?.movieID != id {
            detailModel?.cancel()
            detailModel = MovieDetailViewModel(movieID: id, repository: repository)
        }
        // Model giữ snapshot khi Back; loadIfNeeded không fetch lại phần đã thành công.
        detailModel?.loadIfNeeded()
    }
}

#if DEBUG
// Store có dữ liệu mẫu trong bộ nhớ; tìm kiếm vẫn chạy Combine của ViewModel thật.
// Xóa phim trong Preview chỉ sửa mảng mẫu, không xóa Favorite đã lưu của app.
#Preview("Favorites") {
    PreviewHost { context in
        FavoritesView(repository: context.movieRepository, library: context.library)
    }
}

// Một tùy chọn seed nhỏ đủ xem empty UI, không cần thêm hệ thống mô phỏng mọi trạng thái.
#Preview("Favorites – rỗng") {
    PreviewHost(hasFavorites: false) { context in
        FavoritesView(repository: context.movieRepository, library: context.library)
    }
}
#endif
