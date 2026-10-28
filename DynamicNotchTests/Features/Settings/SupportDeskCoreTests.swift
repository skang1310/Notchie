import XCTest
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import DynamicNotch

final class SupportDeskCoreTests: XCTestCase {
    func testCalculatorPrecedenceUnaryScientificAndPercent() throws {
        XCTAssertEqual(try LocalCalculator.evaluate("-(2+3)*4 + 1e2 / 2"),30)
        XCTAssertEqual(try LocalCalculator.evaluate("50% * 80"),40)
        XCTAssertThrowsError(try LocalCalculator.evaluate("1/0"))
        XCTAssertThrowsError(try LocalCalculator.evaluate("system('id')"))
        XCTAssertThrowsError(try LocalCalculator.evaluate("2+"))
        XCTAssertThrowsError(try LocalCalculator.evaluate("1e9999"))
    }
    func testUnitConversionUsesExplicitCompatibleDimensions() throws {
        XCTAssertEqual(try LocalCalculator.convert(1024,from:"KiB",to:"MiB"),1)
        XCTAssertEqual(try LocalCalculator.convert(1000,from:"ms",to:"s"),1)
        XCTAssertEqual(try LocalCalculator.convert(32,from:"°F",to:"°C"),0)
        XCTAssertThrowsError(try LocalCalculator.convert(-1,from:"K",to:"°C"))
        XCTAssertThrowsError(try LocalCalculator.convert(10,from:"MB",to:"m"))
    }
    func testCSVQuotedCommaNewlineEscapedQuotesAndCRLF() throws {
        let csv=try ReportCSV("\u{feff}campaign,value\r\n\"Hello, \"\"world\"\"\",1\r\n\"two\nlines\",2\r\n")
        XCTAssertEqual(csv.rows.count,2)
        XCTAssertEqual(csv.rows[0][0],"Hello, \"world\"")
        XCTAssertEqual(csv.rows[1][0],"two\nlines")
        XCTAssertThrowsError(try ReportCSV("a,a\n1,2"))
        XCTAssertThrowsError(try ReportCSV("a,b\n1"))
        XCTAssertThrowsError(try ReportCSV("a,b\n\"unfinished,1"))
    }
    func testReportAggregationExactDecimalsMissingRowsAndZeroBaseline() throws {
        let a=try ReportCSV("campaign,revenue\nx,0.1\nx,0.2\ny,0\nonlyA,4")
        let b=try ReportCSV("campaign,revenue\nx,0.4\ny,2\nonlyB,5")
        let result=try ReportReconciler.compare(a,b,keys:["campaign"],metric:"revenue")
        XCTAssertEqual(result.totalA,Decimal(string:"4.3"))
        XCTAssertEqual(result.totalB,Decimal(string:"7.4"))
        XCTAssertEqual(result.duplicateRowsA,1)
        let x=try XCTUnwrap(result.deltas.first{$0.key==["x"]})
        XCTAssertEqual(x.change,Decimal(string:"0.1"))
        XCTAssertNil(try XCTUnwrap(result.deltas.first{$0.key==["y"]}).percent)
        XCTAssertNil(try XCTUnwrap(result.deltas.first{$0.key==["onlyB"]}).a)
        XCTAssertThrowsError(try ReportReconciler.compare(ReportCSV("c,v\nx,N/A"),ReportCSV("c,v\nx,1"),keys:["c"],metric:"v"))
    }
    func testJSONDiffURLDuplicatesAndSecretMasking() throws {
        XCTAssertEqual(try SupportTextTools.json("{\"b\":2,\"a\":1}",compact:true),"{\"a\":1,\"b\":2}")
        XCTAssertTrue(try SupportTextTools.diff("{\"v\":1}","{\"v\":2}").contains("/v"))
        let query=try SupportTextTools.query("https://s2s.singular.net/api/v2/evt?n=install&n=other&sdid=test%20id")
        XCTAssertEqual(query.count,3);XCTAssertEqual(query[2].1,"test id")
        let masked=try SupportTextTools.redacted("a=secret&sdid=40009df0-d618-4d81-9da1-cbb3337b8dec&email=person@example.com Authorization: Bearer abc123")
        XCTAssertFalse(masked.contains("secret"));XCTAssertFalse(masked.contains("person@example.com"));XCTAssertFalse(masked.contains("abc123"))
        XCTAssertThrowsError(try SupportTextTools.json(String(repeating:"x",count:1_000_001)))
    }
    func testActualDeflateArchiveAndForgedExpandedSize() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let source = folder.appendingPathComponent("fixture.txt"), archive = folder.appendingPathComponent("fixture.zip")
        try String(repeating: "report-row,123\n", count: 1000).write(to: source, atomically: true, encoding: .utf8)
        let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-q", "-j", "-X", archive.path, source.path]
        try process.run(); process.waitUntilExit(); XCTAssertEqual(process.terminationStatus, 0)
        let bytes = try Data(contentsOf: archive)
        XCTAssertEqual(try ZipInspection(data: bytes).names, ["fixture.txt"])
        var forged = bytes
        let signature = Data([0x50,0x4b,0x01,0x02])
        let central = try XCTUnwrap(bytes.range(of: signature)).lowerBound
        for i in 0..<4 { forged[central+24+i] = 0 }
        XCTAssertThrowsError(try ZipInspection(data: forged))
    }
    func testZipValidFixtureAndTraversalLinksLocalNameMismatchRejected() throws {
        func archive(name:String,localName:String?=nil,mode:UInt32=0x81a40000)->Data {
            var d=Data()
            func u16(_ n:UInt16){d.append(UInt8(n&255));d.append(UInt8(n>>8))}
            func u32(_ n:UInt32){for i in 0..<4{d.append(UInt8((n>>UInt32(i*8))&255))}}
            let local=Data((localName ?? name).utf8),central=Data(name.utf8)
            u32(0x04034b50);u16(20);u16(0);u16(0);u16(0);u16(0);u32(0);u32(0);u32(0);u16(UInt16(local.count));u16(0);d.append(local)
            let start=UInt32(d.count)
            u32(0x02014b50);u16(0x0314);u16(20);u16(0);u16(0);u16(0);u16(0);u32(0);u32(0);u32(0);u16(UInt16(central.count));u16(0);u16(0);u16(0);u16(0);u32(mode);u32(0);d.append(central)
            let size=UInt32(d.count)-start
            u32(0x06054b50);u16(0);u16(0);u16(1);u16(1);u32(size);u32(start);u16(0)
            return d
        }
        XCTAssertEqual(try ZipInspection(data:archive(name:"safe.txt")).names,["safe.txt"])
        for name in ["../evil","/absolute","a/../../evil","C:/evil","a\\evil"] {XCTAssertThrowsError(try ZipInspection(data:archive(name:name)))}
        XCTAssertThrowsError(try ZipInspection(data:archive(name:"safe",localName:"../bad")))
        XCTAssertThrowsError(try ZipInspection(data:archive(name:"link",mode:0xa1ff0000)))
        XCTAssertThrowsError(try ZipInspection(data:Data("not zip".utf8)))
    }
}

