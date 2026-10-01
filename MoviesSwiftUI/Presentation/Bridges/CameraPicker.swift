//
//  CameraPicker.swift
//  MoviesSwiftUI
//
//  Created by DaoNA3 on 01/10/2026.
//

import SwiftUI
import UIKit

// UIViewControllerRepresentable đưa UIImagePickerController vào cây SwiftUI.
// makeUIViewController tạo controller một lần theo lifecycle bridge; update không tạo controller mới.
// Coordinator là NSObject triển khai delegate UIKit và chuyển kết quả thành closure cho màn SwiftUI.
// SwiftUI struct View có thể được tạo lại nhiều lần nên không dùng chính struct làm delegate reference.
// @Environment dismiss đóng sheet đang chứa bridge, không sửa Profile đã lưu.
// Delegate cancel chỉ đóng picker, không xóa ảnh draft trước đó.
// Closure selected chuyển UIImage lên ViewModel để xử lý; camera bridge không lưu UserDefaults/database.


// SwiftUI chưa có camera picker tương đương; bridge dùng delegate qua Coordinator.
struct CameraPicker: UIViewControllerRepresentable {
    let selected: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    // Coordinator là reference object để UIKit giữ delegate ổn định.
    // Nó nhận struct bridge hiện tại để gọi closure selected và DismissAction.
    // make/update/dismantle của Representable khác với body được tính lại của một View bình thường.
    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ controller: UIImagePickerController, context: Context) { }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let parent: CameraPicker
        init(parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { parent.selected(image) }
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}
