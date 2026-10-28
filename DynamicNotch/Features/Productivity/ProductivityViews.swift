import SwiftUI

struct FocusSessionView: View {
    @ObservedObject var controller: FocusSessionController
    @ObservedObject private var storage = ProductivityStorage.shared
    @State private var minutes = 25
    var body: some View {
        VStack(spacing: 14) {
            if controller.phase == .idle || controller.phase == .complete {
                Stepper(value: $minutes, in: 1...180) { Text("\(minutes) min") }
                Toggle("productivity.focus.awake", isOn: $controller.preventSleep)
                Button("productivity.focus.start") { controller.startFocus(minutes: minutes) }
            } else if controller.phase == .readyForBreak {
                Text("productivity.focus.finished")
                Button("productivity.focus.break") { controller.startBreak() }
                Button("productivity.focus.stop") { controller.stop() }
            } else {
                Text(LocalizedStringKey(controller.phase == .focus ? "productivity.focus.working" : "productivity.focus.resting"))
                Text(controller.timer.formattedRemainingTime).font(.system(size: 34, design: .monospaced))
                HStack {
                    Button(LocalizedStringKey(controller.timer.state == .paused ? "productivity.resume" : "settings.tools.pause")) { controller.pauseOrResume() }
                    Button("productivity.focus.stop") { controller.stop() }
                }
            }
            Text("\(storage.document.focusHistory.filter { Calendar.current.isDateInToday($0.date) }.count)").font(.title2)
            Text("productivity.focus.completedToday").font(.caption).foregroundStyle(.secondary)
            if let error = controller.persistenceError { Text(error).font(.caption).foregroundStyle(.red) }
        }.padding().frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct TodayTasksView: View {
    @ObservedObject private var storage = ProductivityStorage.shared
    @State private var draft = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("productivity.tasks.description").font(.caption).foregroundStyle(.secondary)
            ForEach(storage.todayTasks) { task in
                HStack {
                    Button { storage.toggleTask(task.id) } label: { Image(systemName: task.done ? "checkmark.circle.fill" : "circle") }
                    Text(task.text).strikethrough(task.done).lineLimit(2)
                    Spacer()
                    Button { storage.removeTask(task.id) } label: { Image(systemName: "trash") }.help(L10n.app("productivity.remove"))
                }
            }
            HStack {
                TextField("productivity.tasks.new", text: $draft).textFieldStyle(.roundedBorder)
                    .onSubmit { add() }
                Button("productivity.add") { add() }.disabled(storage.todayTasks.count >= 3 || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if let error = storage.error { Text(error).font(.caption).foregroundStyle(.red) }
        }.padding().frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    private func add() { if storage.addTask(draft) { draft = "" } }
}
