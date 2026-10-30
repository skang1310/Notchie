import SwiftUI
import UniformTypeIdentifiers

extension AppDelegate {
    func createNotchWindow() {
        guard let screen =
            NSScreen.preferredNotchScreen(for: settingsViewModel) ??
            NSScreen.preferredNotchScreen(for: settingsViewModel.application) ??
            NSScreen.preferredNotchScreen(for: .main) ??
            NSScreen.screens.first
        else {
            return
        }

        let frame = OverlayWindowLayout.topAnchoredFrame(
            on: screen,
            size: OverlayWindowLayout.canvasSize(for: screen.frame.size)
        )

        window = OverlayPanelFactory.makePanel(
            frame: frame,
            level: OverlayWindowLevel.interactiveNotch
        )

        let hostingView = NotchHostingView(
            rootView: NotchView(
                notchEventCoordinator: notchEventCoordinator,
                notchViewModel: notchViewModel,
                airDropViewModel: airDropViewModel,
                airDropController: airDropController,
                settingsViewModel: settingsViewModel
            )
        )
        hostingView.frame = NSRect(origin: .zero, size: frame.size)
        hostingView.autoresizingMask = [.width, .height]

        window.contentView = hostingView
        window.collectionBehavior = OverlayPanelFactory.collectionBehavior(
            includesFullscreenAuxiliary: true
        )
        SkyLightOperator.shared.delegateWindow(window, to: .notchSurface)
        updateWindowFrame()
        reRegisterDragDestination(for: window)
    }

    @objc
    func updateWindowFrame() {
        guard let window else { return }

        notchViewModel.updateDimensions(animated: false)

        guard let screen = NSScreen.preferredNotchScreen(for: settingsViewModel) else {
            clearNowPlayingPrimaryWindowPresentationState()
            notchViewModel.invalidatePointerInteraction()
            notchViewModel.isPrimarySurfaceHidden = true
            window.orderOut(nil)
            return
        }
        notchViewModel.updatePresentationBounds(screen.frame.size)

        let targetFrame = OverlayWindowLayout.topAnchoredFrame(
            on: screen,
            size: OverlayWindowLayout.canvasSize(for: screen.frame.size)
        )

        window.collectionBehavior = OverlayPanelFactory.collectionBehavior(
            includesFullscreenAuxiliary: true
        )
        if window.frame != targetFrame {
            notchViewModel.invalidatePointerInteraction()
            window.setFrame(targetFrame, display: true, animate: false)
            reRegisterDragDestination(for: window)
        }
        updatePrimaryWindowPresentation(on: screen)
    }

    func suspendPrimaryWindowForLock() {
        guard let window, !isPrimaryWindowSuspendedForLock else { return }

        isPrimaryWindowSuspendedForLock = true
        notchViewModel.invalidatePointerInteraction()
        notchViewModel.isPrimarySurfaceHidden = true
        notchViewModel.isLocked = true
        airDropController.resetTargetState()
        clearNowPlayingPrimaryWindowPresentationState()
        
        window.orderOut(nil)
    }

    func restorePrimaryWindowForUnlockTransition() {
        guard let window, isPrimaryWindowSuspendedForLock else { return }

        isPrimaryWindowSuspendedForLock = false
        notchViewModel.isLocked = false
        airDropController.resetTargetState()
        
        updateWindowFrame()
        reRegisterDragDestination(for: window)
    }

    func reRegisterDragDestination(for window: NSWindow) {
        let revision = UUID()
        dragRegistrationRevision = revision
        let dragTypes: [NSPasteboard.PasteboardType] = [
            .fileURL,
            .URL,
            NSPasteboard.PasteboardType(UTType.data.identifier)
        ]

        func notifyViews(_ view: NSView) {
            if let dragView = view as? DragAndDropView {
                dragView.registerTypes()
            }
            for subview in view.subviews {
                notifyViews(subview)
            }
        }

        func performRegistration() {
            window.registerForDraggedTypes(dragTypes)
            if let contentView = window.contentView {
                notifyViews(contentView)
            }
        }

        // Immediate pass
        performRegistration()

        // Staggered passes to ensure WindowServer space transition has finished
        for delay in [0.2, 0.6, 1.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, weak window] in
                guard let self, let window, self.window === window, self.dragRegistrationRevision == revision else { return }
                performRegistration()
            }
        }
    }

    private func updatePrimaryWindowPresentation(on screen: NSScreen) {
        guard let window, !isPrimaryWindowSuspendedForLock else { return }

        let isFullscreen = SkyLightOperator.shared.isFullscreenSpaceActive(on: screen)
        let shouldHideActivities = settingsViewModel.application.isNotchHiddenInFullscreenEnabled && isFullscreen
        let shouldHideNotchlessIsland = screen.isNotchless && settingsViewModel.application.isDynamicIslandHiddenInFullscreenEnabled && isFullscreen
        notchViewModel.isPrimarySurfaceHidden = shouldHideNotchlessIsland && !notchViewModel.hasDisplayedContent

        notchViewModel.setActivityPresentationHidden(shouldHideActivities)

        if shouldHideActivities {
            clearNowPlayingPrimaryWindowPresentationState()
        }

        if shouldHideNotchlessIsland {
            if notchViewModel.hasDisplayedContent {
                hideWindowWorkItem?.cancel()
                hideWindowWorkItem = nil
                window.orderFrontRegardless()
            } else {
                scheduleDynamicIslandOrderOut()
            }
        } else {
            hideWindowWorkItem?.cancel()
            hideWindowWorkItem = nil
            window.orderFrontRegardless()
        }
    }

    private func scheduleDynamicIslandOrderOut() {
        guard hideWindowWorkItem == nil else { return }

        let workItem = DispatchWorkItem { [weak self] in
            guard let self,
                  let screen = NSScreen.preferredNotchScreen(for: self.settingsViewModel),
                  screen.isNotchless,
                  SkyLightOperator.shared.isFullscreenSpaceActive(on: screen),
                  self.settingsViewModel.application.isDynamicIslandHiddenInFullscreenEnabled,
                  !self.notchViewModel.hasDisplayedContent else {
                self?.hideWindowWorkItem = nil
                return
            }
            self.window?.orderOut(nil)
            self.hideWindowWorkItem = nil
        }
        hideWindowWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: workItem)
    }

    private func clearNowPlayingPrimaryWindowPresentationState() {
        nowPlayingViewModel.clearPresentationActivityState()
    }
}
