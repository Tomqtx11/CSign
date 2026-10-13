//
//  TabbarView.swift
//  csign
//
//  Created by samara on 23.03.2025.
//

import SwiftUI
import NimbleViews

struct TabbarView: View {
	@AppStorage("CSign.activeTab") private var selectedTab = TabEnum.today.rawValue

	var body: some View {
		TabView(selection: $selectedTab) {
			ForEach(TabEnum.defaultTabs, id: \.hashValue) { tab in
				TabEnum.view(for: tab)
					.tabItem {
						Label(tab.title, systemImage: tab.icon)
					}
					.tag(tab.rawValue)
			}
		}
        .onAppear {
            if !TabEnum.defaultTabs.contains(where: { $0.rawValue == selectedTab }) { selectedTab = TabEnum.today.rawValue }
        }
	}
}
