//
//  ProfileEditViewModel.swift
//  MoviesSwiftUI
//
//  Created by DaoNA3 on 01/10/2026.
//

import Foundation
import Observation
import PhotosUI
import UIKit
import ImageIO
import _PhotosUI_SwiftUI

// Owner của draft Profile và avatar chưa lưu, độc lập với ProfileStore đã áp dụng.
// Validation nằm ở đây để View tập trung vào dựng control.
// PhotosPickerItem trả dữ liệu qua loadTransferable async; thời gian hoàn thành không theo thứ tự chọn.
// imageToken xác định lựa chọn mới nhất, cancellation giảm công việc nhưng token vẫn cần kiểm tra.
// Ảnh thư viện được downsample bằng ImageIO trước khi tạo UIImage để giảm bitmap trong bộ nhớ.
// Ảnh camera resize theo tỷ lệ, không kéo méo thành một hình vuông.
// MainActor bảo vệ state UI; code xử lý bitmap đồng bộ ở đây không tự chạy background chỉ vì hàm gọi là async.
// Save chỉ công bố Profile qua store sau validation và persistence; Cancel không gọi Save.
// Task ảnh không phải dữ liệu UI nên được ObservationIgnored, isLoadingImage vẫn observable.


@MainActor @Observable final class ProfileEditViewModel {
    var draft: UserProfile
    var newAvatarData: Data?
    var errorMessage: String?
    private(set) var isSaving = false
    private(set) var isLoadingImage = false
    private let store: ProfileStore
    private var imageToken = UUID()
    @ObservationIgnored private var imageTask: Task<Void, Never>?

    init(store: ProfileStore) {
        self.store = store
        draft = store.profile
        if draft.birthday == nil { draft.birthday = MovieReleaseDate(year: 2000, month: 1, day: 1) }
    }

    var birthdayDate: Date {
        get { draft.birthday?.pickerDate ?? Date() }
        set { draft.birthday = MovieReleaseDate(pickerDate: newValue) }
    }

    var avatarData: Data? { newAvatarData ?? store.avatarData }

    // Mỗi lựa chọn mới vô hiệu hóa task/token cũ trước khi bắt đầu loadTransferable.
    // Sau await, kiểm tra cả Task cancellation và token trước khi xử lý/công bố ảnh.
    // defer chỉ tắt loading nếu còn thuộc lựa chọn hiện tại, không tắt spinner của ảnh mới hơn.
    // Lỗi lựa chọn cũ bị bỏ qua, tránh hiện alert cho một ảnh người dùng đã bỏ.
    func loadPhoto(_ item: PhotosPickerItem) {
        invalidateImageSelection()
        let token = imageToken
        isLoadingImage = true
        imageTask = Task { [weak self] in
            guard let self else { return }
            defer { if token == imageToken { isLoadingImage = false; imageTask = nil } }
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else { throw AppError.invalidInput("Không đọc được ảnh.") }
                try Task.checkCancellation()
                guard token == imageToken else { return }
                newAvatarData = try thumbnailJPEG(data)
            } catch is CancellationError { }
            catch {
                guard token == imageToken, !Task.isCancelled else { return }
                errorMessage = "Không xử lý được ảnh đã chọn. Vui lòng chọn ảnh khác."
            }
        }
    }

    // Ảnh camera có thể rất lớn và có orientation; draw tạo bitmap đã resize theo kích thước tỷ lệ.
    // Dùng cạnh dài nhất để tính factor, không ép width/height thành hai giá trị bằng nhau.
    // format.scale = 1 giúp kích thước bitmap tính theo pixel mục tiêu thay vì nhân scale màn hình.
    // Chỉ gán newAvatarData sau khi JPEG tạo thành công; Profile đã lưu vẫn chưa đổi.
    func cameraSelected(_ image: UIImage) {
        invalidateImageSelection()
        let longest = max(image.size.width, image.size.height)
        guard longest > 0 else { return }
        let factor = min(1, 500 / longest)
        let size = CGSize(width: image.size.width * factor, height: image.size.height * factor)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let data = resized.jpegData(compressionQuality: 0.85) else {
            errorMessage = "Không xử lý được ảnh camera."
            return
        }
        newAvatarData = data
    }

    // CGImageSource cho phép downsample trực tiếp từ dữ liệu nguồn trước khi tạo UIImage lớn.
    // CreateThumbnailWithTransform áp dụng orientation ảnh, MaxPixelSize giới hạn cạnh dài.
    // Phép xử lý này đồng bộ tại miền hiện tại; không coi await loadTransferable là tự đưa đoạn này background.
    // Nếu không decode/encode được ảnh, throws và giữ preview trước đó.
    private func thumbnailJPEG(_ data: Data) throws -> Data {
        // Downsample trước khi tạo UIImage, tránh giải mã toàn bộ ảnh độ phân giải lớn.
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 500
              ] as CFDictionary), let jpeg = UIImage(cgImage: image).jpegData(compressionQuality: 0.85) else {
            throw AppError.invalidInput("Không xử lý được ảnh.")
        }
        return jpeg
    }

    // Trim input trước validation để tên/email chỉ có khoảng trắng không được chấp nhận.
    // Email regex ở mức kiểm tra định dạng, không xác minh địa chỉ có tồn tại trên server.
    // Guard isSaving/isLoadingImage chặn Save trong khi ảnh chưa xác định xong hoặc đang Save.
    // Async signature thuận tiện cho action Task; persistence hiện tại bên trong vẫn đồng bộ trên MainActor.
    // Kết quả Bool chỉ cho View biết có được dismiss sau Save hay không.
    func save() async -> Bool {
        guard !isSaving, !isLoadingImage else { return false }
        draft.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.email = draft.email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !draft.name.isEmpty, draft.birthday != nil, !draft.email.isEmpty else {
            errorMessage = "Vui lòng nhập tên, ngày sinh và email."
            return false
        }
        guard let birthday = draft.birthday, birthday <= MovieReleaseDate(pickerDate: Date()) else {
            errorMessage = "Ngày sinh không được ở tương lai."
            return false
        }
        guard draft.email.range(of: #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#, options: .regularExpression) != nil else {
            errorMessage = "Email chưa đúng định dạng."
            return false
        }
        isSaving = true
        defer { isSaving = false }
        do {
            try store.save(draft, newAvatar: newAvatarData)
            return true
        } catch {
            errorMessage = AppError.storage.localizedDescription
            return false
        }
    }

    func invalidateImageSelection() {
        imageToken = UUID()
        imageTask?.cancel()
        imageTask = nil
        isLoadingImage = false
    }
}
