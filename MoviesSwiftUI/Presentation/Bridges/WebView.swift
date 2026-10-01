//
//  WebView.swift
//  MoviesSwiftUI
//
//  Created by DaoNA3 on 01/10/2026.
//

import SwiftUI
import WebKit

// UIViewRepresentable bọc WKWebView, vì trang web tương tác vẫn cần WebKit.
// makeUIView tạo/configure/load URL ban đầu; updateUIView không load lại theo mỗi state UI.
// Coordinator nối WKNavigationDelegate/WKUIDelegate tới AboutViewModel observable.
// currentNavigation phân biệt callback của navigation cũ với lần mới để loading/error không bị ghi sai.
// Link target window mới được tải cùng web view, không tự tạo một browser riêng.
// JavaScript cần completion handler dù người dùng hủy hoặc View bị tháo, nếu không trang có thể chờ mãi.
// dismantleUIView dừng công việc và hoàn tất dialog còn chờ khi SwiftUI tháo bridge.
// Đây là bridge có giới hạn, không chuyển phần còn lại của app sang UIKit.


struct WebView: UIViewRepresentable {
    let model: AboutViewModel
    let url: URL

    func makeCoordinator() -> Coordinator { Coordinator(model: model) }

    // make chạy khi SwiftUI cần tạo UIView cho identity bridge này.
    // Gắn delegate/coordinator và attach weak reference trước khi bắt đầu load initial URL.
    // Không gọi load lại từ body hoặc updateUIView khi loading/canGoBack thay đổi.
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        model.attach(webView)
        webView.load(URLRequest(url: url))
        return webView
    }

    // updateUIView chạy khi state thay đổi; load ở đây sẽ tạo vòng lặp navigation.
    func updateUIView(_ webView: WKWebView, context: Context) { }

    // Đây là mốc SwiftUI tháo UIView khỏi cây được quản lý.
    // Dừng load và bỏ delegate để callback không tiếp tục điều khiển UI không còn cần.
    // Hoàn tất dialog còn chờ với kết quả hủy, không để JavaScript giữ một lời gọi chưa trả về.
    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        coordinator.model.finishDialog(confirmed: false)
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let model: AboutViewModel
        private var currentNavigation: WKNavigation?
        init(model: AboutViewModel) { self.model = model }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            currentNavigation = navigation
            model.isLoading = true
            model.errorMessage = nil
            model.updateNavigation(webView)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard navigation === currentNavigation else { return }
            model.isLoading = false
            model.updateNavigation(webView)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            failed(webView, navigation: navigation, error: error)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            failed(webView, navigation: navigation, error: error)
        }

        // WKWebView có thể báo callback của navigation đã bị thay bởi navigation mới.
        // So identity để lỗi cũ không tắt loading của trang mới.
        // NSURLErrorCancelled thường do điều hướng/hủy, không phải lý do hiện lỗi tải cho người dùng.
        private func failed(_ webView: WKWebView, navigation: WKNavigation?, error: Error) {
            guard navigation === currentNavigation else { return }
            model.isLoading = false
            model.updateNavigation(webView)
            if (error as NSError).code != NSURLErrorCancelled { model.errorMessage = "Không tải được trang About. Vui lòng thử lại." }
        }

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil { webView.load(navigationAction.request) }
            return nil
        }

        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            model.presentDialog(kind: .alert, message: message) { _, _ in completionHandler() }
        }

        func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
            model.presentDialog(kind: .confirm, message: message) { confirmed, _ in completionHandler(confirmed) }
        }

        func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String,
                     defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
            model.presentDialog(kind: .prompt, message: prompt, defaultText: defaultText ?? "") { _, text in completionHandler(text) }
        }
    }
}
