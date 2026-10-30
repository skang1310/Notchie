//
//  TimerCountdownText.swift
//  DynamicNotch
//
//  Created by Евгений Петрукович on 4/17/26.
//

import SwiftUI

struct TimerCountdownText: View {
    let source: TimerSource
    @State private var isPresentationVisible = false
    
    @Environment(\.isNotchlessScreen) private var isNotchlessScreen

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.25, paused: source.isPaused || !isPresentationVisible)) { context in
            let formatted = source.formattedTime(at: context.date)
            Text(formatted)
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(.orange.gradient)
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .background(PresentationVisibilityReader(isVisible: $isPresentationVisible).frame(width: 0, height: 0))
    }
}
