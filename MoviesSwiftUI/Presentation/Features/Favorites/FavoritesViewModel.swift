//
//  FavoritesViewModel.swift
//  MoviesSwiftUI
//
//  Created by DaoNA3 on 01/10/2026.
//

import Foundation
import Observation
import Combine

// Tách hai giá trị searchText và appliedQuery để minh họa debounce.
// searchText đổi ngay theo binding UI; appliedQuery chỉ đổi sau khi người dùng ngừng nhập 300 ms.
// PassthroughSubject phát input, không tự lưu giá trị hiện tại như một state property.
// removeDuplicates tránh xử lý query liên tiếp giống nhau; debounce hoãn phát tới sink.
// AnyCancellable giữ subscription và cho phép hủy rõ ràng.
// Observation dựng lại UI theo appliedQuery/library; Combine không làm toàn bộ binding của app.
// computed visibleFavorites đọc snapshot mới nên Favorite thay đổi ở màn khác vẫn cập nhật kết quả.
// Weak capture tránh chu kỳ giữ object, token chặn callback cũ sau Clear/reset/rời màn.


@MainActor @Observable final class FavoritesViewModel {
    var searchText = ""
    private(set) var appliedQuery = ""
    private let library: MovieLibraryStore
    // Subject và subscription là công cụ điều phối, không phải các giá trị UI cần render.
    // Không dựa vào @Observable để phát publisher: subject được tạo và send rõ ràng.
    // Token là danh tính một pipeline, không phải ID của phim hoặc request network.
    @ObservationIgnored private var subject = PassthroughSubject<String, Never>()
    @ObservationIgnored private var cancellable: AnyCancellable?
    private var subscriptionToken = UUID()

    init(library: MovieLibraryStore) { self.library = library }

    // Computed property đọc cả appliedQuery và shared favorites.
    // Sau khi debounce đã áp dụng query, một phim thêm/xóa từ Detail vẫn đổi kết quả mà không cần send query lại.
    // range options bỏ qua chữ hoa/thường và dấu; đây là search local theo tên snapshot.
    var visibleFavorites: [FavoriteMovie] {
        guard !appliedQuery.isEmpty else { return library.favorites }
        return library.favorites.filter {
            $0.movie.title.range(of: appliedQuery, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    func searchChanged() {
        if searchText.isEmpty { reset() }
        else { subject.send(searchText.trimmingCharacters(in: .whitespacesAndNewlines)) }
    }

    // Clear cần có hiệu lực ngay, không đợi thêm 300 ms.
    // Hủy subscription, đổi token, xóa query và dựng pipeline mới để input cũ không quay lại.
    // Callback sink có thể đã tạo Task lên MainActor trước cancel, nên token vẫn cần kiểm tra.
    // Tạo lại subject cũng reset bộ nhớ removeDuplicates của subscription cũ.
    func reset() {
        cancellable?.cancel()
        subscriptionToken = UUID()
        searchText = ""
        appliedQuery = ""
        subject = PassthroughSubject<String, Never>()
        let token = subscriptionToken
        // Observation cập nhật View; Combine chỉ quyết định lúc áp dụng query.
        cancellable = subject.removeDuplicates()
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            // sink được gọi trên scheduler của debounce, nhưng state UI vẫn được chuyển vào MainActor rõ ràng.
            // weak self không tạo vòng self → cancellable → closure → self.
            // Task tới muộn phải khớp token, tránh Clear/rời màn xong query cũ lại được áp dụng.
            .sink { [weak self] query in
                Task { @MainActor [weak self] in
                    guard let self, self.subscriptionToken == token else { return }
                    self.appliedQuery = query
                }
            }
    }

    // Đổi token trước cancel để callback đã xếp hàng cũng bị vô hiệu.
    // Không cần tự remove observer NotificationCenter vì luồng này dùng Combine subscription.
    // Lần vào sau reset sẽ tạo subscription mới theo hành vi app mẫu.
    func disappear() {
        subscriptionToken = UUID()
        cancellable?.cancel()
        cancellable = nil
    }
}
