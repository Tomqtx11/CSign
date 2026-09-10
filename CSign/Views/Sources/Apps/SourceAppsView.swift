//
//  SourceAppsView.swift
//  CSign
//
//  Created by samara on 1.05.2025.
//

import SwiftUI
import AltSourceKit
import NimbleViews
import UIKit

// MARK: - Extension: View (Enil)
extension SourceAppsView {
	enum SortOption: String, CaseIterable {
		case `default` = "default"
		case name
		case date
		
		var displayName: String {
			switch self {
			case .default:  .localized("Default")
			case .name: 	.localized("Name")
			case .date: 	.localized("Date")
			}
		}
	}
}

// MARK: - View
struct SourceAppsView: View {
	@AppStorage("CSign.sortOptionRawValue") private var _sortOptionRawValue: String = SortOption.name.rawValue
	@AppStorage("CSign.sortAscending") private var _sortAscending: Bool = true
	
	@State private var _sortOption: SortOption = .name
	@State private var _selectedRoute: SourceAppRoute?
	
	@State var isLoading = true
	@State var hasLoadedOnce = false
	@State private var _searchText = ""
	@State private var _selectedCategory: String? = nil

	private var _availableCategories: [String] {
		guard let contexts = _sourceContexts else { return [] }
		var cats = Set<String>()
		for ctx in contexts {
			for app in ctx.repository.apps {
				cats.insert(app.category?.capitalized ?? String.localized("Others"))
			}
		}
		return cats.sorted()
	}

	private var _navigationTitle: String {
		if object.count == 1 {
			object[0].name ?? .localized("Unknown")
		} else {
			.localized("%lld Sources", arguments: object.count)
		}
	}
	
	var object: [AltSource]
	@ObservedObject var viewModel: SourcesViewModel
	@State private var _sourceContexts: [SourceRepositoryContext]?
	
	@ViewBuilder
	private var _categoryScrollView: some View {
		let cats = _availableCategories
		if !cats.isEmpty {
			ScrollView(.horizontal, showsIndicators: false) {
				HStack(spacing: 10) {
					Button(action: {
						withAnimation { _selectedCategory = nil }
					}) {
						Text(.localized("All"))
							.padding(.horizontal, 16)
							.padding(.vertical, 8)
							.background(_selectedCategory == nil ? Color.accentColor : Color(.secondarySystemFill))
							.foregroundColor(_selectedCategory == nil ? .white : .primary)
							.cornerRadius(20)
					}
					
					ForEach(cats, id: \.self) { cat in
						Button(action: {
							withAnimation { _selectedCategory = cat }
						}) {
							Text(cat)
								.padding(.horizontal, 16)
								.padding(.vertical, 8)
								.background(_selectedCategory == cat ? Color.accentColor : Color(.secondarySystemFill))
								.foregroundColor(_selectedCategory == cat ? .white : .primary)
								.cornerRadius(20)
						}
					}
				}
				.padding(.horizontal)
				.padding(.vertical, 8)
			}
			.background(Color(.systemBackground))
		}
	}

	// MARK: Body
	var body: some View {
		ZStack {
			if
				let _sourceContexts,
				!_sourceContexts.isEmpty
			{
				VStack(spacing: 0) {
					_categoryScrollView
					SourceAppsTableRepresentableView(
						sourceContexts: _sourceContexts,
						searchText: $_searchText,
						selectedCategory: $_selectedCategory,
						sortOption: $_sortOption,
						sortAscending: $_sortAscending,
						onSelect: {self._selectedRoute = $0}
					)
				}
			} else {
				ProgressView()
			}
		}
		.navigationTitle(_navigationTitle)
		.searchable(text: $_searchText, placement: .platform())
		.toolbar {
			NBToolbarMenu(
				systemImage: "line.3.horizontal.decrease",
				style: .icon,
				placement: .topBarTrailing
			) {
				_sortActions()
			}
		}
		.onAppear {
			if !hasLoadedOnce, viewModel.isFinished {
				_load()
				hasLoadedOnce = true
			}
			_sortOption = SortOption(rawValue: _sortOptionRawValue) ?? .name
		}
		.onChange(of: viewModel.isFinished) { _ in
			_load()
		}
		.onChange(of: _sortOption) { newValue in
			_sortOptionRawValue = newValue.rawValue
		}
		.navigationDestination(
			isPresented: Binding(
				get: { _selectedRoute != nil },
				set: { if !$0 { _selectedRoute = nil } }
			),
			destination: {
				if let route = _selectedRoute {
					SourceAppsDetailView(
						sourceURL: route.sourceURL,
						source: route.source,
						app: route.app
					)
				}
			}
		)
	}
	
	private func _load() {
		isLoading = true
		
		Task {
			let loadedSources = object.compactMap { source -> SourceRepositoryContext? in
				guard let repository = viewModel.sources[source] else { return nil }
				return SourceRepositoryContext(sourceURL: source.sourceURL, repository: repository)
			}
			_sourceContexts = loadedSources
			withAnimation(.easeIn(duration: 0.2)) {
				isLoading = false
			}
		}
	}
	
	struct SourceRepositoryContext: Equatable {
		let sourceURL: URL?
		let repository: ASRepository
		
		static func == (lhs: SourceRepositoryContext, rhs: SourceRepositoryContext) -> Bool {
			lhs.sourceURL == rhs.sourceURL &&
			lhs.repository.id == rhs.repository.id &&
			lhs.repository.name == rhs.repository.name &&
			lhs.repository.apps.map { "\($0.currentUniqueId)|\($0.currentVersion ?? "")" } ==
			rhs.repository.apps.map { "\($0.currentUniqueId)|\($0.currentVersion ?? "")" }
		}
	}
	
	struct SourceAppRoute: Identifiable, Hashable {
		let sourceURL: URL?
		let source: ASRepository
		let app: ASRepository.App
		let id: String = UUID().uuidString
	}
}

// MARK: - Extension: View (Sort)
extension SourceAppsView {
	@ViewBuilder
	private func _sortActions() -> some View {
		Section(.localized("Filter by")) {
			ForEach(SortOption.allCases, id: \.displayName) { opt in
				_sortButton(for: opt)
			}
		}
	}
	
	private func _sortButton(for option: SortOption) -> some View {
		Button {
			if _sortOption == option {
				_sortAscending.toggle()
			} else {
				_sortOption = option
				_sortAscending = true
			}
		} label: {
			HStack {
				Text(option.displayName)
				Spacer()
				if _sortOption == option {
					Image(systemName: _sortAscending ? "chevron.up" : "chevron.down")
				}
			}
		}
	}
}

import SwiftUI


