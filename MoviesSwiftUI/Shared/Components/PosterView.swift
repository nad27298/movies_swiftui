//
//  PosterView.swift
//  MoviesSwiftUI
//
//  Created by DaoNA3 on 01/10/2026.
//

import SwiftUI
import Kingfisher

// Component duy nhất dựng ảnh TMDB bằng Kingfisher KFImage.
// path là đường dẫn tương đối từ server; nối base image URL tại đây để các màn không lặp lại.
// KFImage tải/cache bất đồng bộ và cập nhật phần ảnh, không phải pipeline decode JSON của app.
// Placeholder xử lý chưa tải/thiếu ảnh; lỗi ảnh không biến request dữ liệu phim thành lỗi.
// scaledToFill phủ kín khung, clipped cắt phần thừa thay vì kéo méo tỷ lệ bitmap.
// width nil để nhận đề xuất của cha/grid, height xác định vùng ảnh mong muốn.
// cancelOnDisappear giảm công việc ảnh ngoài màn; cache vẫn do Kingfisher quản lý.
// accessibilityHidden tránh VoiceOver đọc ảnh trang trí lặp lại tên phim bên cạnh.


struct PosterView: View {
    let path: String?
    var width: CGFloat? = nil
    var height: CGFloat = 160

    // URL là giá trị tính ra từ path, không có state riêng cần đồng bộ.
    // Chỉ chấp nhận path tương đối của TMDB; nil/không đúng dạng dùng placeholder.
    // Các View khác không cần biết base URL hoặc cache của Kingfisher.
    private var url: URL? {
        guard let path, path.hasPrefix("/"), !path.isEmpty else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w500" + path)
    }

    var body: some View {
        // KFImage là View SwiftUI của Kingfisher, tương tự UIImageView + image loader.
        KFImage(url)
            .placeholder {
                ZStack {
                    Color.secondary.opacity(0.12)
                    Image(systemName: "photo").foregroundStyle(.secondary)
                }
            }
            .cancelOnDisappear(true)
            .resizable()
            .scaledToFill()
            .frame(width: width, height: height)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .accessibilityHidden(true)
    }
}

#if DEBUG
// #Preview khai báo một ví dụ UI cho Canvas của Xcode, không thêm màn hình vào app thật.
// nil dùng placeholder để học kích thước/crop mà không phụ thuộc tải ảnh từ mạng.
#Preview("Poster – placeholder", traits: .sizeThatFitsLayout) {
    PosterView(path: nil, width: 130, height: 195).padding()
}
#endif
