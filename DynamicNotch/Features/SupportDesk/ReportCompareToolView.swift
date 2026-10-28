import SwiftUI
internal import AppKit

struct ReportCompareToolView: View {
    @ObservedObject private var cases = SupportCaseStore.shared
    @State private var a = ""
    @State private var b = ""
    @State private var keys = ""
    @State private var metric = ""
    @State private var output = ""
    @State private var busy = false
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("support.report.description").font(.caption).foregroundStyle(.secondary)
            HStack {
                VStack { Text("Report A · CSV"); TextEditor(text:$a).font(.system(size:11,design:.monospaced)).border(.secondary.opacity(0.3)) }
                VStack { Text("Report B · CSV"); TextEditor(text:$b).font(.system(size:11,design:.monospaced)).border(.secondary.opacity(0.3)) }
            }.frame(minHeight:90,maxHeight:180)
            HStack {
                TextField("support.report.keys",text:$keys).textFieldStyle(.roundedBorder)
                TextField("support.report.metric",text:$metric).textFieldStyle(.roundedBorder)
                Button("support.report.compare") { compare() }.disabled(busy)
            }
            HStack {
                Button("productivity.copy") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(output,forType:.string) }.disabled(output.isEmpty)
                Button("support.report.attach") { if let id = cases.selected { cases.update(id) { $0.notes += "\n\n" + output } } }.disabled(output.isEmpty || cases.selected == nil)
                if busy { ProgressView().controlSize(.small) }
            }
            ScrollView { Text(output).font(.system(size:11,design:.monospaced)).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading) }.frame(minHeight:80,maxHeight:230)
            Link("support.report.reference",destination:URL(string:"https://support.singular.net/hc/en-us/articles/360031109752-Troubleshooting-Discrepancies-between-Singular-Reports-and-Ad-Network-Dashboard")!)
        }.padding()
    }
    private func compare() {
        let left = a, right = b, groupKeys = keys.split(separator:",").map { $0.trimmingCharacters(in:.whitespaces) }, column = metric
        busy = true
        Task {
            output = await Task.detached { () -> String in
                do { return ReportReconciler.summary(try ReportReconciler.compare(ReportCSV(left),ReportCSV(right),keys:groupKeys,metric:column)) }
                catch { return error.localizedDescription }
            }.value
            busy = false
        }
    }
}
