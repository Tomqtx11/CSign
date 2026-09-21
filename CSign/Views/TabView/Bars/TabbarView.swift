//
//  TabbarView.swift
//  csign
//
//  Created by samara on 23.03.2025.
//

import SwiftUI

struct TabbarView: View {
	@State private var selectedTab: TabEnum = .sources
	@State private var _showMissingCertAlert = false

	var body: some View {
		TabView(selection: $selectedTab) {
			ForEach(TabEnum.defaultTabs, id: \.hashValue) { tab in
				TabEnum.view(for: tab)
					.tabItem {
						Label(tab.title, systemImage: tab.icon)
					}
					.tag(tab)
			}
		}
		.onAppear {
			_checkCertificates()
		}
		.alert("Thiếu Chứng Chỉ", isPresented: $_showMissingCertAlert) {
			Button("Nhập Ngay") {
				_showCertificatesSheet = true
			}
			Button("Để Sau", role: .cancel) { }
		} message: {
			Text("Bạn chưa có chứng chỉ nào để ký ứng dụng. Vui lòng nhập chứng chỉ (.p12 và .mobileprovision) để tiếp tục.")
		}
		.sheet(isPresented: $_showCertificatesSheet) {
			NBNavigationView(.localized("Certificates")) { CertificatesView() }
		}
	}
	
	@State private var _showCertificatesSheet = false
	
	private func _checkCertificates() {
		let certs = Storage.shared.getAllCertificates()
		if certs.isEmpty {
			_showMissingCertAlert = true
		}
	}
}
