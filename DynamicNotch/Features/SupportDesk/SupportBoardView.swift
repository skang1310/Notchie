import SwiftUI
internal import AppKit
import UniformTypeIdentifiers

struct SupportBoardView: View {
    @ObservedObject var store: SupportCaseStore
    @ObservedObject var watcher: SupportFolderWatcher
    @State private var tab = "evidence"
    @State private var active: UUID?
    @State private var comparison: [UUID] = []
    @State private var mask = false
    @State private var status = ""
    @State private var exporting = false
    var body: some View {
        HSplitView {
            VStack(alignment:.leading,spacing:10) {
                Button("support.case.new") { _ = store.newCase(title:L10n.app("support.case.untitled")); active = nil; comparison = [] }
                List(selection:$store.selected) {
                    ForEach(store.document.cases.reversed()) { item in
                        VStack(alignment:.leading) { Text(item.title).lineLimit(1); Text("\(item.screenshots.count) · \(item.createdAt.formatted(date:.abbreviated,time:.omitted))").font(.caption).foregroundStyle(.secondary) }.tag(item.id)
                    }
                }
                Text("support.case.local").font(.caption2).foregroundStyle(.secondary)
            }.padding(12).frame(minWidth:170,idealWidth:210,maxWidth:240)
            VStack(alignment:.leading,spacing:10) {
                HStack {
                    Picker("support.board.mode",selection:$tab) { Text("support.board.evidence").tag("evidence"); Text("support.board.report").tag("report"); Text("support.board.text").tag("text") }.pickerStyle(.segmented)
                    if store.busy || exporting { ProgressView().controlSize(.small) }
                }
                if tab == "report" { ReportCompareToolView() }
                else if tab == "text" { DeveloperTextToolsView() }
                else if let item = store.current {
                    toolbar
                    HSplitView {
                        VStack(spacing:8) {
                            if comparison.count == 2 {
                                HStack {
                                    ForEach(comparison,id:\.self) { id in
                                        if let shot = item.screenshots.first(where:{$0.id==id}) {
                                            VStack { SupportThumbnailView(shot:shot,url:store.file(shot),size:1400); Text(shot.caption).font(.caption).lineLimit(2) }
                                        }
                                    }
                                }.frame(maxHeight:290)
                            }
                            ScrollView {
                                LazyVGrid(columns:[GridItem(.adaptive(minimum:135,maximum:210))],spacing:12) {
                                    ForEach(item.screenshots) { shot in
                                        VStack(alignment:.leading,spacing:4) {
                                            SupportThumbnailView(shot:shot,url:store.file(shot)).frame(height:110).frame(maxWidth:.infinity)
                                                .background(.secondary.opacity(0.08)).onTapGesture { active = shot.id }
                                            HStack {
                                                Button { toggleCompare(shot.id) } label: { Image(systemName:comparison.contains(shot.id) ? "checkmark.square.fill":"square") }
                                                Text(shot.capturedAt.formatted(date:.omitted,time:.shortened)).font(.caption)
                                                Spacer()
                                            }
                                            Text(shot.caption.isEmpty ? "\(shot.width)×\(shot.height)" : shot.caption).font(.caption).lineLimit(2)
                                        }.padding(7).background(active == shot.id ? Color.accentColor.opacity(0.15):Color.clear).clipShape(RoundedRectangle(cornerRadius:8))
                                    }
                                }.padding(4)
                            }
                        }.frame(minWidth:320)
                        ScrollView { inspector(item) }.frame(minWidth:280,idealWidth:315,maxWidth:380)
                    }
                } else {
                    VStack(spacing:16) { Image(systemName:"rectangle.stack.badge.plus").font(.largeTitle); Text("support.case.start"); Button("support.case.new") { _ = store.newCase(title:L10n.app("support.case.untitled")) } }.frame(maxWidth:.infinity,maxHeight:.infinity)
                }
                Text(status.isEmpty ? store.message:status).font(.caption).foregroundStyle(.secondary).lineLimit(2).textSelection(.enabled)
            }.padding(14).frame(minWidth:700)
        }
        .onChange(of:store.selected) { active=nil; comparison=[] }
        .onDrop(of:[UTType.fileURL.identifier],isTargeted:nil) { providers in
            let group = DispatchGroup(), collected = SupportDropURLs()
            for provider in providers {
                group.enter()
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url { collected.append(url) }; group.leave()
                }
            }
            group.notify(queue: .main) { store.importFiles(collected.values) }
            return true
        }
    }
    private var toolbar: some View {
        HStack {
            Button("support.case.import") { let p=NSOpenPanel(); p.allowedContentTypes=[.image]; p.allowsMultipleSelection=true; p.canChooseDirectories=false; if p.runModal() == .OK { store.importFiles(p.urls) } }.disabled(store.busy)
            Button("support.case.paste") { pasteImage() }.disabled(store.busy)
            Button("support.case.watch") { chooseWatch() }.disabled(store.busy)
            if watcher.running { Button("support.case.stopWatch") { watcher.stop() } }
            Spacer()
            Button("support.case.export") { export() }.disabled(exporting || store.current?.screenshots.isEmpty != false)
        }.font(.caption)
    }
    @ViewBuilder private func inspector(_ item:SupportCase) -> some View {
        VStack(alignment:.leading,spacing:10) {
            field("support.case.title",value:item.title) { $0.title=$1 }
            field("support.case.ticket",value:item.ticket) { $0.ticket=$1 }
            field("support.case.app",value:item.app) { $0.app=$1 }
            field("support.case.timezone",value:item.timeZone) { $0.timeZone=$1 }
            field("support.case.reportA",value:item.reportAContext) { $0.reportAContext=$1 }
            field("support.case.reportB",value:item.reportBContext) { $0.reportBContext=$1 }
            field("support.case.expected",value:item.expected) { $0.expected=$1 }
            field("support.case.actual",value:item.actual) { $0.actual=$1 }
            Text("support.case.notes").font(.caption)
            TextEditor(text:Binding(get:{store.current?.notes ?? ""},set:{ value in store.update(item.id){$0.notes=value} })).frame(height:90).border(.secondary.opacity(0.2))
            if let shot = item.screenshots.first(where:{$0.id==active}) {
                Divider()
                RedactionEditor(shot:shot,url:store.file(shot),enabled:mask) { r in store.update(item.id) { c in if let i=c.screenshots.firstIndex(where:{$0.id==shot.id}){c.screenshots[i].redactions.append(r)} } }
                    .frame(height:220)
                Toggle("support.case.mask",isOn:$mask)
                Button("support.case.undoMask") { store.update(item.id) { c in if let i=c.screenshots.firstIndex(where:{$0.id==shot.id}),!c.screenshots[i].redactions.isEmpty{c.screenshots[i].redactions.removeLast()} } }.disabled(shot.redactions.isEmpty)
                TextField("support.case.caption",text:Binding(get:{store.current?.screenshots.first{$0.id==shot.id}?.caption ?? ""},set:{ value in store.update(item.id){ c in if let i=c.screenshots.firstIndex(where:{$0.id==shot.id}){c.screenshots[i].caption=value} } })).textFieldStyle(.roundedBorder)
                Button("support.case.ocr") { ocr(shot,caseID:item.id) }
                Text(shot.ocr).font(.system(size:11,design:.monospaced)).textSelection(.enabled)
            }
            Text("support.case.contextHelp").font(.caption2).foregroundStyle(.secondary)
            Link("support.report.reference",destination:URL(string:"https://support.singular.net/hc/en-us/articles/360031109752-Troubleshooting-Discrepancies-between-Singular-Reports-and-Ad-Network-Dashboard")!)
        }.padding(.leading,12)
    }
    private func field(_ key:LocalizedStringKey,value:String,update:@escaping(inout SupportCase,String)->Void) -> some View {
        TextField(key,text:Binding(get:{value},set:{ value in if let id=store.selected{store.update(id){update(&$0,value)}} })).textFieldStyle(.roundedBorder)
    }
    private func toggleCompare(_ id:UUID) { if comparison.contains(id){comparison.removeAll{$0==id}} else { if comparison.count==2 {comparison.removeFirst()};comparison.append(id) } }
    private func pasteImage() {
        guard let image=NSImage(pasteboard:NSPasteboard.general),let data=image.tiffRepresentation else {status=L10n.app("support.case.noImage");return}
        let folder=store.root.appendingPathComponent("staging")
        let url=folder.appendingPathComponent(UUID().uuidString+".tiff")
        do {
            try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
            try data.write(to:url,options:.atomic)
            try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:url.path)
            store.importFiles([url],ownedStaging:[url])
        }
        catch {status=error.localizedDescription}
    }
    private func chooseWatch() {
        let p=NSOpenPanel();p.canChooseDirectories=true;p.canChooseFiles=false
        if p.runModal() == .OK,let url=p.url { do{try watcher.start(url)}catch{status=error.localizedDescription} }
    }
    private func export() {
        guard let id=store.selected else{return};let p=NSOpenPanel();p.canChooseDirectories=true;p.canChooseFiles=false
        guard p.runModal() == .OK,let folder=p.url else{return};exporting=true
        Task { do{let url=try await store.export(id,to:folder);status=url.path;NSWorkspace.shared.activateFileViewerSelecting([url])}catch{status=error.localizedDescription};exporting=false }
    }
    private func ocr(_ shot:SupportScreenshot,caseID:UUID) {
        let url=store.file(shot)
        Task {
            guard let data=try? await Task.detached(operation:{try SupportImages.png(url:url,maxPixel:3000,redactions:shot.redactions)}).value,let image=NSImage(data:data) else{return}
            let text=await OCRService.shared.recognizeText(in:image,languages:["en-US","ko-KR"])
            store.update(caseID){c in if let i=c.screenshots.firstIndex(where:{$0.id==shot.id}){c.screenshots[i].ocr=text}}
        }
    }
}
struct RedactionEditor:View {
    let shot:SupportScreenshot;let url:URL;let enabled:Bool;let add:(SupportRedaction)->Void
    @State private var drag:SupportRedaction?
    var body:some View {
        GeometryReader { geo in
            let ratio=CGFloat(shot.width)/CGFloat(max(1,shot.height))
            let w=min(geo.size.width,geo.size.height*ratio),h=w/ratio
            let x=(geo.size.width-w)/2,y=(geo.size.height-h)/2
            ZStack {
                SupportThumbnailView(shot:shot,url:url,size:1400).frame(width:w,height:h).position(x:geo.size.width/2,y:geo.size.height/2)
                if let drag { Rectangle().fill(.black.opacity(0.8)).frame(width:w*drag.width,height:h*drag.height).position(x:x+w*(drag.x+drag.width/2),y:y+h*(drag.y+drag.height/2)) }
                if enabled {
                    Color.clear.contentShape(Rectangle()).gesture(DragGesture(minimumDistance:2).onChanged { value in
                        func clamp(_ n:CGFloat)->Double{Double(min(1,max(0,n)))}
                        let a=clamp((value.startLocation.x-x)/w),b=clamp((value.startLocation.y-y)/h),c=clamp((value.location.x-x)/w),d=clamp((value.location.y-y)/h)
                        drag=SupportRedaction(x:min(a,c),y:min(b,d),width:abs(c-a),height:abs(d-b))
                    }.onEnded { _ in if let drag,drag.valid {add(drag)};drag=nil })
                }
            }
        }
    }
}

private final class SupportDropURLs: @unchecked Sendable {
    private let lock = NSLock(); private var urls: [URL] = []
    func append(_ url: URL) { lock.lock(); defer { lock.unlock() }; urls.append(url) }
    var values: [URL] { lock.lock(); defer { lock.unlock() }; return urls }
}
