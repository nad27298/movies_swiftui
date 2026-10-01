//
//  SettingsViewModel.swift
//  MoviesSwiftUI
//
//  Created by DaoNA3 on 01/10/2026.
//

import Foundation
import Observation

// Owner của draft Settings, không ghi trực tiếp vào settings đã áp dụng mỗi khi Slider đổi.
// MovieSettings là struct nên gán từ store tạo một bản value để chỉnh sửa.
// releasePickerDate là computed property chuyển Date của control sang ngày lịch Domain.
// Binding có thể ghi qua setter computed property như với một biến lưu thông thường.
// resetDraft dùng khi vào/rời màn để bỏ thay đổi chưa Save.
// Save gọi store; store lưu trước rồi mới tăng revision cho Movies.
// Lỗi lưu nằm trong observable state để View hiển thị mà không phải truyền UIViewController vào model.


@MainActor @Observable final class SettingsViewModel {
    var draftSettings = MovieSettings()
    var errorMessage: String?
    private let store: SettingsStore
    init(store: SettingsStore) { self.store = store }

    // Getter/setter tạo adapter giữa DatePicker và MovieReleaseDate của draft.
    // $property từ @Bindable vẫn ghi được qua setter computed property này.
    // Không giữ thêm một Date mutable rồi phải onChange đồng bộ với ngày Domain ở cả hai chiều.
    var releasePickerDate: Date {
        get { draftSettings.minimumReleaseDate.pickerDate }
        set { draftSettings.minimumReleaseDate = MovieReleaseDate(pickerDate: newValue) }
    }

    func resetDraft() { draftSettings = store.appliedSettings }
    func save() {
        do { try store.save(draftSettings) }
        catch { errorMessage = AppError.storage.localizedDescription }
    }
}
