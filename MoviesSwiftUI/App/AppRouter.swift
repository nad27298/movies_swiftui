//
//  AppRouter.swift
//  MoviesSwiftUI
//
//  Created by DaoNA3 on 01/10/2026.
//

import SwiftUI
import Observation

// Router là owner của navigation và presentation dùng chung.
// View gửi ý định mở phim; router quyết định tab, movie ID và cột compact cần hiển thị.
// @Observable khiến các View đọc router tự cập nhật khi selection thay đổi.
// NavigationSplitViewColumn cho phép cùng UI thích ứng danh sách/chi tiết trên iPad và iPhone.
// Notification có thể tới khi sheet đang mở hoặc đang đóng nên cần một route pending.
// Đổi state sheet về false/nil chỉ bắt đầu dismissal, chưa chứng minh animation đã kết thúc.
// Các cờ dismissal chỉ được xóa trong onDismiss, rồi mới tiêu thụ route pending.
// Đây là khác biệt quan trọng với việc gọi push ngay sau dismiss trong UIKit.
// Router giữ ID/state, không giữ View hoặc UIViewController để tránh phụ thuộc vòng đời UI.


@MainActor @Observable final class AppRouter {
    enum Tab: Hashable { case movies, favorites, settings, about }
    var selectedTab: Tab = .movies
    var homeMovieID: Int?
    var favoriteMovieID: Int?
    var homeCompactColumn: NavigationSplitViewColumn = .sidebar
    var favoriteCompactColumn: NavigationSplitViewColumn = .sidebar
    // didSet theo dõi cả dismissal do code và do người dùng vuốt sheet.
    // Ngay khi false/nil, đánh dấu đang đóng để một notification tới giữa animation không mở phim quá sớm.
    // Cờ này không tự xóa trong didSet; onDismiss ở AppRoot chịu trách nhiệm xóa.
    var menuPresented = false {
        didSet { if oldValue && !menuPresented { menuIsDismissing = true } }
    }
    var reminderMovie: Movie? {
        didSet { if oldValue != nil && reminderMovie == nil { reminderIsDismissing = true } }
    }
    private(set) var pendingMovieID: Int?
    private var menuIsDismissing = false
    private var reminderIsDismissing = false
    var isPresentationDismissing: Bool { menuIsDismissing || reminderIsDismissing }

    // Chỉ nhận ID hợp lệ, chọn đúng tab và cột detail khi giao diện đang compact.
    // Gán cùng ID không append thêm một route vào stack, nên không tạo Detail thứ hai cho cùng selection.
    // Router không fetch dữ liệu; View có ID mới sẽ yêu cầu ViewModel tải tại lifecycle phù hợp.
    func openMovie(_ id: Int, in tab: Tab = .movies) {
        guard id > 0 else { return }
        selectedTab = tab
        if tab == .favorites {
            favoriteMovieID = id
            favoriteCompactColumn = .detail
        } else {
            homeMovieID = id
            homeCompactColumn = .detail
        }
    }

    // Ghi ý định navigation trước, chưa thao tác presentation ở callback notification/menu.
    // Nếu có nhiều event trong lúc chưa thể route, pending giữ lựa chọn mới nhất.
    // AppRoot gọi processPendingRoute khi event/state readiness thay đổi.
    func queueMovie(_ id: Int) {
        guard id > 0 else { return }
        pendingMovieID = id
    }

    // Guard chặn route khi đang lưu lịch hoặc còn animation dismissal chưa hoàn tất.
    // Nếu editor/menu còn mở, bắt đầu đóng rồi return; không mở phim trong cùng bước.
    // onDismiss gọi lại hàm này và lúc đó mới tiêu thụ pendingMovieID.
    // Xóa pending trước openMovie để onChange không xử lý lại cùng event.
    func processPendingRoute(isBusy: Bool) {
        guard let id = pendingMovieID, !isBusy, !menuIsDismissing, !reminderIsDismissing else { return }
        if reminderMovie != nil {
            reminderIsDismissing = true
            reminderMovie = nil
            return
        }
        if menuPresented {
            menuIsDismissing = true
            menuPresented = false
            return
        }
        pendingMovieID = nil
        openMovie(id)
    }

    func menuDidDismiss() { menuIsDismissing = false }
    func reminderDidDismiss() { reminderIsDismissing = false }
}

struct MenuToolbar: ToolbarContent {
    let router: AppRouter
    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button { router.menuPresented = true } label: { Image(systemName: "person.crop.circle") }
                .disabled(router.isPresentationDismissing || router.reminderMovie != nil)
                .accessibilityLabel("Mở hồ sơ và lịch nhắc")
        }
    }
}
