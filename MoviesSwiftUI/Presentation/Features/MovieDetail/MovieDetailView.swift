//
//  MovieDetailView.swift
//  MoviesSwiftUI
//
//  Created by DaoNA3 on 01/10/2026.
//

import SwiftUI

// Màn Detail nhận ID và repository, rồi sở hữu ViewModel bằng @State.
// Thư viện Favorite/Reminder dùng chung được đọc từ Environment, không sao chép thành bool cục bộ.
// .task yêu cầu tải khi xuất hiện, onDisappear hủy công việc của màn.
// ViewThatFits thử bố cục ngang rồi dọc theo không gian và cỡ chữ, không chỉ dựa tên thiết bị.
// Thông tin phim và cast hiển thị state riêng, nên API một phần lỗi không che toàn bộ màn.
// Nút Favorite gọi store; nút Reminder gửi snapshot cho router mở editor tại AppRoot.
// Snapshot chưa tải được thì không cho thao tác cần dữ liệu hợp lệ.
// ScrollView và các stack khai báo layout, không cần constraint/reloadData như UIKit.


struct MovieDetailView: View {
    @Environment(MovieLibraryStore.self) private var library
    @Environment(AppRouter.self) private var router
    @State private var model: MovieDetailViewModel
    @State private var actionError: String?

    init(movieID: Int, repository: any MovieRepository) {
        _model = State(initialValue: MovieDetailViewModel(movieID: movieID, repository: repository))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let movie = model.detail?.movie {
                    // ViewThatFits chọn bố cục vừa không gian, kể cả khi Dynamic Type lớn.
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 20) {
                            PosterView(path: movie.posterPath, width: 130, height: 195)
                            movieInformation(movie).fixedSize(horizontal: true, vertical: false)
                        }
                        VStack(alignment: .leading, spacing: 16) {
                            PosterView(path: movie.posterPath, width: 150, height: 225)
                            movieInformation(movie)
                        }
                    }
                    Text(movie.overview.isEmpty ? "Chưa có nội dung giới thiệu." : movie.overview)
                    // Truyền Movie snapshot đã tải hợp lệ làm item của sheet.
                    // Router là owner presentation nên notification có thể đóng editor và chờ onDismiss trước khi route.
                    // Không mở sheet bằng một Bool độc lập rồi cố tìm lại dữ liệu phim sau đó.
                    Button { router.reminderMovie = movie } label: { Label("Đặt lịch nhắc", systemImage: "bell") }
                        .buttonStyle(.borderedProminent)
                        .disabled(!library.isLoaded || library.isReminderBusy || router.isPresentationDismissing)
                    if let reminder = library.reminder(for: movie.id) {
                        Text("Lịch đã lưu: \(reminder.scheduledAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.subheadline).foregroundStyle(.secondary)
                        if reminder.scheduledAt > Date(), library.scheduleStatuses[movie.id] != .scheduled {
                            Text("Chưa có thông báo hệ thống khớp với lịch này.").font(.caption).foregroundStyle(.orange)
                        }
                    }
                } else if model.isLoadingDetail {
                    LoadingStateView()
                } else if let error = model.detailError {
                    ErrorStateView(message: error, retry: model.retryDetail)
                }

                Divider()
                Text("Diễn viên").font(.title3).bold()
                if model.isLoadingCast {
                    LoadingStateView()
                } else if let error = model.castError {
                    ErrorStateView(message: error, retry: model.retryCast)
                } else if model.cast.isEmpty {
                    Text("Chưa có thông tin diễn viên.").foregroundStyle(.secondary)
                } else {
                    CastRow(members: model.cast)
                }
                if !library.isLoaded {
                    ErrorStateView(message: library.loadError ?? "Chưa tải được thư viện local.") { library.load() }
                }
            }
            .padding().frame(maxWidth: AppTheme.contentWidth, alignment: .leading).frame(maxWidth: .infinity)
        }
        .navigationTitle("Chi tiết phim")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.loadIfNeeded() }
        .onDisappear { model.cancel() }
        .messageAlert($actionError)
    }

    private func movieInformation(_ movie: Movie) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(movie.title).font(.title2).bold()
            Text(movie.releaseDate?.displayText ?? "Chưa có ngày phát hành").foregroundStyle(.secondary)
            Label(movie.ratingText, systemImage: "star.fill").foregroundStyle(AppTheme.accent)
            if movie.isAdult { Text("Adult").foregroundStyle(.red) }
            Button {
                do { try library.toggleFavorite(movie) }
                catch { actionError = error.localizedDescription }
            } label: {
                Label(library.isFavorite(movie.id) ? "Bỏ yêu thích" : "Yêu thích",
                      systemImage: library.isFavorite(movie.id) ? "heart.fill" : "heart")
            }
            .disabled(!library.isLoaded)
        }
    }
}

#if DEBUG
// Detail cần NavigationStack của màn cha để hiện navigation title và toolbar.
// MoviesView đã cung cấp navigation khi chạy app; chỉ Preview standalone cần bọc thêm ở đây.
#Preview("Chi tiết phim") {
    PreviewHost { context in
        NavigationStack {
            MovieDetailView(movieID: PreviewSampleData.movie.id, repository: context.movieRepository)
        }
    }
}
#endif
