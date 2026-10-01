//
//  AboutViewModel.swift
//  MoviesSwiftUI
//
//  Created by DaoNA3 on 01/10/2026.
//

import Foundation
import Observation
import WebKit

// State của WebView và các dialog JavaScript được trình bày bằng SwiftUI.
// WKWebView reference được giữ weak và ObservationIgnored: nó là công cụ, không phải value UI.
// canGoBack/canGoForward/isLoading là state observable để toolbar phản ứng với delegate.
// Dialog chứa kind/message/ID; completion được giữ riêng vì closure không phải dữ liệu để render.
// finishDialog lấy callback rồi xóa reference trước khi gọi để tránh hoàn tất hai lần/reentrancy.
// Button Back/Forward/Refresh gửi lệnh tới web view hiện có, không đổi URL initial để ép makeUIView chạy lại.
// MainActor phù hợp vì WebKit/UI state được điều phối trên miền giao diện.


@MainActor @Observable final class AboutViewModel {
    enum DialogKind: Equatable { case alert, confirm, prompt }
    struct Dialog: Identifiable {
        let id = UUID()
        let kind: DialogKind
        let message: String
    }

    var isLoading = false
    var canGoBack = false
    var canGoForward = false
    var errorMessage: String?
    var dialog: Dialog?
    var promptText = ""
    // WebView do bridge/UI sở hữu; ViewModel chỉ cần reference để gửi lệnh toolbar.
    // weak tránh ViewModel giữ UIView sống ngoài lifecycle cây SwiftUI.
    // Không quan sát UIView reference vì canGoBack/loading mới là state thực sự được body đọc.
    @ObservationIgnored private weak var webView: WKWebView?
    @ObservationIgnored private var dialogCompletion: ((Bool, String?) -> Void)?

    func attach(_ webView: WKWebView) { self.webView = webView }
    func back() { webView?.goBack() }
    func forward() { webView?.goForward() }
    func refresh() { webView?.reload() }
    func updateNavigation(_ webView: WKWebView) {
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
    }

    // Hoàn tất dialog cũ trước khi giữ callback mới để không bỏ một callback đang chờ.
    // State Dialog mô tả UI, closure completion được giữ riêng ngoài tracking.
    // promptText là input draft của alert và chỉ trả lại web page khi confirm.
    func presentDialog(kind: DialogKind, message: String, defaultText: String = "", completion: @escaping (Bool, String?) -> Void) {
        finishDialog(confirmed: false)
        promptText = defaultText
        dialogCompletion = completion
        dialog = Dialog(kind: kind, message: message)
    }

    // Copy callback rồi xóa storage/state trước khi gọi để xử lý reentrancy và dismiss lặp.
    // Confirm trả promptText; Cancel trả nil và false cho các bridge callback tương ứng.
    // Dù gọi từ button, binding dismissal hoặc dismantle, mỗi callback chỉ được dùng một lần.
    func finishDialog(confirmed: Bool) {
        let completion = dialogCompletion
        dialogCompletion = nil
        dialog = nil
        // Lấy callback ra trước: dismiss hoặc dismantle gọi lần nữa sẽ không hoàn tất hai lần.
        completion?(confirmed, confirmed ? promptText : nil)
    }
}
