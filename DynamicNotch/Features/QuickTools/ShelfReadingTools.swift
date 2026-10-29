import SwiftUI
internal import AppKit

struct TeleprompterView: View {
    @ObservedObject var controller: TeleprompterController
    @State private var reading = false
    @State private var fontSize = 23.0
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Label(privacyText("Teleprompter", "텔레프롬프터"), systemImage: "text.alignleft").font(.caption.weight(.semibold))
                Spacer()
                Toggle(privacyText("Read", "읽기"), isOn: $reading).toggleStyle(.switch).controlSize(.mini)
                if reading {
                    Button {
                        if controller.isRunning { controller.pause() } else { controller.start() }
                    } label: { Image(systemName: controller.isRunning ? "pause.fill" : "play.fill") }
                    .disabled(controller.words.isEmpty)
                    .accessibilityLabel(controller.isRunning ? privacyText("Pause", "일시 정지") : privacyText("Start reading", "읽기 시작"))
                    Button { controller.reset() } label: { Image(systemName: "arrow.counterclockwise") }
                        .help(privacyText("Start over", "처음으로"))
                }
            }
            if reading {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 9) {
                            ForEach(Array(chunks.enumerated()), id: \.offset) { index, line in
                                Text(line).font(.system(size: fontSize, weight: currentLine == index ? .semibold : .regular))
                                    .foregroundStyle(currentLine == index ? Color.primary : Color.secondary.opacity(0.55))
                                    .frame(maxWidth: .infinity, alignment: .leading).id(index)
                            }
                        }.padding(.vertical, 10)
                    }
                    .onChange(of: currentLine) { _, value in
                        withAnimation(.easeInOut(duration: 0.2)) { proxy.scrollTo(value, anchor: .center) }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 10))
            } else {
                TextEditor(text: $controller.script)
                    .font(.system(size: 13)).scrollContentBackground(.hidden)
                    .padding(6).background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityIdentifier("shelf.teleprompter.script")
                    .overlay(alignment: .topLeading) {
                        if controller.script.isEmpty {
                            Text(privacyText("Write or paste your script here…", "발표할 대본을 입력하거나 붙여넣으세요…"))
                                .font(.caption).foregroundStyle(.secondary).padding(12).allowsHitTesting(false)
                        }
                    }
            }
            HStack {
                Text("\(Int(controller.wordsPerMinute)) " + privacyText("words/min", "단어/분")).font(.caption).monospacedDigit().frame(width: 95)
                Slider(value: $controller.wordsPerMinute, in: 30...300, step: 10)
                    .accessibilityLabel(privacyText("Reading speed", "읽기 속도"))
                Slider(value: $fontSize, in: 16...36, step: 1).frame(width: 70)
                    .accessibilityLabel(privacyText("Text size", "글자 크기"))
            }
        }
        .padding(8)
        .task(id: controller.isRunning) {
            guard controller.isRunning else { return }
            while !Task.isCancelled {
                controller.advance()
                do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
            }
        }
        .onChange(of: reading) { _, _ in controller.pause() }
        .onChange(of: controller.script) { _, _ in controller.reset() }
        .onDisappear { controller.pause() }
    }
    private var currentLine: Int { controller.currentIndex / 7 }
    private var chunks: [String] {
        let words = controller.words
        return stride(from: 0, to: words.count, by: 7).map { words[$0..<min($0 + 7, words.count)].joined(separator: " ") }
    }
}

struct ShelfEmoji: Identifiable {
    let symbol: String
    let terms: String
    var id: String { symbol }
    static let all: [ShelfEmoji] = [
        .init(symbol: "😀", terms: "smile happy 웃음 행복"), .init(symbol: "😂", terms: "laugh joy 웃음 눈물"),
        .init(symbol: "🥹", terms: "touched 감동 눈물"), .init(symbol: "😍", terms: "love heart 사랑"),
        .init(symbol: "😎", terms: "cool sunglasses 멋짐 선글라스"), .init(symbol: "🤔", terms: "think question 생각 질문"),
        .init(symbol: "😭", terms: "cry sad 슬픔 눈물"), .init(symbol: "🥳", terms: "party celebrate 축하 파티"),
        .init(symbol: "👍", terms: "yes good thumb 좋아 찬성"), .init(symbol: "👎", terms: "no bad 싫어 반대"),
        .init(symbol: "👏", terms: "clap 박수"), .init(symbol: "🙌", terms: "hooray 만세"),
        .init(symbol: "🙏", terms: "please thanks pray 감사 기도 부탁"), .init(symbol: "👀", terms: "look eyes 눈 확인"),
        .init(symbol: "❤️", terms: "heart love 사랑 하트"), .init(symbol: "💜", terms: "purple heart 보라 하트"),
        .init(symbol: "🔥", terms: "fire hot 불 열정"), .init(symbol: "✨", terms: "sparkles star 반짝 별"),
        .init(symbol: "✅", terms: "check done 완료 확인"), .init(symbol: "❌", terms: "cancel no 취소 오류"),
        .init(symbol: "⚠️", terms: "warning 주의 경고"), .init(symbol: "💡", terms: "idea bulb 생각 아이디어"),
        .init(symbol: "🚀", terms: "rocket launch 로켓 출시"), .init(symbol: "🎉", terms: "celebrate 축하"),
        .init(symbol: "💻", terms: "computer mac 개발 컴퓨터"), .init(symbol: "🍎", terms: "apple 사과 애플"),
        .init(symbol: "☕️", terms: "coffee break 커피 휴식"), .init(symbol: "📌", terms: "pin 고정 핀"),
        .init(symbol: "📝", terms: "note memo 메모 기록"), .init(symbol: "📅", terms: "calendar date 일정 날짜"),
        .init(symbol: "⏰", terms: "alarm time 알람 시간"), .init(symbol: "🎵", terms: "music 음악"),
        .init(symbol: "🌈", terms: "rainbow 무지개"), .init(symbol: "🌙", terms: "moon night 달 밤"),
        .init(symbol: "🐱", terms: "cat 고양이"), .init(symbol: "🐶", terms: "dog 강아지 개")
    ]
    static func matching(_ query: String) -> [ShelfEmoji] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty ? all : all.filter { $0.terms.localizedCaseInsensitiveContains(query) || $0.symbol == query }
    }
}

struct ShelfEmojiView: View {
    @State private var query = ""
    @State private var copied: String?
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField(privacyText("Search emoji in English or Korean", "영어·한국어로 이모지 검색"), text: $query).textFieldStyle(.plain)
                Text(copied.map { $0 + " " + privacyText("Copied", "복사됨") } ?? "").font(.caption).foregroundStyle(.secondary)
            }.padding(8).background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 36))], spacing: 5) {
                    ForEach(ShelfEmoji.matching(query)) { emoji in
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(emoji.symbol, forType: .string)
                            copied = emoji.symbol
                        } label: { Text(emoji.symbol).font(.system(size: 24)).frame(width: 36, height: 36).contentShape(Rectangle()) }
                        .buttonStyle(.plain).help(emoji.terms)
                        .accessibilityLabel(emoji.terms)
                    }
                }
            }
            if ShelfEmoji.matching(query).isEmpty { Text(privacyText("No matches", "검색 결과 없음")).foregroundStyle(.secondary) }
            Text(privacyText("Click to copy · Paste wherever you need it", "클릭하여 복사 · 필요한 곳에 붙여넣으세요")).font(.caption2).foregroundStyle(.secondary)
        }.padding(8)
    }
}
