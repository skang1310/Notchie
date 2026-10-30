import SwiftUI
internal import AppKit

struct ClipboardSnippetsView: View {
    var maxItems: Int? = nil
    var onOpenSettings: (() -> Void)? = nil
    @ObservedObject private var storage = ProductivityStorage.shared
    @AppStorage("DynamicNotch.Clipboard.kind.v1") private var kindRaw = "all"
    @AppStorage("DynamicNotch.Clipboard.favoritesOnly.v1") private var favoritesOnly = false
    @AppStorage("DynamicNotch.Clipboard.oldestFirst.v1") private var oldestFirst = false
    @State private var searchQuery = ""
    @State private var copiedSnippetID: UUID?
    @State private var showingSettings = false
    @State private var confirmingClear = false
    @State private var preview: SavedSnippet?
    @State private var message = ""
    private var kind: ClipboardKind { ClipboardKind(rawValue: kindRaw) ?? .all }
    private var filteredItems: [SavedSnippet] {
        storage.filteredSnippets(query: searchQuery, kind: kind, favoritesOnly: favoritesOnly, oldestFirst: oldestFirst)
    }
    private var displayedItems: [SavedSnippet] {
        if let maxItems {
            return Array(filteredItems.prefix(maxItems))
        }
        return filteredItems
    }
    private var removableCount: Int { storage.document.snippets.filter { $0.isFavorite != true }.count }

