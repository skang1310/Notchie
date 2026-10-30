import SwiftUI
internal import EventKit

struct CalendarExpandedNotchView: View {
    @ObservedObject var calendarViewModel: CalendarViewModel
    @Environment(\.isNotchlessScreen) private var isNotchlessScreen
    @Environment(\.locale) private var locale
    
    let notchViewModel: NotchViewModel

    @State private var isShowingFullSchedule = false
    @State private var isHoveringEvent = false
    @State private var scrollMonitor: Any? = nil
    @State private var accumulatedScrollDelta: CGFloat = 0
    
    var body: some View {
        VStack {
            Spacer()
            
            if isShowingFullSchedule {
                fullScheduleList
                    .transition(.opacity)
            } else if let event = calendarViewModel.nextEvent {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        title(event: event)
                        clock(event: event)
                        location(event: event)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                            isShowingFullSchedule = true
                        }
                    }
                    .onHover { hovering in
                        handleEventHover(hovering)
                    }
                    
                    Spacer()
                    buttons(event: event)
                }
            } else {
                Text(locale.dn("notch.calendar.noEvents", fallback: "No upcoming events"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.gray.opacity(0.6))
            }
        }
        .padding(.leading, isNotchlessScreen ? 20 : 45)
        .padding(.trailing, isNotchlessScreen ? 15 : 40)
        .padding(.bottom, isNotchlessScreen ? 20 : 18)
        .onDisappear {
            isHoveringEvent = false
            removeScrollMonitor()
            isShowingFullSchedule = false
        }
    }

    private func physicalVerticalDelta(from event: NSEvent) -> CGFloat {
        let deltaY = CGFloat(event.scrollingDeltaY)
        return event.isDirectionInvertedFromDevice ? -deltaY : deltaY
    }

    private func handleEventHover(_ hovering: Bool) {
        isHoveringEvent = hovering
        if hovering {
            accumulatedScrollDelta = 0
            if scrollMonitor == nil {
                scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
                    if abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) * 1.5 {
                        return event
                    }

                    let physicalDelta = self.physicalVerticalDelta(from: event)

                    if !self.isShowingFullSchedule {
                        // Closed: downward scroll ("밑으로") opens full schedule
                        if physicalDelta < -0.25 {
                            self.accumulatedScrollDelta += physicalDelta
                            if self.accumulatedScrollDelta <= -0.9 || abs(event.scrollingDeltaY) >= 0.8 {
                                self.accumulatedScrollDelta = 0
                                DispatchQueue.main.async {
                                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                                        self.isShowingFullSchedule = true
                                    }
                                }
                                return nil
                            }
                        } else if physicalDelta > 0.25 {
                            self.accumulatedScrollDelta = 0
                        }
                        return event
                    } else {
                        // Open: upward scroll ("위로") closes full schedule
                        if physicalDelta > 0.25 {
                            self.accumulatedScrollDelta += physicalDelta
                            if self.accumulatedScrollDelta >= 0.9 || abs(event.scrollingDeltaY) >= 0.8 {
                                self.accumulatedScrollDelta = 0
                                DispatchQueue.main.async {
                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                                        self.isShowingFullSchedule = false
                                    }
                                }
                                return nil
                            }
                        } else if physicalDelta < -0.25 {
                            self.accumulatedScrollDelta = 0
                        }
                        return event
                    }
                }
            }
        } else {
            removeScrollMonitor()
        }
    }

    private func removeScrollMonitor() {
        if let monitor = scrollMonitor {
            NSEvent.removeMonitor(monitor)
            scrollMonitor = nil
        }
        accumulatedScrollDelta = 0
    }

    @ViewBuilder
    private var fullScheduleList: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(locale.dn("notch.calendar.todaySchedule", fallback: "Today's Schedule"))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                Text("\(calendarViewModel.events.count)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color.blue.opacity(0.2), in: Capsule())
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                        isShowingFullSchedule = false
                    }
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.gray)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                    isShowingFullSchedule = false
                }
            }
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(calendarViewModel.events, id: \.eventIdentifier) { ev in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(ev.calendar?.cgColor.map { Color(cgColor: $0) } ?? Color.blue)
                                .frame(width: 4, height: 4)
                            Text(timeString(from: ev.startDate))
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(.gray)
                            Text(calendarViewModel.displayTitle(for: ev))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            Spacer()
                            if let url = MeetingLink.first(url: ev.url, notes: ev.notes, location: ev.location) {
                                Button {
                                    NSWorkspace.shared.open(url)
                                } label: {
                                    Text(locale.dn("notch.calendar.join", fallback: "Join"))
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue, in: Capsule())
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .frame(maxHeight: 70)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                isShowingFullSchedule = false
            }
        }
        .onHover { hovering in
            handleEventHover(hovering)
        }
    }
    
    @ViewBuilder
    private func title(event: EKEvent) -> some View {
        let displayTitle = calendarViewModel.displayTitle(for: event)
        MarqueeText(
            .constant(displayTitle),
            font: .system(size: 18, weight: .bold),
            nsFont: .headline,
            textColor: .white,
            backgroundColor: .clear,
            minDuration: 2.0,
            frameWidth: 200
        )
    }
    
    @ViewBuilder
    private func clock(event: EKEvent) -> some View {
        HStack {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 16))
                .foregroundColor(.gray)
            
            if event.isAllDay {
                Text(locale.dn("notch.calendar.allDay", fallback: "All Day"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.red)
            } else {
                Text(timeString(from: event.startDate) + " - " + timeString(from: event.endDate))
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
                    .foregroundColor(.red)
            }
        }
    }
    
    @ViewBuilder
    private func location(event: EKEvent) -> some View {
        if let location = calendarViewModel.displayLocation(for: event), !location.isEmpty {
            MarqueeText(
                .constant(location),
                font: .system(size: 12),
                nsFont: .headline,
                textColor: .gray.opacity(0.8),
                backgroundColor: .clear,
                minDuration: 4.0,
                frameWidth: 200
            )
        } else {
            Text(calendarViewModel.isPrivacyModeEnabled ? locale.dn("notch.calendar.privateEvent", fallback: "Private Event") : locale.dn("notch.calendar.emptyLocation", fallback: "Empty Location"))
                .font(.system(size: 12))
                .lineLimit(1)
                .foregroundColor(.gray.opacity(0.8))
        }
    }
    
    @ViewBuilder
    private func buttons(event: EKEvent) -> some View {
        VStack(spacing: 8) {
          TimelineView(.periodic(from: .now, by: 30)) { _ in
              Text(event.startDate, style: .relative).font(.caption).monospacedDigit()
          }
          HStack {
            Button {
                calendarViewModel.dismissEvent(event)
                notchViewModel.send(.hideLiveActivity(id: NotchContentRegistry.Calendar.upcoming.id))
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
            }
            .buttonStyle(PrimaryButtonStyle(width: 45, height: 45, backgroundColor: .gray.opacity(0.3)))
            
            if let url = MeetingLink.first(url: event.url, notes: event.notes, location: event.location) {
                Button {
                    NSWorkspace.shared.open(url)
                    notchViewModel.send(.hideLiveActivity(id: NotchContentRegistry.Calendar.upcoming.id))
                } label: {
                    HStack {
                        Image(systemName: "video.fill")
                        Text(locale.dn("notch.calendar.joinMeeting", fallback: "Join Meeting"))
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
            }
          }
        }
    }
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
}
