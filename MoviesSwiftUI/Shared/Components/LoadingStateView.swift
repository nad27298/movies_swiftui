//
//  LoadingStateView.swift
//  MoviesSwiftUI
//
//  Created by DaoNA3 on 01/10/2026.
//

import SwiftUI

// Component loading dùng ProgressView native, gần activity indicator của UIKit.
// State loading được owner ở ViewModel quyết định; component không tự bật/tắt request.
// Dùng một View nhỏ để các màn hiển thị thông điệp/loading nhất quán.
// Không dùng global HUD vì một request cast không nên che cả Detail hoặc màn khác.
// frame nhận chiều rộng cha đề xuất và dành vùng tối thiểu để indicator không bị dồn.


struct LoadingStateView: View {
    var body: some View { ProgressView("Đang tải…").frame(maxWidth: .infinity, minHeight: 120) }
}

#if DEBUG
// Component không cần Environment hoặc ViewModel, nên Preview dựng trực tiếp là đủ.
#Preview("Đang tải", traits: .sizeThatFitsLayout) {
    LoadingStateView()
}
#endif
