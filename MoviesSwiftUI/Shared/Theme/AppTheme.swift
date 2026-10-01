//
//  AppTheme.swift
//  MoviesSwiftUI
//
//  Created by DaoNA3 on 01/10/2026.
//

import SwiftUI

// Các giá trị giao diện dùng chung, không giữ state hay side effect.
// Màu accent gần bản UIKit cũ; semantic secondary/material vẫn theo giao diện hệ thống.
// contentWidth giới hạn nội dung đọc trên iPad để form/văn bản không trải quá rộng.
// Enum không có instance giúp nhóm các hằng số, không cần tạo ThemeManager singleton.
// AppRoot dùng tint để truyền màu tương tác xuống các control SwiftUI hỗ trợ tint.


enum AppTheme {
    static let accent = Color(red: 46 / 255, green: 81 / 255, blue: 194 / 255)
    static let contentWidth: CGFloat = 760
}
