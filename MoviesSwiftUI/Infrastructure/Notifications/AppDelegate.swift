//
//  AppDelegate.swift
//  MoviesSwiftUI
//
//  Created by DaoNA3 on 01/10/2026.
//

import UIKit
import UserNotifications

// Cầu nối UIApplication lifecycle và notification delegate cho SwiftUI App.
// Delegate được đăng ký tại launch để notification tap khởi động lạnh không bị bỏ qua.
// Handler chưa kết nối thì giữ movie ID pending; AppRoot connect khi bootstrap sẵn sàng.
// Delegate async trả về để hệ thống hoàn tất callback, không tự gọi completion nhiều nhánh.
// Callback notification là nonisolated: trích payload thành Int/String rồi chuyển sang MainActor.
// Không chuyển cả userInfo dictionary/UNNotificationResponse vào store UI.
// Response key chống xử lý trùng một lần tap; cùng phim ở lần notification khác vẫn có thể route.
// willPresent chỉ chọn banner/list/sound, không tự mở Detail nếu người dùng chưa tap.


@MainActor final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    private var handler: ((Int) -> Void)?
    private var pendingMovieID: Int?
    private var handledResponses: Set<String> = []

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // Callback được nối sau bootstrap, khi router/UI có thể tiếp nhận ý định navigation.
    // Nếu có cold-start event trước đó, chuyển đúng ID pending rồi xóa buffer.
    // connect không tự dựng tab hoặc gọi API, trách nhiệm đó thuộc AppRoot/router/ViewModel.
    func connect(handler: @escaping (Int) -> Void) {
        self.handler = handler
        if let pendingMovieID {
            self.pendingMovieID = nil
            handler(pendingMovieID)
        }
    }

    // Dùng delegate async: hệ thống hoàn tất callback sau khi hàm trả về.
    // Đọc payload tại callback, chỉ chuyển Int/String Sendable sang MainActor.
    // Chỉ default action của người dùng tap mới route; dismiss notification không mở phim.
    // Payload hỗ trợ Int hoặc String ID, sau đó kiểm tra > 0 trước gửi sang MainActor.
    // responseKey dùng identifier + ngày nhận để phân biệt lần tap với event trùng.
    // await accept đảm bảo mutation handler/buffer ở MainActor; delegate async tự hoàn tất khi return.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier else { return }
        let value = response.notification.request.content.userInfo["movieID"]
        let id = (value as? Int) ?? (value as? String).flatMap(Int.init)
        guard let id, id > 0 else { return }
        let key = response.notification.request.identifier + ":" + String(response.notification.date.timeIntervalSince1970)
        await accept(id: id, responseKey: key)
    }

    private func accept(id: Int, responseKey: String) {
        guard handledResponses.insert(responseKey).inserted else { return }
        if let handler { handler(id) }
        else { pendingMovieID = id }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
