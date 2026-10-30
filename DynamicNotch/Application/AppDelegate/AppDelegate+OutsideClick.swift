import SwiftUI
import Combine

extension AppDelegate {
    func observeOutsideClickDismissal() {
        NotificationCenter.default.publisher(for: NSMenu.didBeginTrackingNotification)
            .sink { [weak self] _ in
                guard let self else { return }
                self.menuTrackingDepth += 1
                self.notchViewModel.isMenuTracking = true
            }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: NSMenu.didEndTrackingNotification)
            .sink { [weak self] _ in
                guard let self else { return }
                self.menuTrackingDepth = max(0, self.menuTrackingDepth - 1)
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.notchViewModel.isMenuTracking = self.menuTrackingDepth > 0
                }
            }
            .store(in: &cancellables)
        notchViewModel.$notchModel
            .map(\.isLiveActivityExpanded)
            .removeDuplicates()
            .sink { [weak self] isEnabled in
                guard let self else { return }

                if isEnabled {
                    startOutsideClickMonitoring()
                } else {
                    stopOutsideClickMonitoring()
                }
            }
            .store(in: &cancellables)
    }

    func startOutsideClickMonitoring() {
        expansionTime = Date()

        if localClickMonitor == nil {
            localClickMonitor = NSEvent.addLocalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
            ) { [weak self] event in
                let sourceWindow = event.window
                let screenLocation =
                    sourceWindow?.convertPoint(toScreen: event.locationInWindow) ??
                    NSEvent.mouseLocation

                Task { @MainActor [weak self] in
                    self?.handleLocalClick(from: sourceWindow, atScreenLocation: screenLocation)
                }

                return event
            }
        }

        globalClickMonitor.start { [weak self] _ in
            let screenLocation = NSEvent.mouseLocation
            Task { @MainActor [weak self] in
                self?.handleGlobalClick(atScreenLocation: screenLocation)
            }
        }
    }

    func stopOutsideClickMonitoring() {
        if let localClickMonitor {
            NSEvent.removeMonitor(localClickMonitor)
        }

        localClickMonitor = nil
        globalClickMonitor.stop()
    }

    @MainActor
    func handleLocalClick(from sourceWindow: NSWindow?, atScreenLocation screenLocation: NSPoint) {
        guard shouldHandleOutsideClick else { return }
        if QuickToolsStore.shared.isSoundMixerVisibleInCalendarSlot || SoundMixerService.shared.isAdjustingVolume {
            if sourceWindow == window {
                return
            }
        }
        guard let activeNotchScreenRect else {
            notchViewModel.handleOutsideClick()
            return
        }

        guard !activeNotchScreenRect.contains(screenLocation) else { return }
        notchViewModel.handleOutsideClick()
    }

    @MainActor
    func handleGlobalClick(atScreenLocation screenLocation: NSPoint) {
        guard shouldHandleOutsideClick else { return }
        if SoundMixerService.shared.isAdjustingVolume {
            return
        }
        guard let activeNotchScreenRect else {
            notchViewModel.handleOutsideClick()
            return
        }

        guard !activeNotchScreenRect.contains(screenLocation) else { return }
        notchViewModel.handleOutsideClick()
    }

    @MainActor
    var shouldHandleOutsideClick: Bool {
        guard notchViewModel.notchModel.isLiveActivityExpanded, !notchViewModel.isMenuTracking else { return false }
        guard !SoundMixerService.shared.isAdjustingVolume else { return false }
        guard Date().timeIntervalSince(expansionTime) > 0.15 else { return false }
        return true
    }

    @MainActor
    var activeNotchScreenRect: CGRect? {
        guard let window else { return nil }

        let notchSize = notchViewModel.notchModel.size
        guard notchSize.width > 0, notchSize.height > 0 else { return nil }

        let scale = notchViewModel.presentationScale
        let height = notchSize.height * scale
        let width = notchSize.width * scale
        let originX = floor(window.frame.midX - width / 2)

        let origin = CGPoint(
            x: originX,
            y: window.frame.maxY - height - (notchViewModel.isDynamicIsland ? 9 : 1) * scale
        )

        return CGRect(origin: origin, size: CGSize(width: width, height: height)).insetBy(dx: -12, dy: -8)
    }
}
