//
//  MovieRow.swift
//  MoviesSwiftUI
//
//  Created by DaoNA3 on 01/10/2026.
//

import SwiftUI

// Component trình bày thông tin một Movie, gần một UITableViewCell được cấu hình bằng model.
// View không tự tải JSON hoặc sửa database; dữ liệu và action được truyền từ màn cha.
// VStack/HStack là layout khai báo, không đặt frame thủ công cho từng subview UIKit.
// Font semantic hỗ trợ Dynamic Type, lineLimit giới hạn overview chứ không khóa chiều cao toàn row.
// PosterView đóng gói tải ảnh; đường dẫn nil vẫn có placeholder.
// Button Favorite tùy chọn dùng closure để báo thao tác lên cha; closure vẫn hữu ích cho component SwiftUI.
// State Favorite phải lấy từ shared store, không tạo @State bool riêng trong từng row.


struct MovieRow: View {
    let movie: Movie
    var isFavorite = false
    var favoriteEnabled = true
    var toggleFavorite: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            PosterView(path: movie.posterPath, width: 100, height: 145)
            VStack(alignment: .leading, spacing: 7) {
                Text(movie.title).font(.headline)
                Text(movie.releaseDate?.displayText ?? "Chưa có ngày phát hành").font(.caption).foregroundStyle(.secondary)
                Label(movie.ratingText, systemImage: "star.fill").font(.subheadline).foregroundStyle(AppTheme.accent)
                if movie.isAdult { Text("Adult").font(.caption).foregroundStyle(.red) }
                if !movie.overview.isEmpty { Text(movie.overview).font(.subheadline).lineLimit(3) }
            }
            Spacer(minLength: 0)
            if let toggleFavorite {
                Button(action: toggleFavorite) {
                    Image(systemName: isFavorite ? "heart.fill" : "heart").frame(minWidth: 32, minHeight: 44)
                }
                .buttonStyle(.borderless)
                .disabled(!favoriteEnabled)
                .accessibilityLabel(isFavorite ? "Bỏ phim yêu thích" : "Lưu phim yêu thích")
            }
        }
        .padding(.vertical, 5)
    }
}
