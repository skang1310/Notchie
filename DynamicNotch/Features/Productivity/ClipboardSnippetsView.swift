import SwiftUI
internal import AppKit

struct ClipboardSnippetsView: View {
    @ObservedObject private var storage = ProductivityStorage.shared
    @State private var searchQuery = ""
    @State private var copiedSnippetID: UUID?
    @State private var message = ""

    private func text(_ en: String, _ ko: String) -> String {
        privacyText(en, ko)
    }

    private var filteredItems: [SavedSnippet] {
        storage.filteredSnippets(query: searchQuery)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    TextField(
                        text("Search clipboard history…", "클립보드 내역 검색…"),
                        text: $searchQuery
                    )
                    .textFieldStyle(.plain)
                    .font(.callout)
                    .accessibilityIdentifier("clipboard.searchField")

                    if !searchQuery.isEmpty {
                        Button {
                            searchQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                Button("productivity.snippets.capture") {
                    if storage.captureFromPasteboard() {
                        message = L10n.app("settings.tools.notes.saved")
                    } else {
                        message = storage.error ?? L10n.app("productivity.snippets.empty")
                    }
                }
                .controlSize(.small)
            }

            HStack(spacing: 10) {
                Toggle(
                    text("Auto-save copied items while running", "실행 중 복사한 텍스트 자동 기록"),
                    isOn: $storage.isAutoCaptureClipboardEnabled
                )
                .toggleStyle(.switch)
                .controlSize(.mini)
                .font(.caption)
                .foregroundStyle(.secondary)

                Spacer()

                Text("\(filteredItems.count) / \(storage.document.snippets.count)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)

                if !storage.document.snippets.isEmpty {
                    Button(text("Clear All", "전체 삭제"), role: .destructive) {
                        storage.update { $0.snippets.removeAll() }
                    }
                    .font(.caption2)
                    .buttonStyle(.plain)
                    .foregroundStyle(.red.opacity(0.85))
                }
            }

            if filteredItems.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: searchQuery.isEmpty ? "doc.on.clipboard" : "magnifyingglass")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text(
                        searchQuery.isEmpty
                            ? text("No saved clipboard items yet. Copy text or click Capture.", "저장된 클립보드 항목이 없습니다. 캡처 버튼을 누르거나 자동 기록을 켜세요.")
                            : text("No clipboard items match your search.", "검색어와 일치하는 클립보드 내역이 없습니다.")
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 90)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(filteredItems) { snippet in
                            let isCopied = copiedSnippetID == snippet.id
                            HStack(spacing: 8) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(snippet.text)
                                        .font(.system(size: 12.5))
                                        .lineLimit(2)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text(snippet.date, style: .relative)
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    copySnippet(snippet)
                                }

                                Button {
                                    copySnippet(snippet)
                                } label: {
                                    Label(
                                        isCopied ? text("Copied!", "복사됨!") : L10n.app("productivity.copy"),
                                        systemImage: isCopied ? "checkmark.circle.fill" : "doc.on.doc"
                                    )
                                    .font(.caption)
                                    .foregroundStyle(isCopied ? Color.green : Color.primary)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)

                                Button {
                                    storage.update { $0.snippets.removeAll { $0.id == snippet.id } }
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(isCopied ? Color.green.opacity(0.12) : Color.primary.opacity(0.05))
                            )
                        }
                    }
                }
            }

            if !message.isEmpty {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(8)
    }

    private func copySnippet(_ snippet: SavedSnippet) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(snippet.text, forType: .string)
        withAnimation(.easeInOut(duration: 0.15)) {
            copiedSnippetID = snippet.id
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            if copiedSnippetID == snippet.id {
                withAnimation(.easeInOut(duration: 0.2)) {
                    copiedSnippetID = nil
                }
            }
        }
    }
}
