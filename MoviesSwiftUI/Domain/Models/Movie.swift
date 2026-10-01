//
//  Movie.swift
//  MoviesSwiftUI
//
//  Created by DaoNA3 on 01/10/2026.
//

import Foundation

// Các value model dùng cho dữ liệu phim và snapshot Favorite.
// struct có value semantics: truyền một Movie không chia sẻ một object mutable như class.
// Identifiable cung cấp id để ForEach nhận biết cùng một phim giữa những lần render.
// Hashable hỗ trợ so sánh/nhận diện giá trị; Codable kết hợp Encodable và Decodable.
// Sendable cho biết dữ liệu có thể truyền qua ranh giới concurrency một cách phù hợp.
// nonisolated tách model giá trị khỏi MainActor mặc định của target, nhất là khi JSON serializer làm việc.
// MovieReleaseDate chỉ biểu diễn ngày lịch Gregorian từ TMDB, không phải thời điểm có giờ/phút.
// Date cho reminder mang nghĩa thời điểm thực, nên không nên dùng hai kiểu này thay thế nhau.
// FavoriteMovie bọc snapshot Movie cùng savedAt, không biến thuộc tính Favorite thành dữ liệu của server.


// Ngày phát hành là ngày lịch, không đổi theo múi giờ như thời điểm của reminder.
nonisolated struct MovieReleaseDate: Codable, Hashable, Comparable, Sendable {
    let year: Int
    let month: Int
    let day: Int

    static let minimum = MovieReleaseDate(year: 1970, month: 1, day: 1)

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    // Failable initializer trả nil nếu ngày API thiếu hoặc không hợp lệ.
    // Tách ba phần số rồi kiểm tra lại bằng Calendar, vì ngày 31/02 có thể được calendar tự normalize.
    // Mapper coi nil là phim chưa có ngày, không suy ra một ngày giả để lọc/sort.
    init?(apiValue: String?) {
        guard let apiValue else { return nil }
        let parts = apiValue.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, (1...12).contains(parts[1]), (1...31).contains(parts[2]) else { return nil }
        self.init(year: parts[0], month: parts[1], day: parts[2])
        guard let date = Self.calendar.date(from: DateComponents(year: year, month: month, day: day)),
              Self.calendar.component(.year, from: date) == year,
              Self.calendar.component(.month, from: date) == month,
              Self.calendar.component(.day, from: date) == day else { return nil }
    }

    // DatePicker trao một thời điểm Date, nhưng Domain cần ngày lịch Gregorian.
    // Lấy thành phần ngày trong múi giờ local để lựa chọn trên picker không lệch sang hôm trước/hôm sau.
    // Dùng Gregorian rõ ràng để một thiết bị chọn lịch Buddhist không biến năm TMDB thành năm khác.
    init(pickerDate: Date) {
        let parts = Self.pickerCalendar.dateComponents([.year, .month, .day], from: pickerDate)
        self.init(year: parts.year ?? 1970, month: parts.month ?? 1, day: parts.day ?? 1)
    }

    // Computed property chuyển chiều ngược lại cho control UI.
    // Không lưu thêm pickerDate cạnh year/month/day, tránh hai nguồn dữ liệu cho cùng ngày.
    // Date fallback chỉ phục vụ trường hợp dữ liệu ngày không biểu diễn được.
    var pickerDate: Date {
        Self.pickerCalendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
    }

    var displayText: String { String(format: "%02d/%02d/%04d", day, month, year) }
    // Mã số YYYYMMDD giữ đúng thứ tự ngày lịch đối với các ngày hợp lệ của app.
    // Comparable cung cấp <; Swift suy ra các toán tử >, <=, >= để filter/sort dùng cùng quy tắc.
    // Không so sánh chuỗi định dạng dd/MM/yyyy vì thứ tự chữ không phải thứ tự thời gian.
    private var orderingValue: Int { year * 10_000 + month * 100 + day }
    static func < (lhs: Self, rhs: Self) -> Bool { lhs.orderingValue < rhs.orderingValue }

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private static var pickerCalendar: Calendar {
        // TMDB dùng lịch Gregorian kể cả khi thiết bị chọn lịch khác; picker vẫn dùng múi giờ local.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }
}

nonisolated struct Movie: Identifiable, Codable, Hashable, Sendable {
    let id: Int
    let title: String
    let overview: String
    let posterPath: String?
    let rating: Double
    let releaseDate: MovieReleaseDate?
    let isAdult: Bool

    // String(format:) cố định một chữ số thập phân theo cách hiển thị của app mẫu.
    // Đây là giá trị tính từ rating, không cần lưu thêm một chuỗi có thể lệch với Double gốc.
    var ratingText: String { String(format: "%.1f/10", rating) }
}

nonisolated struct FavoriteMovie: Identifiable, Sendable {
    let movie: Movie
    let savedAt: Date
    var id: Int { movie.id }
}
