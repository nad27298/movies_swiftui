//
//  AppDependencies.swift
//  MoviesSwiftUI
//
//  Created by DaoNA3 on 01/10/2026.
//

import Foundation
import SwiftData
import Observation

// Composition root: nơi duy nhất nối các implementation Data với contracts Domain.
// AppBootstrap là observable state của bước mở app: chưa sẵn sàng, có dependency, hoặc có lỗi.
// AppDependencies giữ các object sống lâu: database, repository và shared stores.
// Các ViewModel nhận dependency đã tạo thay vì tự truy cập singleton hoặc tự tạo Session.
// Nhờ đó, ViewModel biết cần chức năng gì qua protocol, nhưng không cần biết nguồn đó dùng Alamofire.
// MainActor giữ việc khởi tạo và các store UI trong cùng miền isolation.
// Nếu mở database thất bại, app cho thử lại; không xóa dữ liệu và không dùng fatalError.
// Đây là dependency injection bằng initializer, không cần một framework DI riêng.


// App sở hữu bootstrap một lần; body hoặc WindowGroup không tự tạo thêm database/session.
@MainActor @Observable final class AppBootstrap {
    private(set) var dependencies: AppDependencies?
    private(set) var errorMessage: String?

    // Thao tác có guard để nhiều lần xuất hiện của View không khởi tạo dependency lần nữa.
    // Đặt dependencies sau khi initializer hoàn tất; các màn không nhận một dependency đang tạo dở.
    // Nếu throws, observable errorMessage làm AppRoot chuyển sang UI thử lại.
    // Không tự xóa database khi mở lỗi, vì lỗi khởi tạo không chứng minh dữ liệu không còn cần thiết.
    func start() {
        guard dependencies == nil else { return }
        do {
            dependencies = try AppDependencies()
            errorMessage = nil
        } catch {
            errorMessage = "Không thể mở dữ liệu của app. Vui lòng thử lại; app chưa xóa dữ liệu đã lưu."
        }
    }
}

@MainActor final class AppDependencies {
    let container: ModelContainer
    let movieRepository: any MovieRepository
    let library: MovieLibraryStore
    let settings: SettingsStore
    let profile: ProfileStore

    // Khởi tạo từ tầng thấp lên cao: container → repositories → stores.
    // Cùng một library/profile/settings được chia sẻ cho các màn, tránh mỗi tab có một bản state khác nhau.
    // MovieRepository được khai báo bằng protocol nhưng implementation cụ thể được chọn tại đây.
    // Việc load local xảy ra trước khi các nút Favorite/Reminder được phép thao tác.
    init() throws {
        container = try PersistenceContainer.make()
        let scheduler = NotificationScheduler()
        movieRepository = RemoteMovieRepository(service: TMDBService(client: HTTPClient()))
        library = MovieLibraryStore(favorites: LocalFavoriteRepository(container: container),
                                    reminders: LocalReminderRepository(container: container), scheduler: scheduler)
        settings = SettingsStore(repository: UserDefaultsSettingsRepository())
        profile = ProfileStore(repository: UserDefaultsProfileRepository(), files: AvatarFileStorage())
        library.load()
    }
}
