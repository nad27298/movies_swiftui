//
//  MoviesView.swift
//  MoviesSwiftUI
//
//  Created by DaoNA3 on 01/10/2026.
//

import SwiftUI

// Màn SwiftUI dựng UI từ MoviesViewModel và các shared stores.
// @State sở hữu instance model, @Environment đọc library/settings/router do AppRoot inject.
// @Bindable trong body tạo Binding tới thuộc tính observable cho navigation container.
// NavigationSplitView thay vai trò UISplitViewController, tự collapse khi không gian hẹp.
// List và LazyVGrid gần UITableView/UICollectionView, nhưng row được khai báo bằng ForEach.
// Identity dựa movie.id giúp SwiftUI đối chiếu row cũ/mới, không dùng index làm danh tính phim.
// .task bắt đầu công việc tại lifecycle; refreshable nối gesture refresh với hàm async.
// onChange chỉ phản ứng revision mới; onDisappear yêu cầu model hủy request không cần nữa.
// Button gửi hành động tới model/store/router, không trực tiếp gọi Alamofire hoặc ModelContext.


struct MoviesView: View {
    @Environment(MovieLibraryStore.self) private var library
    @Environment(SettingsStore.self) private var settings
    @Environment(AppRouter.self) private var router
    @Environment(\.horizontalSizeClass) private var sizeClass
    // @State giữ instance qua những lần body được tính lại; @Observable theo dõi thuộc tính được đọc.
    // State giữ reference tới ViewModel chứ không biến mỗi property của model thành State riêng.
    // State gắn với identity của View; initializer có thể được gọi lại nhưng state đã sở hữu vẫn được SwiftUI giữ.
    // Điều này không bảo đảm dữ liệu sống mãi nếu cả View bị tháo/identity đổi.
    @State private var model: MoviesViewModel
    // Owner nằm ở màn navigation cha để việc View con đổi identity/chuyển cột không hủy dữ liệu.
    // Giữ một model cho phim hiện tại; đổi phim thay model, Back chỉ hủy request còn chạy.
    @State private var detailModel: MovieDetailViewModel?
    @State private var actionError: String?
    private let repository: any MovieRepository

    init(repository: any MovieRepository) {
        self.repository = repository
        _model = State(initialValue: MoviesViewModel(repository: repository))
    }

