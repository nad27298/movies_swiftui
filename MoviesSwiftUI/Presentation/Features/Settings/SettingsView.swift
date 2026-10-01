//
//  SettingsView.swift
//  MoviesSwiftUI
//
//  Created by DaoNA3 on 01/10/2026.
//

import SwiftUI

// Form SwiftUI nhóm input native, gần một màn UITableView kiểu grouped chứa các control.
// @State sở hữu ViewModel; @Bindable tạo các binding tới draft cho Picker/Slider/DatePicker.
// Picker cần tag có cùng kiểu với selection; enum Hashable/CaseIterable giúp dựng lựa chọn an toàn.
// Slider ghi minimumRating vào draft, chưa gọi API hoặc UserDefaults.
// DatePicker dùng computed binding để giữ Domain ngày lịch thay vì lưu raw Date tùy múi giờ.
// Save là mốc áp dụng; rời màn bỏ draft qua resetDraft.
// NavigationStack cho toolbar/title và luồng một cột, tương ứng vai trò UINavigationController.


struct SettingsView: View {
    @Environment(AppRouter.self) private var router
    @Environment(SettingsStore.self) private var store
    @State private var model: SettingsViewModel

    init(store: SettingsStore) { _model = State(initialValue: SettingsViewModel(store: store)) }

    var body: some View {
        // @State sở hữu model; @Bindable không tạo model mới mà chỉ cung cấp binding tới nó.
        // Các binding đi vào draftSettings nên đổi control chưa phải Save.
        // Điểm khác với closure UIKit thường dùng là control có thể đọc và ghi cùng một nguồn state.
        @Bindable var model = model
        NavigationStack {
            // Form nhóm các input native. Binding ghi vào draft, chưa ghi vào UserDefaults.
            Form {
                if let warning = store.loadWarning { Text(warning).foregroundStyle(.orange) }
                Section("Danh sách phim") {
                    Picker("Loại", selection: $model.draftSettings.category) {
                        ForEach(MovieCategory.allCases) { Text($0.title).tag($0) }
                    }
                }
                Section("Bộ lọc local") {
                    Text("Điểm tối thiểu: \(model.draftSettings.minimumRating, specifier: "%.1f")")
                    Slider(value: $model.draftSettings.minimumRating, in: 0...10, step: 0.1)
                        .accessibilityLabel("Điểm tối thiểu")
                    DatePicker("Phát hành từ", selection: $model.releasePickerDate,
                               in: MovieReleaseDate.minimum.pickerDate..., displayedComponents: .date)
                    Text("App lọc trên các trang đã tải, không lọc toàn bộ TMDB.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Sắp xếp") {
                    Picker("Thứ tự", selection: $model.draftSettings.sort) {
                        ForEach(MovieSort.allCases) { Text($0.title).tag($0) }
                    }
                }
                Section {
                    Button("Lưu và tải lại Movies", action: model.save)
                    Text("Rời màn mà chưa lưu sẽ bỏ các thay đổi.").font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: AppTheme.contentWidth).frame(maxWidth: .infinity)
            .navigationTitle("Settings")
            .toolbar { MenuToolbar(router: router) }
            .onAppear { model.resetDraft() }
            .onDisappear { model.resetDraft() }
            .messageAlert($model.errorMessage)
        }
    }
}
