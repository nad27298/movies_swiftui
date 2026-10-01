//
//  ErrorStateView.swift
//  MoviesSwiftUI
//
//  Created by DaoNA3 on 01/10/2026.
//

import SwiftUI

// Component lỗi có closure retry do feature truyền vào.
// Closure cho phép retry đúng phần bị lỗi, ví dụ chỉ tải cast mà không tải lại Detail.
// View không tự quyết định networking, vì cùng UI có thể dùng cho lỗi API hoặc đọc local.
// Text multiline và font mặc định thích ứng với nội dung tiếng Việt/cỡ chữ người dùng.
// buttonStyle bordered là native styling, không cần tạo background/corner radius thủ công cho UIButton.


struct ErrorStateView: View {
    let message: String
    let retry: () -> Void
    var body: some View {
        VStack(spacing: 12) {
            Text(message).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Thử lại", action: retry).buttonStyle(.bordered)
        }
        .padding().frame(maxWidth: .infinity)
    }
}
