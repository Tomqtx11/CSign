//
//  InstallationView.swift
//  CSign
//
//  Created by samara on 3.06.2025.
//

import SwiftUI
import NimbleViews

// MARK: - View
struct InstallationView: View {
	@AppStorage("CSign.installationMethod") private var _installationMethod: Int = 0

	// MARK: Body
	var body: some View {
		NBList(.localized("Cài Đặt Cục Bộ")) {
			Section {
				HStack {
					Label(.localized("Máy Chủ Local (Mặc Định)"), systemImage: "server.rack")
					Spacer()
					Image(systemName: "checkmark").foregroundColor(.accentColor)
				}
			} footer: {
				Text("Sau khi đóng gói, CSign mở trình cài đặt của iOS. Nếu cách mở trực tiếp không phản hồi, CSign chuyển qua Safari: bấm Cài đặt và xác nhận thông báo của iPhone.")
			}
			
			ServerView()
		}
		.onAppear {
			// Luôn ép kiểu là 0 (Server Local)
			if _installationMethod != 0 {
				_installationMethod = 0
			}
		}
	}
}