    var body: some View {
        VStack(spacing: 8) {
            header
            searchBar
            if filteredItems.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: favoritesOnly ? "star" : "doc.on.clipboard").font(.system(size: 25, weight: .light)).foregroundStyle(.secondary)
                    Text(privacyText("Nothing here yet", "아직 표시할 항목이 없어요")).font(.callout.weight(.medium))
                    Text(privacyText("Capture copied text, or change your search and filters.", "복사한 텍스트를 저장하거나 검색·필터를 바꿔보세요."))
                        .font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(displayedItems) { snippet in
                            ClipboardHistoryRow(snippet: snippet, copied: copiedSnippetID == snippet.id,
                                onCopy: { copy(snippet) },
                                onStar: { storage.toggleSnippetFavorite(snippet.id) },
                                onPreview: { preview = snippet },
                                onRemove: { storage.update { $0.snippets.removeAll { $0.id == snippet.id } } })
                        }

                        if let maxItems, filteredItems.count > maxItems {
                            let remaining = filteredItems.count - maxItems
                            Button {
                                if let onOpenSettings {
                                    onOpenSettings()
                                } else {
                                    SettingsWindowController.shared.showWindow()
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "ellipsis.circle.fill")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(Color.mint)

                                    Text(privacyText("+\(remaining) more in App Settings…", "외 \(remaining)개 항목은 앱 설정에서 보기…"))
                                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.92))

                                    Spacer()

                                    Image(systemName: "arrow.up.forward.app")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.6))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.white.opacity(0.06))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 6)
                            .padding(.top, 4)
                            .padding(.bottom, 6)
                        }
                    }
                }
                .scrollIndicators(.visible)
                .accessibilityIdentifier("clipboard.history")
            }
            HStack(spacing: 6) {
                Circle().fill(storage.isAutoCaptureClipboardEnabled ? Color.green : Color.secondary).frame(width: 4, height: 4)
                Text(storage.isAutoCaptureClipboardEnabled ? privacyText("Auto-save on", "자동 저장 중") : privacyText("Manual capture", "직접 저장"))
                if let maxItems, filteredItems.count > maxItems {
                    Text("· \(privacyText("Recent \(maxItems) of", "최근 \(maxItems)건 / 전체")) \(filteredItems.count)")
                } else {
                    Text("· \(filteredItems.count) / \(storage.document.snippets.count)")
                }
                Spacer()
                Text(message.isEmpty ? privacyText("Return to copy · Right-click for more", "Enter로 복사 · 우클릭으로 더 보기") : message).lineLimit(1)
            }.font(.system(size: 9)).foregroundStyle(.secondary)
        }
        .padding(8)
        .confirmationDialog(privacyText("Clear clipboard history?", "클립보드 내역을 정리할까요?"), isPresented: $confirmingClear, titleVisibility: .visible) {
            Button(privacyText("Delete \(removableCount) unstarred items", "즐겨찾기를 제외한 \(removableCount)개 삭제"), role: .destructive) {
                _ = storage.removeUnstarredSnippets()
            }
            Button(privacyText("Cancel", "취소"), role: .cancel) {}
        } message: { Text(privacyText("Starred items are kept. This clears all unstarred history, including items outside the current filter.", "즐겨찾기는 남겨둡니다. 현재 검색·필터 밖의 항목을 포함해 즐겨찾기가 아닌 내역을 삭제합니다.")) }
        .popover(item: $preview) { item in
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(privacyText("Clipboard preview", "클립보드 미리보기"), systemImage: item.clipboardKind.symbol).font(.headline)
                    Spacer()
                    Button(privacyText("Copy all", "전체 복사")) { copy(item) }
                }
                ScrollView { Text(String(item.text.prefix(15_000))).font(.system(size: 12, design: item.clipboardKind == .code ? .monospaced : .default)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                    .frame(maxHeight: 250)
                if item.text.count > 15_000 { Text(privacyText("Preview shortened. Copy includes the full item.", "미리보기는 일부만 표시합니다. 복사하면 전체 내용이 복사됩니다.")).font(.caption).foregroundStyle(.secondary) }
            }.padding(16).frame(width: 430).background(Color(red: 0.085, green: 0.09, blue: 0.105)).environment(\.colorScheme, .dark).preferredColorScheme(.dark)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Button { capture() } label: { Image(systemName: "square.and.pencil").frame(width: 25, height: 25) }
                .buttonStyle(.plain).background(.primary.opacity(0.06), in: Circle())
                .help(privacyText("Capture current clipboard", "현재 클립보드 저장"))
                .accessibilityLabel(privacyText("Capture current clipboard", "현재 클립보드 저장"))
                .accessibilityIdentifier("clipboard.capture")
            Spacer(minLength: 0)
            HStack(spacing: 2) {
                segment(privacyText("Clipboard", "클립보드"), selected: !favoritesOnly) { favoritesOnly = false }
                segment(privacyText("Starred", "즐겨찾기"), selected: favoritesOnly) { favoritesOnly = true }
            }.padding(3).background(.primary.opacity(0.05), in: Capsule()).overlay(Capsule().strokeBorder(.primary.opacity(0.08), lineWidth: 0.7))
            Spacer(minLength: 0)
            Button { showingSettings.toggle() } label: { Image(systemName: "gearshape").frame(width: 25, height: 25) }
                .buttonStyle(.plain).background(.primary.opacity(0.06), in: Circle())
                .help(privacyText("Clipboard settings", "클립보드 설정"))
                .accessibilityLabel(privacyText("Clipboard settings", "클립보드 설정"))
                .popover(isPresented: $showingSettings) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(privacyText("Clipboard", "클립보드")).font(.headline)
                        Toggle(privacyText("Automatically save copied text", "복사한 텍스트 자동 저장"), isOn: $storage.isAutoCaptureClipboardEnabled).toggleStyle(.switch).controlSize(.small)
                        Text(privacyText("Saved locally. Concealed clipboard items are excluded. Source labels show the foreground app observed at capture time, not a guaranteed original source.", "기기에만 저장하며 숨김 처리된 클립보드 항목은 제외합니다. 출처는 수집 시 앞에 있던 앱이며 실제 원본 앱과 다를 수 있습니다."))
                            .font(.caption).foregroundStyle(.secondary)
                    }.padding(16).frame(width: 300).background(Color(red: 0.085, green: 0.09, blue: 0.105)).environment(\.colorScheme, .dark).preferredColorScheme(.dark)
                }
        }.frame(height: 28)
    }
    private func segment(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 11, weight: selected ? .semibold : .medium))
                .foregroundStyle(selected ? Color.primary : Color.secondary)
                .padding(.horizontal, 12).padding(.vertical, 4)
                .background(selected ? Color.primary.opacity(0.1) : Color.clear, in: Capsule())
        }.buttonStyle(.plain)
    }
    private var searchBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField(privacyText("Search clipboard…", "클립보드 검색…"), text: $searchQuery)
                    .textFieldStyle(.plain).font(.system(size: 12))
                    .accessibilityIdentifier("clipboard.searchField")
                    .onSubmit { if let item = filteredItems.first { copy(item) } }
                if !searchQuery.isEmpty {
                    Button { searchQuery = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }.buttonStyle(.plain)
                }
                if kind != .all { Text(kind.title).font(.system(size: 9, weight: .semibold)).foregroundStyle(.mint) }
            }.padding(.horizontal, 11).frame(height: 30)
                .background(.primary.opacity(0.035), in: Capsule())
                .overlay(Capsule().strokeBorder(.primary.opacity(0.08), lineWidth: 0.7))
            Menu {
                Picker(privacyText("Show", "표시"), selection: $kindRaw) {
                    ForEach(ClipboardKind.allCases) { value in Label(value.title, systemImage: value.symbol).tag(value.rawValue) }
                }
                Divider()
                Toggle(privacyText("Oldest first", "오래된 순"), isOn: $oldestFirst)
            } label: { Image(systemName: "line.3.horizontal.decrease").frame(width: 26, height: 26) }
                .menuStyle(.borderlessButton).fixedSize()
                .help(privacyText("Filter and sort", "필터 및 정렬"))
                .accessibilityIdentifier("clipboard.filters")
            Button { confirmingClear = true } label: { Image(systemName: "trash").frame(width: 26, height: 26) }
                .buttonStyle(.plain).disabled(removableCount == 0)
                .help(privacyText("Clear unstarred history", "즐겨찾기 제외한 내역 삭제"))
                .accessibilityLabel(privacyText("Clear unstarred history", "즐겨찾기 제외한 내역 삭제"))
        }
    }
    private func capture() {
        message = storage.captureFromPasteboard() ? privacyText("Saved", "저장됨") : (storage.error ?? privacyText("No text to capture", "저장할 텍스트가 없습니다"))
    }
    private func copy(_ item: SavedSnippet) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.text, forType: .string)
        copiedSnippetID = item.id
        message = privacyText("Copied", "복사됨")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if copiedSnippetID == item.id { copiedSnippetID = nil; message = "" }
        }
    }
}

