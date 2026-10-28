//
//  FaceIDNotchView.swift
//  DynamicNotch
//

import SwiftUI

struct FaceIDNotchView: View {
    var style: FaceIDPresentationStyle = .expanded
    
    @Environment(\.isNotchlessScreen) private var isNotchlessScreen
    @Environment(\.notchScale) private var scale
    @ObservedObject var service: FaceIDService = .shared
    
    @State private var hasSucceeded: Bool = false
    
    private var scanMedia: ScanMedia {
        if hasSucceeded {
            return .success
        }
        switch service.state {
        case .idle:
            return .idle
        case .searching:
            return .searching
        case .scanning:
            return .scanning
        case .success:
            return .success
        case .failed:
            return .failure
        }
    }
    
    private var headlineColor: Color {
        let accent = ApplicationSettingsStore.currentCustomAccentColor()
        switch service.state {
        case .searching, .scanning, .success:
            return accent
        case .failed:
            return hasSucceeded ? accent : .red.opacity(0.85)
        default:
            return accent
        }
    }
    
    private var isUnlockedState: Bool {
        hasSucceeded || service.state.isSuccess
    }
    
    var body: some View {
        Group {
            if style == .compact {
                minimalNotchBody
            } else {
                originalBadgeBody
            }
        }
        .onChange(of: service.state) { _, newState in
            switch newState {
            case .success:
                hasSucceeded = true
            case .searching, .scanning:
                hasSucceeded = false
            default:
                break
            }
        }
    }
    
    private var originalBadgeBody: some View {
        VStack(spacing: 6) {
            Spacer(minLength: isNotchlessScreen ? 6 : 22)
            
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [headlineColor.opacity(0.18), .clear],
                            center: .center,
                            startRadius: 4,
                            endRadius: 56
                        )
                    )
                    .frame(width: 112, height: 112)
                
                ScanAnimationView(media: scanMedia, tintColor: headlineColor)
                    .frame(width: isNotchlessScreen ? 96 : 104, height: isNotchlessScreen ? 96 : 104)
            }
            
            Spacer(minLength: 8)
        }
    }
    
    private var minimalNotchBody: some View {
        HStack {
            Image(systemName: isUnlockedState ? "lock.open.fill" : "lock.fill")
                .contentTransition(.symbolEffect(.replace))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isUnlockedState ? headlineColor : .white)
                .scaleEffect(1.25)
            
            Spacer()
            
            ScanAnimationView(media: scanMedia, tintColor: headlineColor)
                .frame(width: isNotchlessScreen ? 28 : 32, height: isNotchlessScreen ? 28 : 32)
        }
        .padding(.leading, isNotchlessScreen ? 12.scaled(by: scale) : 18.scaled(by: scale))
        .padding(.trailing, isNotchlessScreen ? 8.scaled(by: scale) : 14.scaled(by: scale))
    }
}
