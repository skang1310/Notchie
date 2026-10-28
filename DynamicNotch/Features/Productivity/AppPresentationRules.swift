import Foundation
import SwiftUI
internal import AppKit
import UniformTypeIdentifiers

struct AppPresentationRulesView: View {
    @ObservedObject private var storage = ProductivityStorage.shared
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("productivity.rules.description").font(.caption).foregroundStyle(.secondary)
            Button("productivity.rules.add") {
                let chooser = NSOpenPanel(); chooser.allowedContentTypes = [.application]; chooser.canChooseDirectories = false
                guard chooser.runModal() == .OK, let url = chooser.url, let id = Bundle(url: url)?.bundleIdentifier, id != "com.Jackson.DynamicNotch" else { return }
                storage.update { if !$0.hiddenBundleIDs.contains(id) { $0.hiddenBundleIDs.append(id) } }
            }
            ScrollView {
                ForEach(storage.document.hiddenBundleIDs, id: \.self) { id in
                    HStack {
                        Text(id).font(.caption).lineLimit(2)
                        Spacer()
                        Button("productivity.remove") { storage.update { $0.hiddenBundleIDs.removeAll { $0 == id } } }
                    }.padding(.vertical, 6)
                }
            }
            if let error = storage.error { Text(error).font(.caption).foregroundStyle(.red) }
        }.padding()
    }
}
