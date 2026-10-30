internal import AppKit
import SwiftUI

struct CalendarNotchContent: NotchContentProtocol, DynamicIslandCustomizable {
    let id = NotchContentRegistry.Calendar.upcoming.id
    let calendarViewModel: CalendarViewModel
    let notchViewModel: NotchViewModel
    
    var priority: Int { NotchContentRegistry.Calendar.upcoming.priority }
    var isExpandable: Bool { true }
    
    var windowLink: (@MainActor () -> Void)? {
        return {
            calendarViewModel.openCalendarEvent()
        }
    }
    
    var requiredExtraWidth: CGFloat {
        let time = calendarViewModel.formattedNextEventTime
        guard !time.isEmpty else { return 110 }
        
        let font = NSFont.systemFont(ofSize: 14)
        let textWidth = (time as NSString).size(withAttributes: [.font: font]).width
        // Trailing padding 14 + textWidth + inner notch bezel margin 14
        let singleWingNeeded = textWidth + 28
        let dynamicWidth = singleWingNeeded * 2
        return max(200, ceil(dynamicWidth))
    }
    
    func compactSize(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        return .init(width: baseWidth + requiredExtraWidth, height: baseHeight)
    }
    
    func expandedSize(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        .init(width: baseWidth + 130, height: baseHeight + 90)
    }
    
    func dynamicIslandSize(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        let extraWidth = max(180, requiredExtraWidth - 10)
        return .init(width: baseWidth + extraWidth, height: baseHeight)
    }
    
    func expandedDynamicIslandSize(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        .init(width: baseWidth + 200, height: baseHeight + 85)
    }
    
    func expandedCornerRadius(baseRadius: CGFloat) -> (top: CGFloat, bottom: CGFloat) {
        (top: 24, bottom: 36)
    }
    
    func expandedDynamicIslandCornerRadius(baseHeight: CGFloat) -> CGFloat {
        baseHeight * 0.3
    }
    
    @MainActor
    func compactView() -> AnyView {
        AnyView(CalendarMinimalNotchView(calendarViewModel: calendarViewModel))
    }
    
    @MainActor
    func expandedView() -> AnyView {
        AnyView(CalendarExpandedNotchView(calendarViewModel: calendarViewModel, notchViewModel: notchViewModel))
    }
}
