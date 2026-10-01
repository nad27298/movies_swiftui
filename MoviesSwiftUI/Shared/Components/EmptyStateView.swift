//
//  EmptyStateView.swift
//  MoviesSwiftUI
//
//  Created by DaoNA3 on 01/10/2026.
//

import SwiftUI

// Component trạng thái không có nội dung bằng ContentUnavailableView native.
// Cha truyền title/message/symbol để phân biệt chưa có Favorite với không có kết quả filter.
// Empty không đồng nghĩa network/database lỗi; màn cha phải kiểm tra load state trước.
// SF Symbol minh họa cùng text, không cần asset riêng cho từng empty state.
// Component chỉ render dữ liệu đầu vào, không tự phát sinh API để cố thoát trạng thái rỗng.


struct EmptyStateView: View {
    let title: String
    var message = ""
    var symbol = "film"
    var body: some View { ContentUnavailableView(title, systemImage: symbol, description: Text(message)) }
}
