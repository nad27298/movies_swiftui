//
//  AboutView.swift
//  MoviesSwiftUI
//
//  Created by DaoNA3 on 01/10/2026.
//

import SwiftUI

// Màn SwiftUI chứa WebView bridge và toolbar native.
// @State giữ AboutViewModel để state không mất mỗi lần loading thay đổi.
// Button enable/disable dựa canGoBack/canGoForward từ delegate, không đoán lịch sử trang.
// Toolbar bottomBar gần thanh công cụ bên dưới UIViewController trong UIKit.
// Alert trình bày JavaScript dialog theo model; Binding false xử lý cả đường dismiss/hủy.
// TextField của prompt ghi vào promptText, callback chỉ hoàn tất khi người dùng chọn hoặc dialog bị đóng.
// onDisappear hoàn tất dialog còn chờ, tránh giữ trang web chờ một UI không còn hiển thị.


struct AboutView: View {
    @Environment(AppRouter.self) private var router
    @State private var model = AboutViewModel()
    private let url = URL(string: "https://www.themoviedb.org/about")!

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            VStack(spacing: 0) {
                if model.isLoading { ProgressView().padding(8) }
                if let error = model.errorMessage { ErrorStateView(message: error, retry: model.refresh) }
                WebView(model: model, url: url)
            }
            .navigationTitle("About")
            .toolbar {
                MenuToolbar(router: router)
                ToolbarItemGroup(placement: .bottomBar) {
                    Button(action: model.back) { Image(systemName: "chevron.left") }
                        .disabled(!model.canGoBack).accessibilityLabel("Trang trước")
                    Spacer()
                    Button(action: model.refresh) { Image(systemName: "arrow.clockwise") }.accessibilityLabel("Tải lại trang")
                    Spacer()
                    Button(action: model.forward) { Image(systemName: "chevron.right") }
                        .disabled(!model.canGoForward).accessibilityLabel("Trang sau")
                }
            }
            .alert("Thông báo từ trang web", isPresented: Binding(get: { model.dialog != nil }, set: {
                if !$0 { model.finishDialog(confirmed: false) }
            }), presenting: model.dialog) { dialog in
                if dialog.kind == .prompt { TextField("Nội dung", text: $model.promptText) }
                Button("OK") { model.finishDialog(confirmed: true) }
                if dialog.kind != .alert { Button("Hủy", role: .cancel) { model.finishDialog(confirmed: false) } }
            } message: { dialog in Text(dialog.message) }
            .onDisappear { model.finishDialog(confirmed: false) }
        }
    }
}
