//
//  MovieGridItem.swift
//  MoviesSwiftUI
//
//  Created by DaoNA3 on 01/10/2026.
//

import SwiftUI

// Item của LazyVGrid, gần UICollectionViewCell nhưng được dựng từ value Movie.
// Component chỉ có poster/tên để bám nội dung grid của app mẫu.
// LazyVGrid ở màn cha chọn cột; item không tự quyết định iPhone/iPad.
// frame(maxWidth: .infinity) nhận chiều rộng cột được cha đề xuất.
// contentShape xác định vùng hit-test của item khi đặt trong Button.
// Không tạo ViewModel/request riêng cho mỗi item; tải ảnh được PosterView đảm nhiệm.


struct MovieGridItem: View {
    let movie: Movie
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PosterView(path: movie.posterPath, height: 230)
            Text(movie.title).font(.headline).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
    }
}

#if DEBUG
// Xem item trong layout thật mà nó thường được sử dụng: LazyVGrid chọn cột theo chiều rộng.
// Đổi Preview destination iPhone/iPad để quan sát số cột mà không hardcode tên thiết bị.
#Preview("Các item trong lưới") {
    ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 145))], spacing: 20) {
            ForEach(PreviewSampleData.movies) { MovieGridItem(movie: $0) }
        }
        .padding()
    }
}
#endif
