import SwiftUI

struct QuickNotesView: View {
    @ObservedObject var store: QuickNotes
    @State private var saved = false
    @State private var confirmDiscard = false
    @State private var pendingNote: QuickNote?
    private func requestEdit(_ note: QuickNote?) {
        if store.hasUnsavedChanges { pendingNote = note; confirmDiscard = true }
        else { store.edit(note); saved = false }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("settings.tools.notes", systemImage: "note.text").font(.headline)
                Spacer()
                Button("settings.tools.notes.new") { requestEdit(nil) }
                Button(LocalizedStringKey(saved ? "settings.tools.notes.saved" : "settings.tools.notes.save")) { saved = store.saveDraft() }
                    .disabled(store.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if let error = store.error {
                Text(error).font(.caption).foregroundStyle(.orange)
                Button("Retry reading") { store.load() }
            }
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    TextField("settings.tools.notes.search", text: $store.query).textFieldStyle(.roundedBorder)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            if store.filtered.isEmpty { Text("settings.tools.notes.empty").font(.caption).foregroundStyle(.secondary) }
                            ForEach(store.filtered) { note in
                                HStack {
                                    Button { requestEdit(note) } label: { Text(note.title).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading) }
                                    Button { store.togglePin(note.id) } label: { Image(systemName: note.pinned ? "pin.fill" : "pin") }
                                        .accessibilityLabel((note.pinned ? "Unpin " : "Pin ") + note.title)
                                }.font(.caption).padding(6).background(.white.opacity(store.editingID == note.id ? 0.12 : 0.04), in: RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }
                }.frame(width: 175)
                TextEditor(text: $store.draft).font(.system(size: 12)).scrollContentBackground(.hidden)
                    .padding(6).background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                    .accessibilityLabel("settings.tools.notes.text")
                    .onChange(of: store.draft) { _, _ in saved = false }
            }.frame(minHeight: 95)
            Text("settings.tools.notes.local").font(.caption).foregroundStyle(.secondary)
        }.confirmationDialog("settings.tools.notes.discardTitle", isPresented: $confirmDiscard) {
            Button("settings.tools.notes.discard", role: .destructive) { store.edit(pendingNote); saved = false }
            Button("common.cancel", role: .cancel) { }
        }
    }
}
