//
//  ReminderEditorViewModel.swift
//  MoviesSwiftUI
//
//  Created by DaoNA3 on 01/10/2026.
//

import Foundation
import Observation

// Owner của thời điểm draft và kết quả thao tác Save.
// DatePicker có thể giữ giờ cũ nếu editor mở lâu nên Save phải kiểm tra lại với Date() hiện tại.
// Bỏ phần giây để dữ liệu local khớp calendar trigger có độ chính xác phút.
// isSaving khóa lần bấm lặp; store tiếp tục giữ Task cho toàn bộ luồng local + notification.
// Kết quả scheduled có thể đóng editor, savedWithoutNotification giữ editor để người dùng biết và thử lại.
// warningMessage khác errorMessage: warning nghĩa local đã lưu, không nên nói tất cả bước thất bại.
// Không tự xin quyền notification trong ViewModel; side effect nằm ở scheduler thông qua use case/store.


@MainActor @Observable final class ReminderEditorViewModel {
    var selectedDate: Date
    var errorMessage: String?
    var warningMessage: String?
    private(set) var isSaving = false
    private let movie: Movie
    private let library: MovieLibraryStore

    init(movie: Movie, library: MovieLibraryStore) {
        self.movie = movie
        self.library = library
        let existing = library.reminder(for: movie.id)?.scheduledAt
        selectedDate = existing.flatMap { $0 > Date() ? $0 : nil } ?? Date().addingTimeInterval(3600)
    }

    // Chuẩn hóa xuống phút bằng timestamp để giữ đúng thời điểm, kể cả giờ lặp khi chuyển DST.
    // So với Date() ngay lúc Save vì giới hạn UI có thể đã cũ từ lúc editor mở.
    // Store giữ Task dài hạn; isSaving của editor chỉ phục vụ guard/control/presentation.
    // Outcome warning không trả true, nên editor không tự biến mất trước khi người dùng thấy cảnh báo.
    func save() async -> Bool {
        guard !isSaving else { return false }
        // DatePicker có thể giữ giá trị cũ khi sheet mở lâu: kiểm tra lại ở thời điểm Save.
        // Bỏ giây bằng timestamp để không mất lựa chọn ở phút lặp lại khi chuyển DST.
        let date = Date(timeIntervalSince1970: floor(selectedDate.timeIntervalSince1970 / 60) * 60)
        guard date > Date() else {
            errorMessage = "Vui lòng chọn thời điểm trong tương lai."
            return false
        }
        isSaving = true
        defer { isSaving = false }
        do {
            let outcome = try await library.saveReminder(movie: movie, date: date)
            switch outcome {
            case .scheduled: return true
            case .savedWithoutNotification(let message): warningMessage = message; return false
            }
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
