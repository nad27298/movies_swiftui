//
//  PersistenceContainer.swift
//  MoviesSwiftUI
//
//  Created by DaoNA3 on 01/10/2026.
//

import SwiftData

// Factory mở ModelContainer với schema FavoriteRecord và ReminderRecord.
// ModelContainer quản lý schema và persistent store; ModelContext quản lý các thay đổi trên model.
// Gần tương ứng NSPersistentContainer và NSManagedObjectContext của Core Data.
// Không thêm Item của template vì app mới có hai loại dữ liệu local riêng.
// Hàm throws để AppBootstrap hiển thị lỗi và thử lại, không crash hoặc xóa store.
// Container sống theo AppDependencies, không tạo lại trong body của View.


@MainActor enum PersistenceContainer {
    static func make() throws -> ModelContainer {
        try ModelContainer(for: FavoriteRecord.self, ReminderRecord.self)
    }
}
