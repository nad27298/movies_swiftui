//
//  PreviewHost.swift
//  MoviesSwiftUI
//
//  Created by DaoNA3 on 01/10/2026.
//

#if DEBUG
import SwiftUI

// View bao ngoài để tránh lặp bốn dòng .environment ở mỗi Preview màn hình.
// Generic Content chỉ giữ kiểu View mà closure tạo ra; không cần AnyView hoặc một hệ thống Preview lớn.
// @State giữ context theo identity của host, nên gõ TextField/bấm Favorite không tạo lại store.
// Context không cần @Observable vì các dependency là let; chính các store/router đã observable.
// Initializer của View có thể chạy lại; SwiftUI vẫn giữ State đã có cho cùng identity.
// @ViewBuilder cho phép closure dựng một View, hoặc một nhóm View như NavigationStack chứa màn con.
struct PreviewHost<Content: View>: View {
    @State private var context: PreviewContext
    private let content: (PreviewContext) -> Content

    init(hasFavorites: Bool = true, @ViewBuilder content: @escaping (PreviewContext) -> Content) {
        _context = State(initialValue: PreviewContext(hasFavorites: hasFavorites))
        self.content = content
    }

    var body: some View {
        // Các màn dùng @Environment(Type.self) cần đúng instance đã truyền cho ViewModel.
        // Nếu chỉ viết MoviesView(repository: ...) mà thiếu store/router, Canvas sẽ lỗi Environment.
        content(context)
            .environment(context.library)
            .environment(context.settings)
            .environment(context.profile)
            .environment(context.router)
            .tint(AppTheme.accent)
    }
}
#endif
