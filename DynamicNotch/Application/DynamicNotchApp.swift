import Cocoa
import SwiftUI

@main
struct NotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("isMenuBarIconVisible") var isMenuBarIconVisible: Bool = true
    
    var body: some Scene {
        MenuBarExtra(isInserted: Binding(
            get: { !AppEnvironment.isRunningUnitTests && isMenuBarIconVisible },
            set: { isMenuBarIconVisible = $0 }
        )) {
            // Unit hosts must not initialize the production menu's services.
            if !AppEnvironment.isRunningUnitTests { MenuBarMenu() }
        } label: {
            Image(systemName: "rectangle.topthird.inset.filled")
        }
        .commands {
            CommandMenu("productivity.palette") {
                Button("productivity.palette") { ProductivityCoordinator.shared.showPalette() }
                    .keyboardShortcut("k", modifiers: [.command, .shift])
            }
            CommandGroup(replacing: .appSettings) {
                Button { SettingsWindowController.shared.showWindow() } label: {
                    Text("menuBar.settings")
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}