@MainActor
final class SupportCasePersistenceTests:XCTestCase {
    private func image()->Data {
        let ctx=CGContext(data:nil,width:40,height:20,bitsPerComponent:8,bytesPerRow:0,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(CGColor(red:1,green:0,blue:0,alpha:1));ctx.fill(CGRect(x:0,y:0,width:40,height:20))
        let data=NSMutableData();let dest=CGImageDestinationCreateWithData(data,UTType.png.identifier as CFString,1,nil)!
        CGImageDestinationAddImage(dest,ctx.makeImage()!,nil);CGImageDestinationFinalize(dest);return data as Data
    }
    func testDedupPersistenceFlattenedMaskAndExportExcludeOCRAndOriginalMetadata() async throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer{try? FileManager.default.removeItem(at:root)}
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        let source=root.appendingPathComponent("source.png"),original=image();try original.write(to:source)
        let store=SupportCaseStore(root:root.appendingPathComponent("cases")),id=try XCTUnwrap(store.newCase(title:"QA report comparison"))
        let loaded=try SupportImages.load(source)
        try store.accept(loaded,caseID:id);try store.accept(loaded,caseID:id)
        XCTAssertEqual(store.current?.screenshots.count,1)
        XCTAssertTrue(store.update(id){c in c.notes="token=confidential";c.screenshots[0].ocr="NEVER_EXPORT_RAW_OCR";c.screenshots[0].redactions=[SupportRedaction(x:0.25,y:0.25,width:0.5,height:0.5)]})
        let reload=SupportCaseStore(root:root.appendingPathComponent("cases"));XCTAssertEqual(reload.current?.screenshots.count,1)
        let exported=try await reload.export(id,to:root)
        let md=try String(contentsOf:exported.appendingPathComponent("README.md"),encoding:.utf8)
        XCTAssertFalse(md.contains("NEVER_EXPORT_RAW_OCR"));XCTAssertFalse(md.contains("confidential"))
        XCTAssertEqual(try Data(contentsOf:source),original)
        let png=try Data(contentsOf:exported.appendingPathComponent("images/1.png"))
        let cgSource=CGImageSourceCreateWithData(png as CFData,nil)!,cg=CGImageSourceCreateImageAtIndex(cgSource,0,nil)!
        let ctx=CGContext(data:nil,width:40,height:20,bitsPerComponent:8,bytesPerRow:160,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(cg,in:CGRect(x:0,y:0,width:40,height:20));let pixels=ctx.data!.assumingMemoryBound(to:UInt8.self)
        XCTAssertEqual(pixels[10*160+20*4],0);XCTAssertEqual(pixels[0],255)
    }
    func testCorruptCaseDocumentDoesNotGetOverwritten() throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer{try? FileManager.default.removeItem(at:root)}
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        let file=root.appendingPathComponent("cases.json"),data=Data("bad".utf8);try data.write(to:file)
        let store=SupportCaseStore(root:root)
        XCTAssertNil(store.newCase(title:"No overwrite"));XCTAssertEqual(try Data(contentsOf:file),data)
    }
    func testExplicitFolderWatchImportsNewImagesAndStops() async throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString),source=root.appendingPathComponent("selected")
        defer{try? FileManager.default.removeItem(at:root)}
        try FileManager.default.createDirectory(at:source,withIntermediateDirectories:true)
        let store=SupportCaseStore(root:root.appendingPathComponent("cases"));_ = store.newCase(title:"QA folder watch")
        let watcher=SupportFolderWatcher(store:store)
        try watcher.start(source);XCTAssertTrue(watcher.running)
        try image().write(to:source.appendingPathComponent("new.png"))
        for _ in 0..<60 {if store.current?.screenshots.count==1{break};try await Task.sleep(for:.milliseconds(50))}
        XCTAssertEqual(store.current?.screenshots.count,1)
        watcher.stop();XCTAssertFalse(watcher.running)
        try Data("not an image".utf8).write(to:source.appendingPathComponent("after.png"))
        try await Task.sleep(for:.milliseconds(850))
        XCTAssertEqual(store.current?.screenshots.count,1)
    }
}
