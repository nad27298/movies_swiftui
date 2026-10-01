//
//  ProfileEditView.swift
//  MoviesSwiftUI
//
//  Created by DaoNA3 on 01/10/2026.
//

import SwiftUI
import PhotosUI
import AVFoundation
import UIKit

// Editor native với Form, PhotosPicker và bridge camera UIKit.
// @State giữ ViewModel/draft và các state presentation thuần UI như cameraPresented.
// PhotosPicker không yêu cầu app đọc toàn bộ thư viện; item chọn được xử lý bất đồng bộ ở model.
// onChange là nơi chuyển lựa chọn mới sang model, không load ảnh trong body.
// Camera cần kiểm tra availability và authorization trước khi present.
// isRequestingCamera ngăn nhiều lần bấm tạo nhiều request quyền/presentation.
// @Environment dismiss pop editor hoặc đóng presentation theo ngữ cảnh hiện tại.
// Dữ liệu ảnh được preview từ draft; rời editor hủy lựa chọn đang tải để nó không sửa state đã bỏ.


struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: ProfileEditViewModel
    @State private var photoItem: PhotosPickerItem?
    @State private var cameraPresented = false
    @State private var isRequestingCamera = false
    @State private var isVisible = false

    init(store: ProfileStore) { _model = State(initialValue: ProfileEditViewModel(store: store)) }

    var body: some View {
        @Bindable var model = model
        Form {
            Section("Ảnh đại diện") {
                AvatarView(data: model.avatarData, size: 100).frame(maxWidth: .infinity)
                PhotosPicker(selection: $photoItem, matching: .images) { Label("Chọn từ thư viện", systemImage: "photo") }
                    .disabled(model.isSaving)
                Button { Task { await openCamera() } } label: { Label("Chụp ảnh", systemImage: "camera") }
                    .disabled(model.isSaving || isRequestingCamera)
                if model.isLoadingImage { ProgressView("Đang xử lý ảnh…") }
            }
            Section("Thông tin") {
                TextField("Tên", text: $model.draft.name).textContentType(.name)
                DatePicker("Ngày sinh", selection: $model.birthdayDate, in: ...Date(), displayedComponents: .date)
                TextField("Email", text: $model.draft.email)
                    .textContentType(.emailAddress).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                Picker("Giới tính", selection: $model.draft.gender) {
                    ForEach(ProfileGender.allCases) { Text($0.title).tag($0) }
                }
            }
        }
        .frame(maxWidth: AppTheme.contentWidth).frame(maxWidth: .infinity)
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(model.isSaving)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Lưu") { Task { if await model.save() { dismiss() } } }
                    .disabled(model.isSaving || model.isLoadingImage)
            }
        }
        .interactiveDismissDisabled(model.isSaving)
        .onChange(of: photoItem) { _, item in if let item { model.loadPhoto(item) } }
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false; model.invalidateImageSelection() }
        .sheet(isPresented: $cameraPresented) { CameraPicker(selected: model.cameraSelected).ignoresSafeArea() }
        .messageAlert($model.errorMessage)
    }

    // Chặn bấm lặp trước khi await dialog quyền.
    // Availability kiểm tra riêng với authorization: có quyền không có nghĩa thiết bị có camera.
    // Sau await kiểm tra editor còn hiển thị để không mở camera cho một màn đã rời.
    // CameraPicker chỉ được present sau khi có quyền và ngữ cảnh vẫn hợp lệ.
    private func openCamera() async {
        guard !isRequestingCamera else { return }
        isRequestingCamera = true
        defer { isRequestingCamera = false }
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            model.errorMessage = "Thiết bị này không có camera khả dụng."
            return
        }
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        let granted: Bool
        if status == .notDetermined { granted = await AVCaptureDevice.requestAccess(for: .video) }
        else { granted = status == .authorized }
        guard isVisible else { return }
        if granted {
            model.invalidateImageSelection()
            cameraPresented = true
        } else { model.errorMessage = "Chưa có quyền camera. Bạn có thể cấp quyền trong Cài đặt hệ thống." }
    }
}

struct AvatarView: View {
    let data: Data?
    var size: CGFloat = 72
    var body: some View {
        Group {
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill").resizable().scaledToFit().foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size).clipShape(Circle()).accessibilityLabel("Ảnh đại diện")
    }
}

#if DEBUG
// Form không sở hữu NavigationStack vì khi chạy app nó được push từ menu.
// Preview bọc stack để hiện title/nút Save. Dữ liệu profile dùng repository mẫu.
// PhotosPicker/camera là UI hệ thống: kiểm tra chúng bằng Simulator/thiết bị thật.
#Preview("Chỉnh hồ sơ") {
    PreviewHost { context in
        NavigationStack {
            ProfileEditView(store: context.profile)
        }
    }
}

// Avatar là component độc lập: không cần tạo toàn bộ store để xem hình mặc định.
#Preview("Avatar mặc định", traits: .sizeThatFitsLayout) {
    AvatarView(data: nil, size: 100).padding()
}
#endif
