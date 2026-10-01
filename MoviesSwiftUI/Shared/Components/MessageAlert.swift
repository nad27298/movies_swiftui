//
//  MessageAlert.swift
//  MoviesSwiftUI
//
//  Created by DaoNA3 on 01/10/2026.
//

import SwiftUI

// Helper tạo alert từ một Binding<String?> của màn cha.
// Optional message cũng là trạng thái presentation: có message thì mở, nil thì đóng.
// Binding Bool được xây từ Binding optional, nên không tạo thêm isAlertPresented cần đồng bộ riêng.
// Setter false xóa message khi hệ thống dismiss, nút Đóng cũng trả state về nil.
// Extension View trả some View: kiểu cụ thể được compiler suy ra, caller vẫn tiếp tục chain modifier.
// Không lưu lỗi global vì mỗi feature sở hữu ngữ cảnh và lifecycle lỗi của mình.


extension View {
    // Binding(get:set:) nối hai biểu diễn của cùng state: String? ở owner và Bool mà alert cần.
    // Không có message thì false; hệ thống ghi false thì owner được xóa message.
    // Dữ liệu và trạng thái mở alert vì vậy không thể lệch như khi giữ hai biến mutable riêng.
    func messageAlert(_ message: Binding<String?>, title: String = "Thông báo") -> some View {
        alert(title, isPresented: Binding(get: { message.wrappedValue != nil }, set: {
            if !$0 { message.wrappedValue = nil }
        })) {
            Button("Đóng", role: .cancel) { message.wrappedValue = nil }
        } message: {
            Text(message.wrappedValue ?? "")
        }
    }
}
