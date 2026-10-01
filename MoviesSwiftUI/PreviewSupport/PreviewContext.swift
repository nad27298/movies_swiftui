//
//  PreviewContext.swift
//  MoviesSwiftUI
//
//  Created by DaoNA3 on 01/10/2026.
//

#if DEBUG
import Foundation

// Gom các dependency tối thiểu cần để dựng màn hình trong Canvas.
// App thật vẫn tạo dependency bằng AppDependencies; không tự chọn mock theo biến môi trường.
// Mỗi PreviewContext tạo store/repository/router riêng nên hai Preview không sửa dữ liệu của nhau.
// Chỉ thay implementation ở ranh giới dữ liệu; View và ViewModel chạy như bình thường.
// Nhờ vậy .task của Movies/Detail vẫn hoạt động nhưng nhận dữ liệu mẫu thay vì gọi API.
@MainActor final class PreviewContext {
    let movieRepository: any MovieRepository = PreviewMovieRepository()
    let library: MovieLibraryStore
    let settings = SettingsStore(repository: PreviewSettingsRepository())
    let profile: ProfileStore
    let router = AppRouter()
    private let avatarDirectory: URL

    init(hasFavorites: Bool = true) {
        let now = Date()
        let local = PreviewLibraryRepository()
        if hasFavorites {
            local.favorites = PreviewSampleData.movies.prefix(2).map { FavoriteMovie(movie: $0, savedAt: now) }
        }
        // Tính theo lúc mở Preview, tránh mẫu có ngày cố định trở thành toàn bộ lịch đã qua.
        // Mỗi phim có một reminder, giống quy tắc dữ liệu của app.
        local.reminders = [
            MovieReminder(movie: PreviewSampleData.movie, scheduledAt: now.addingTimeInterval(86_400),
                          createdAt: now, updatedAt: now),
            MovieReminder(movie: PreviewSampleData.movies[1], scheduledAt: now.addingTimeInterval(-86_400),
                          createdAt: now.addingTimeInterval(-172_800), updatedAt: now)
        ]
        library = MovieLibraryStore(favorites: local, reminders: local, scheduler: PreviewNotificationScheduler())
        library.load()

        // Profile text chỉ nằm trong bộ nhớ. Nếu thử chọn và lưu ảnh, file đi vào thư mục tạm riêng.
        // Không tạo thư mục tại init; AvatarFileStorage chỉ tạo khi thực sự cần ghi/đọc ảnh.
        avatarDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MoviesSwiftUI-Preview-" + UUID().uuidString, isDirectory: true)
        profile = ProfileStore(repository: PreviewProfileRepository(), files: AvatarFileStorage(directoryURL: avatarDirectory))
    }

    deinit {
        // Chỉ dọn thư mục UUID của context này, không xóa toàn bộ temporaryDirectory.
        // Đây là cleanup khi context được giải phóng, không phải cam kết khi tiến trình bị đóng đột ngột.
        try? FileManager.default.removeItem(at: avatarDirectory)
    }
}

// Mock nhỏ triển khai contract có sẵn, không cần thêm protocol hay sửa ViewModel.
// Một trang là đủ học List/Grid; không mô phỏng latency, retry hoặc pagination phức tạp.
@MainActor private final class PreviewMovieRepository: MovieRepository {
    func fetchMovies(category: MovieCategory, page: Int) async throws -> MoviePage {
        MoviePage(movies: page == 1 ? PreviewSampleData.movies : [], page: page, totalPages: 1)
    }

    func fetchMovieDetail(id: Int) async throws -> MovieDetail {
        guard let movie = PreviewSampleData.movies.first(where: { $0.id == id }) else {
            throw AppError.invalidInput("Phim này không nằm trong dữ liệu Preview.")
        }
        return MovieDetail(movie: movie)
    }

    func fetchCast(movieID: Int) async throws -> [CastMember] { PreviewSampleData.cast }
}

// Một object chứa hai danh sách local mẫu. Không khởi tạo SwiftData hay đọc database trên đĩa.
// Các thao tác sửa mảng giúp bạn thử Favorite/xóa/lưu lịch mà vẫn dùng logic store thật.
@MainActor private final class PreviewLibraryRepository: FavoriteRepository, ReminderRepository {
    var favorites: [FavoriteMovie] = []
    var reminders: [MovieReminder] = []

    func fetchFavorites() throws -> [FavoriteMovie] { favorites }
    func saveFavorite(_ favorite: FavoriteMovie) throws {
        favorites.removeAll { $0.id == favorite.id }
        favorites.insert(favorite, at: 0)
    }
    func deleteFavorite(movieID: Int) throws { favorites.removeAll { $0.id == movieID } }
    func fetchReminders() throws -> [MovieReminder] { reminders }
    func saveReminder(_ reminder: MovieReminder) throws {
        reminders.removeAll { $0.id == reminder.id }
        reminders.append(reminder)
    }
}

// Settings/Profile mẫu vẫn hỗ trợ Save, nhưng giá trị mất khi context bị giải phóng.
// Không dùng UserDefaults.standard nên thao tác trên Canvas không đổi thiết lập đã lưu của app.
@MainActor private final class PreviewSettingsRepository: SettingsRepository {
    private var value = MovieSettings()
    func load() throws -> MovieSettings { value }
    func save(_ settings: MovieSettings) throws { value = settings }
}

@MainActor private final class PreviewProfileRepository: ProfileRepository {
    private var value = PreviewSampleData.profile
    func load() throws -> UserProfile { value }
    func save(_ profile: UserProfile) throws { value = profile }
}

// Giả lập kết quả đặt lịch để học UI. Không xin quyền và không gọi UserNotifications.
// .scheduled ở đây chỉ là kết quả mẫu; không có notification thật được gửi từ Canvas.
// Lịch seed chưa đi qua schedule nên bắt đầu ở trạng thái notScheduled.
@MainActor private final class PreviewNotificationScheduler: NotificationScheduling {
    private var scheduledIDs: Set<Int> = []

    func schedule(_ reminder: MovieReminder) async -> ReminderSaveOutcome {
        scheduledIDs.insert(reminder.id)
        return .scheduled
    }

    func reconcile(_ reminders: [MovieReminder]) async -> [Int: ReminderScheduleStatus] {
        Dictionary(uniqueKeysWithValues: reminders.map { reminder in
            let status: ReminderScheduleStatus = reminder.scheduledAt <= Date()
                ? .past : (scheduledIDs.contains(reminder.id) ? .scheduled : .notScheduled)
            return (reminder.id, status)
        })
    }
}
#endif
