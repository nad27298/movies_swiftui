//
//  MoviesSwiftUIApp.swift
//  MoviesSwiftUI
//
//  Created by DaoNA3 on 01/10/2026.
//

import SwiftUI

// Điểm vào của ứng dụng SwiftUI: @main yêu cầu hệ thống khởi động từ kiểu App này.
// App mô tả các Scene, còn mỗi Scene chứa cây View của một cửa sổ.
// WindowGroup là nơi SwiftUI tạo cửa sổ và gắn AppRootView vào đó.
// @State giữ AppBootstrap theo identity của App, tránh tạo database và Session mỗi lần body chạy.
// @UIApplicationDelegateAdaptor đưa một UIApplicationDelegate vào lifecycle SwiftUI.
// Ta dùng delegate cho notification; không dùng nó để dựng lại root controller như bản UIKit.
// Trong UIKit, vai trò khởi tạo ứng dụng thường nằm ở AppDelegate/SceneDelegate.
// Trong SwiftUI, composition root được tách thành AppDependencies để việc inject dễ theo dõi.


@main
struct MoviesSwiftUIApp: App {
    // Cầu nối lifecycle UIApplicationDelegate cho notification; UI chính vẫn là SwiftUI.
    // Property wrapper này tạo và giữ AppDelegate theo lifecycle ứng dụng.
    // SwiftUI sẽ gọi các callback UIApplicationDelegate tương ứng, không cần tự new delegate trong View.
    // Notification delegate vì vậy có thể đăng ký trước khi AppRoot đã mở xong database.
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var bootstrap = AppBootstrap()

    var body: some Scene {
        // Scene là cấp trên View. Một WindowGroup mô tả loại cửa sổ có thể chứa cây giao diện này.
        // Bootstrap được App sở hữu nên truyền xuống root, thay vì tạo một database/Session trong closure body.
        // Router vẫn do mỗi AppRoot giữ vì selection/presentation thuộc giao diện của root đó.
        WindowGroup {
            AppRootView(appDelegate: appDelegate, bootstrap: bootstrap)
        }
    }
}
