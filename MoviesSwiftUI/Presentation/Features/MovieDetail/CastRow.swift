//
//  CastRow.swift
//  MoviesSwiftUI
//
//  Created by DaoNA3 on 01/10/2026.
//

import SwiftUI

// Component hiển thị diễn viên theo hàng ngang.
// ScrollView(.horizontal) cho cuộn, LazyHStack dựng các item khi cần.
// Vai trò gần collection view ngang, nhưng không cần dataSource/delegate cho cell.
// ForEach dùng CastMember.id đã được repository loại trùng.
// Ảnh profile có thể nil; PosterView dùng cùng cơ chế placeholder/cache với poster phim.
// Không có navigation diễn viên vì app mẫu không có luồng này.


struct CastRow: View {
    let members: [CastMember]
    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: 16) {
                ForEach(members) { member in
                    VStack(alignment: .leading, spacing: 6) {
                        PosterView(path: member.profilePath, width: 100, height: 140)
                        Text(member.name).font(.subheadline).bold()
                        Text(member.character).font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(width: 100, alignment: .leading)
                }
            }
        }
    }
}

#if DEBUG
#Preview("Diễn viên", traits: .sizeThatFitsLayout) {
    CastRow(members: PreviewSampleData.cast).padding()
}
#endif