    var body: some View {
        // Object Environment tự observable khi body đọc thuộc tính, nhưng cần @Bindable để tạo $property.
        // Binding compact column cho phép hệ thống và router cùng đọc/ghi cột đang hiện trên màn hẹp.
        // Đây là binding hai chiều vào một nguồn state, không phải closure chỉ gửi sự kiện một chiều.
        @Bindable var router = router
        NavigationSplitView(preferredCompactColumn: $router.homeCompactColumn) {
            browser
                .navigationTitle("Movies")
                .navigationSplitViewColumnWidth(min: 320, ideal: 420, max: 560)
                .toolbar {
                    MenuToolbar(router: router)
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            model.displayMode = model.displayMode == .list ? .grid : .list
                        } label: { Image(systemName: model.displayMode == .list ? "square.grid.2x2" : "list.bullet") }
                        .accessibilityLabel("Đổi kiểu danh sách hoặc lưới")
                    }
                }
                // Lifecycle task yêu cầu model tải nếu cần; logic guard vẫn nằm ở ViewModel.
                // Không thay .task bằng lời gọi trong body vì body có thể chạy nhiều lần theo loading/Favorite.
                // onDisappear yêu cầu hủy công việc khi list không còn cần request.
                .task { await model.appear(settings: settings.appliedSettings, revision: settings.revision) }
                .onDisappear { model.disappear() }
        } detail: {
            if let id = router.homeMovieID {
                if let detailModel, detailModel.movieID == id {
                    MovieDetailView(model: detailModel).id(id)
                } else {
                    // Selection có thể render trước callback tạo model; không hiển thị snapshot phim cũ.
                    LoadingStateView().navigationTitle("Chi tiết phim").navigationBarTitleDisplayMode(.inline)
                }
            } else {
                EmptyStateView(title: "Chọn một bộ phim", message: "Thông tin chi tiết sẽ hiển thị tại đây.")
            }
        }
        // Quan sát navigation trên cả container, không dựa vào onDisappear của View Detail con.
        // initial xử lý cả route có sẵn; onAppear đồng bộ lại khi quay về tab/container.
        .onChange(of: activeDetailID, initial: true) { _, _ in synchronizeDetail() }
        .onAppear { synchronizeDetail() }
        .onDisappear {
            // Callback biến mất chỉ hủy nếu router/layout xác nhận Detail không còn active.
            // Sheet hoặc một lần chuyển cột không được tự coi là thao tác Back.
            if activeDetailID == nil { detailModel?.cancel() }
        }
        .onChange(of: settings.revision) { _, revision in
            model.settingsChanged(settings.appliedSettings, revision: revision)
        }
        .messageAlert($actionError)
    }

    private var activeDetailID: Int? {
        guard router.selectedTab == .movies else { return nil }
        // Compact chỉ hiện một cột; Back đổi preferredCompactColumn về sidebar.
        // Regular có thể hiện danh sách và Detail cùng lúc nên không dùng cột compact làm điều kiện.
        guard sizeClass != .compact || router.homeCompactColumn == .detail else { return nil }
        return router.homeMovieID
    }

    private func synchronizeDetail() {
        guard let id = activeDetailID else {
            // Không xóa model/snapshot: mở lại cùng phim chỉ tải phần còn thiếu.
            detailModel?.cancel()
            return
        }
        if detailModel?.movieID != id {
            detailModel?.cancel()
            detailModel = MovieDetailViewModel(movieID: id, repository: repository)
        }
        // Hàm khởi động task đồng bộ; guard trong model chống onAppear/onChange gọi trùng.
        detailModel?.loadIfNeeded()
    }

    @ViewBuilder private var browser: some View {
        if model.isLoading {
            LoadingStateView()
        } else if !model.hasLoaded, let error = model.errorMessage {
            ErrorStateView(message: error, retry: model.retry)
        } else if model.displayMode == .list {
            // List đảm nhiệm vai trò UITableView; không có dataSource/reloadData thủ công.
            List {
                statusHeader
                ForEach(model.visibleMovies) { movie in
                    HStack {
                        Button { router.openMovie(movie.id) } label: { MovieRow(movie: movie) }
                            .buttonStyle(.plain)
                        Button { toggleFavorite(movie) } label: {
                            Image(systemName: library.isFavorite(movie.id) ? "heart.fill" : "heart")
                                .frame(minWidth: 44, minHeight: 44)
                        }
                        .buttonStyle(.borderless).disabled(!library.isLoaded)
                        .accessibilityLabel(library.isFavorite(movie.id) ? "Bỏ phim yêu thích" : "Lưu phim yêu thích")
                    }
                    // onAppear của row là tín hiệu row xuất hiện, không phải bằng chứng người dùng chỉ tới đó một lần.
                    // ViewModel phải guard để nhiều tín hiệu không tạo nhiều request cùng trang.
                    // Chỉ row cuối của danh sách đang thấy mới được dùng làm tín hiệu tự tải thêm.
                    .onAppear { loadMoreIfLast(movie) }
                }
                paginationFooter
            }
            .listStyle(.plain)
            .refreshable { await model.refresh(settings: settings.appliedSettings, revision: settings.revision) }
        } else {
            ScrollView {
                VStack(spacing: 16) {
                    statusHeader
                    // LazyVGrid gần UICollectionView; cột adaptive theo không gian, không theo tên thiết bị.
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: sizeClass == .compact ? 145 : 170), spacing: 16)], spacing: 20) {
                        ForEach(model.visibleMovies) { movie in
                            Button { router.openMovie(movie.id) } label: { MovieGridItem(movie: movie) }
                                .buttonStyle(.plain)
                                .onAppear { loadMoreIfLast(movie) }
                        }
                    }
                    paginationFooter
                }
                .padding()
            }
            .refreshable { await model.refresh(settings: settings.appliedSettings, revision: settings.revision) }
        }
    }

    @ViewBuilder private var statusHeader: some View {
        if let error = model.errorMessage { ErrorStateView(message: error, retry: model.retry) }
        if !library.isLoaded {
            ErrorStateView(message: library.loadError ?? "Chưa tải được dữ liệu đã lưu.") { library.load() }
        }
        if model.isRefreshing { ProgressView("Đang làm mới…") }
        if model.hasLoaded, model.visibleMovies.isEmpty {
            Text(model.canLoadMore ? "Chưa có phim phù hợp trong các trang đã tải." : "Không có phim phù hợp.")
                .foregroundStyle(.secondary).padding()
        }
    }

    // @ViewBuilder cho phép if/else trả các kiểu View khác nhau trong một computed property.
    // Mỗi nhánh mô tả UI của một trạng thái; không phải tạo/sửa subview UIKit bằng tay.
    // Trang bị filter hết vẫn có nút tải tiếp, nhưng không tự vòng lặp tải toàn bộ server.
    @ViewBuilder private var paginationFooter: some View {
        if model.isLoadingMore {
            ProgressView("Đang tải thêm…").frame(maxWidth: .infinity)
        } else if let error = model.loadMoreError {
            ErrorStateView(message: error, retry: model.loadMore)
        } else if model.canLoadMore {
            Button("Tải thêm phim", action: model.loadMore).frame(maxWidth: .infinity)
                .disabled(model.isRefreshing || model.isLoading)
        }
    }

    private func loadMoreIfLast(_ movie: Movie) {
        // Không tự vượt qua trang bị filter hết; nút footer cho người dùng tải tiếp.
        if model.visibleMovies.last?.id == movie.id, model.loadMoreError == nil { model.loadMore() }
    }

    private func toggleFavorite(_ movie: Movie) {
        do { try library.toggleFavorite(movie) }
        catch { actionError = error.localizedDescription }
    }
}

#if DEBUG
// PreviewHost cấp store/router mẫu; .task vẫn tải qua repository mẫu của context.
// Có thể bấm nút list/grid, chọn phim và thử Favorite trong chế độ tương tác của Canvas.
// Đây là Preview một màn, không khởi tạo bootstrap hoặc toàn bộ tab của app.
#Preview("Movies") {
    PreviewHost { context in
        MoviesView(repository: context.movieRepository)
    }
}
#endif
