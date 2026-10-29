import SwiftUI

struct ShelfToolLibrary: View {
    @ObservedObject var store: QuickToolsStore
    var onSelect: () -> Void
    @State private var query = ""
    private var matches: [QuickToolTab] { ShelfToolSearch.matches(query) }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(privacyText("A little more capable.", "작은 도구, 더 많은 가능성.")).font(.headline)
                    Text(privacyText("Your tools, one click away.", "필요한 도구를 한 번에 찾아보세요.")).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "square.grid.2x2.fill").foregroundStyle(.mint).font(.title2)
            }
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField(privacyText("Search tools…", "도구 검색…"), text: $query).textFieldStyle(.plain)
                    .accessibilityIdentifier("shelf.toolSearch")
                    .onSubmit { if let first = matches.first { select(first) } }
            }.padding(10).background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 7) {
                    ForEach(matches) { tab in
                        Button { select(tab) } label: {
                            HStack(spacing: 8) {
                                Image(systemName: tab.systemImage)
                                    .font(.system(size: 13, weight: .medium)).foregroundStyle(tint(tab.id))
                                    .frame(width: 30, height: 30).background(tint(tab.id).opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
                                Text(L10n.app(tab.titleKey)).font(.system(size: 11, weight: .medium)).lineLimit(2)
                                Spacer(minLength: 0)
                                if store.selectedTool == tab.id {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.mint).font(.caption)
                                }
                            }
                            .padding(7).frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
                            .background(.primary.opacity(store.selectedTool == tab.id ? 0.08 : 0.035), in: RoundedRectangle(cornerRadius: 12))
                        }.buttonStyle(.plain).accessibilityIdentifier("shelf.library.\(tab.id)")
                    }
                }
            }.frame(height: 220)
            if matches.isEmpty { Text(privacyText("No matching tools", "일치하는 도구가 없습니다")).font(.caption).foregroundStyle(.secondary) }
        }.padding(16).frame(width: 390)
            .background(Color(red: 0.085, green: 0.09, blue: 0.105))
            .environment(\.colorScheme, .dark)
    }
    private func select(_ tab: QuickToolTab) {
        store.setTabEnabled(tab.id, enabled: true)
        store.selectedTool = tab.id
        onSelect()
    }
    private func tint(_ id: String) -> Color {
        switch id {
        case "focus", "stopwatch", "awake": .orange
        case "notes", "snippets", "tasks": .yellow
        case "developer", "stats", "jobs": .purple
        case "transform", "cases", "color": .pink
        default: .mint
        }
    }
}

enum ShelfToolSearch {
    static func matches(_ query: String) -> [QuickToolTab] {
        let clean = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return QuickToolTab.allTabs.filter { tab in
            clean.isEmpty || tab.id.localizedCaseInsensitiveContains(clean)
                || L10n.app(tab.titleKey).localizedCaseInsensitiveContains(clean)
                || L10n.string(tab.titleKey, language: .english).localizedCaseInsensitiveContains(clean)
                || L10n.string(tab.titleKey, language: .korean).localizedCaseInsensitiveContains(clean)
        }
    }
}
