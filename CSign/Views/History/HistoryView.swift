//
//  HistoryView.swift
//  CSign
//
//  Created by AI on 10.09.2026.
//

import SwiftUI
import NimbleViews

struct HistoryView: View {
    @StateObject private var historyManager = HistoryManager.shared
    @State private var showingApplyAlert = false
    
    var body: some View {
        NBNavigationView(.localized("Lịch sử Ký")) {
            if historyManager.history.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.badge.exclamationmark")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text(.localized("Chưa có lịch sử ký nào."))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(historyManager.history) { item in
                        Button {
                            OptionsManager.shared.options = item.options
                            OptionsManager.shared.saveOptions()
                            showingApplyAlert = true
                            
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.success)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(item.appName)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text(item.appIdentifier)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(item.dateSigned.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .onDelete(perform: historyManager.removeHistory)
                }
            }
        }
        .alert(.localized("Đã áp dụng cấu hình"), isPresented: $showingApplyAlert) {
            Button(.localized("OK"), role: .cancel) { }
        } message: {
            Text(.localized("Cấu hình ký của ứng dụng này đã được khôi phục. Bạn có thể chọn một file IPA mới để ký với cấu hình này."))
        }
    }
}
