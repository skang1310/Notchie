//
//  NotchAnimations.swift
//  DynamicNotch
//
//  Created by Евгений Петрукович on 3/29/26.
//

import SwiftUI

struct NotchAnimations {
    // MARK: - Notifications & Content Lifecycle
    /// Animation used when updating notch content/geometry without full collapse.
    let updateContent: Animation
    /// Animation used when collapsing/hiding notch content.
    let hideContent: Animation
    /// Animation used when expanding/showing notch content from collapsed state.
    let showContent: Animation
    /// Transition animation applied to compact notch content on appearance.
    let compactContentTransition: Animation

    // MARK: - Live Activity
    /// Geometry animation when expanding Live Activity from compact to expanded state.
    let expandLiveActivity: Animation
    /// Transition animation for content appearing inside expanded Live Activity.
    let expandedLiveActivityContentTransition: Animation
    /// Geometry animation when collapsing Live Activity back to compact or closed state.
    let collapseLiveActivity: Animation
    /// Transition animation for content disappearing when Live Activity collapses.
    let collapsedLiveActivityContentTransition: Animation

    // MARK: - Gestures & Interactions
    /// Spring animation returning the notch to resting state after swipe/drag stretch.
    let stretchReset: Animation
    /// Squeeze-and-bounce spring animation when notch loses focus or is dismissed.
    let focusDismissBounce: Animation

    // MARK: - Shell Visibility & Stroke
    /// Animation for showing/hiding the decorative border stroke.
    let strokeVisibility: Animation
    /// Animation for overall notch window visibility toggle.
    let notchVisibility: Animation

    // MARK: - Delays
    /// Delay between hiding previous item and displaying next item.
    let transitionDelay: TimeInterval
    /// Minimum pacing delay when processing queue items.
    let queuePacingDelay: TimeInterval

    // MARK: - Presets
    static let `default`: Self = .fluid

    static let fluid: Self = {
        // Authentic Apple Dynamic Island physics:
        // Response: 0.38s (quick snappy anticipation)
        // Damping: 0.68 (controlled organic bounce, fluid liquid feel)
        // Blend: 0.15s (seamless gesture handoff and morphing)
        let damping: Double = 0.68
        let expandDamping: Double = 0.72
        let baseResponse: Double = 0.38
        let blend: Double = 0.15

        return Self(
            updateContent: .spring(response: baseResponse, dampingFraction: 0.78, blendDuration: blend),
            hideContent: .spring(response: 0.32, dampingFraction: 0.82, blendDuration: blend),
            showContent: .spring(response: baseResponse, dampingFraction: damping, blendDuration: blend),
            compactContentTransition: .spring(response: baseResponse, dampingFraction: damping, blendDuration: blend),

            expandLiveActivity: .spring(response: baseResponse, dampingFraction: expandDamping, blendDuration: blend),
            expandedLiveActivityContentTransition: .spring(response: baseResponse, dampingFraction: expandDamping, blendDuration: blend),

            collapseLiveActivity: .spring(response: 0.32, dampingFraction: 0.80, blendDuration: 0.12),
            collapsedLiveActivityContentTransition: .spring(response: baseResponse, dampingFraction: 0.80, blendDuration: blend),

            stretchReset: .spring(response: 0.35, dampingFraction: 0.62, blendDuration: 0.10),
            focusDismissBounce: .spring(response: 0.35, dampingFraction: 0.62, blendDuration: 0.10),
            strokeVisibility: .spring(response: baseResponse, blendDuration: blend),
            notchVisibility: .spring(response: baseResponse, blendDuration: blend),

            transitionDelay: 0.22,
            queuePacingDelay: 0.20
        )
    }()

    static let balanced: Self = {
        let damping: Double = 0.70
        let expandDamping: Double = 0.90
        let baseResponse: Double = 0.47
        let blend: Double = 1.0

        return Self(
            updateContent: .spring(response: baseResponse, dampingFraction: 0.90, blendDuration: 0.15),
            hideContent: .spring(response: baseResponse, dampingFraction: damping, blendDuration: blend),
            showContent: .spring(response: baseResponse, dampingFraction: damping, blendDuration: blend),
            compactContentTransition: .spring(response: baseResponse, dampingFraction: damping, blendDuration: blend),

            expandLiveActivity: .spring(response: baseResponse, dampingFraction: expandDamping, blendDuration: blend),
            expandedLiveActivityContentTransition: .spring(response: baseResponse, dampingFraction: expandDamping, blendDuration: blend),

            collapseLiveActivity: .spring(response: 0.40, dampingFraction: 0.94, blendDuration: 0.15),
            collapsedLiveActivityContentTransition: .spring(response: baseResponse, blendDuration: blend),

            stretchReset: .spring(response: baseResponse, blendDuration: blend),
            focusDismissBounce: .spring(response: baseResponse, blendDuration: blend),
            strokeVisibility: .spring(response: baseResponse, blendDuration: blend),
            notchVisibility: .spring(response: baseResponse, blendDuration: blend),

            transitionDelay: 0.32,
            queuePacingDelay: 0.30
        )
    }()

    static func preset(_ preset: NotchAnimationPreset = .fluid) -> Self {
        switch preset {
        case .fluid:
            return .fluid
        case .balanced:
            return .balanced
        }
    }
}