private struct ClipboardHistoryRow: View {
    let snippet: SavedSnippet
    let copied: Bool
    var onCopy: () -> Void
    var onStar: () -> Void
    var onPreview: () -> Void
    var onRemove: () -> Void
    @State private var hovering = false
    private var appLocale: Locale {
        Locale(identifier: privacyText("en", "ko"))
    }
    var body: some View {
        HStack(spacing: 7) {
            Button(action: onStar) {
                Image(systemName: snippet.isFavorite == true ? "star.fill" : "star")
                    .font(.system(size: 10)).foregroundStyle(snippet.isFavorite == true ? Color.yellow : Color.secondary.opacity(hovering ? 0.8 : 0.25))
                    .frame(width: 16, height: 24)
            }.buttonStyle(.plain).accessibilityLabel(privacyText("Toggle favorite", "즐겨찾기 전환"))
            Button(action: onCopy) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(snippet.previewLines.first ?? snippet.text).font(.system(size: 12, weight: .medium)).lineLimit(1)
                        if snippet.previewLines.count > 1 {
                            Text(snippet.previewLines[1]).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(snippet.sourceAppName ?? snippet.clipboardKind.title).lineLimit(1).frame(maxWidth: 92, alignment: .trailing)
                        Text(snippet.date.formatted(.relative(presentation: .numeric, unitsStyle: .abbreviated).locale(appLocale))).lineLimit(1)
                    }.font(.system(size: 9)).foregroundStyle(.secondary)
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 10, weight: .medium)).foregroundStyle(copied ? Color.mint : Color.secondary.opacity(hovering ? 0.8 : 0))
                        .frame(width: 12)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain)
            .help(privacyText("Click to copy full text", "클릭하여 전체 텍스트 복사"))
        }
        .padding(.horizontal, 6).padding(.vertical, 9)
        .background(copied ? Color.mint.opacity(0.1) : Color.primary.opacity(hovering ? 0.045 : 0), in: RoundedRectangle(cornerRadius: 7))
        .overlay(alignment: .bottom) { Rectangle().fill(.primary.opacity(0.07)).frame(height: 0.5).padding(.leading, 29) }
        .onHover { hovering = $0 }
        .contextMenu {
            Button(privacyText("Copy", "복사"), action: onCopy)
            Button(privacyText("Preview", "미리보기"), action: onPreview)
            Button(snippet.isFavorite == true ? privacyText("Unstar", "즐겨찾기 해제") : privacyText("Star", "즐겨찾기 추가"), action: onStar)
            Divider()
            Button(privacyText("Remove", "삭제"), role: .destructive, action: onRemove)
        }
    }
}
