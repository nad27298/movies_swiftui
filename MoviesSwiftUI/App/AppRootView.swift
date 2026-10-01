//
//  AppRootView.swift
//  MoviesSwiftUI
//
//  Created by DaoNA3 on 01/10/2026.
//

import SwiftUI

// View gốc nối bootstrap với UI và điều phối các presentation dùng chung.
// SwiftUI body chỉ mô tả giao diện theo state hiện tại; không nên khởi tạo database trong body.
// @Environment scenePhase cho biết Scene đang active, inactive hoặc background.
// @State router giữ lựa chọn tab/phim và trạng thái sheet qua các lần body được tính lại.
// .environment(object) truyền observable object xuống cây View; màn con đọc bằng @Environment(Type.self).
// .sheet biến state thành việc present/dismiss, gần vai trò present UIViewController trong UIKit.
// Dữ liệu reminder dùng chung được đối chiếu lại khi app foreground.
// Các onChange phản ứng với một thay đổi cụ thể; chúng không phải một vòng polling.
// AppTabView dùng TabView, tương ứng vai trò UITabBarController nhưng selection được quản lý bằng state.


struct AppRootView: View {
    let appDelegate: AppDelegate
    let bootstrap: AppBootstrap
    @Environment(\.scenePhase) private var scenePhase
    @State private var router = AppRouter()

    var body: some View {
        Group {
            if let dependencies = bootstrap.dependencies {
                AppTabView(dependencies: dependencies)
                    // Environment truyền reference observable xuống cây View, không copy một snapshot độc lập.
                    // MovieLibraryStore thay đổi sẽ được những View đọc thuộc tính tương ứng quan sát.
                    // Mỗi sheet cũng được inject các dependency cần thiết rõ ràng để dễ đọc đường đi của dữ liệu.
                    .environment(router)
                    .environment(dependencies.library)
                    .environment(dependencies.settings)
                    .environment(dependencies.profile)
                    // Binding Bool là nguồn sự thật cho menu sheet: true mở, false bắt đầu đóng.
                    // onDismiss mới là mốc sheet đã hoàn tất dismissal; route đang chờ được xử lý tại mốc đó.
                    // Không dùng thời gian delay cố định để đoán animation đã xong.
                    .sheet(isPresented: $router.menuPresented, onDismiss: {
                        router.menuDidDismiss()
                        router.processPendingRoute(isBusy: dependencies.library.isReminderBusy)
                    }) {
                        ProfileMenuView(library: dependencies.library)
                            .environment(router).environment(dependencies.library).environment(dependencies.profile)
                    }
                    // Sheet dạng item vừa biểu thị có mở hay không, vừa mang snapshot Movie cho editor.
                    // Item nil nghĩa không present; item khác nil tạo nội dung với đúng phim.
                    // Đây là cách tránh một Bool mở sheet nhưng lại thiếu dữ liệu phim để dựng editor.
                    .sheet(item: $router.reminderMovie, onDismiss: {
                        router.reminderDidDismiss()
                        router.processPendingRoute(isBusy: dependencies.library.isReminderBusy)
                    }) { movie in
                        ReminderEditorView(movie: movie, library: dependencies.library)
                    }
                    // Kết nối delegate khi dependency đã sẵn sàng, rồi đối chiếu lịch local với hệ thống.
                    // Task này không đọc API phim và không tự xin quyền notification.
                    // Nếu cold-start có notification pending, delegate chuyển ID sang router tại connect.
                    // Router vẫn kiểm tra trạng thái lưu/dismissal trước khi thực sự đổi tab/phim.
                    .task {
                        appDelegate.connect { id in router.queueMovie(id) }
                        await dependencies.library.reconcileNotifications()
                        router.processPendingRoute(isBusy: dependencies.library.isReminderBusy)
                    }
                    .onChange(of: router.pendingMovieID) { _, _ in
                        router.processPendingRoute(isBusy: dependencies.library.isReminderBusy)
                    }
                    .onChange(of: dependencies.library.isReminderBusy) { _, busy in
                        router.processPendingRoute(isBusy: busy)
                    }
                    .onChange(of: dependencies.library.isLoaded) { _, loaded in
                        if loaded { Task { await dependencies.library.reconcileNotifications() } }
                    }
                    .onChange(of: scenePhase) { _, phase in
                        if phase == .active { Task { await dependencies.library.reconcileNotifications() } }
                    }
            } else if let error = bootstrap.errorMessage {
                ErrorStateView(message: error, retry: bootstrap.start)
            } else {
                LoadingStateView().task { bootstrap.start() }
            }
        }
        .tint(AppTheme.accent)
    }

}

private struct AppTabView: View {
    let dependencies: AppDependencies
    @Environment(AppRouter.self) private var router

    var body: some View {
        // Environment cung cấp object; @Bindable tạo projected binding như $router.selectedTab.
        // TabView đọc selection để hiển thị tab và ghi selection khi người dùng đổi tab.
        // Vì dùng cùng router, thao tác programmatic từ notification cũng đổi đúng tab đang thấy.
        @Bindable var router = router
        // TabView tương ứng UITabBarController; selection do router sở hữu.
        TabView(selection: $router.selectedTab) {
            MoviesView(repository: dependencies.movieRepository)
                .tabItem { Label("Movies", systemImage: "film") }.tag(AppRouter.Tab.movies)
            FavoritesView(repository: dependencies.movieRepository, library: dependencies.library)
                .tabItem { Label("Favorites", systemImage: "heart") }.tag(AppRouter.Tab.favorites)
            SettingsView(store: dependencies.settings)
                .tabItem { Label("Settings", systemImage: "gearshape") }.tag(AppRouter.Tab.settings)
            AboutView()
                .tabItem { Label("About", systemImage: "info.circle") }.tag(AppRouter.Tab.about)
        }
    }
}
