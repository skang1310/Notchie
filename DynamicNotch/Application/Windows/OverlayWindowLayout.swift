//
//  OverlayWindowLayout.swift
//  DynamicNotch
//
//  Created by Евгений Петрукович on 6/28/26.
//

import SwiftUI

enum OverlayWindowLayout {
    static let appCanvasSize = CGSize(width: 1000, height: 1000)

    static func lockScreenCanvasFrame(on screen: NSScreen) -> NSRect {
        screen.frame
    }

    static func topAnchoredFrame(on screen: NSScreen, size: CGSize, yOffset: CGFloat = 1) -> NSRect {
        topAnchoredFrame(screenFrame: screen.frame, size: size, yOffset: yOffset)
    }

    static func canvasSize(for screenSize: CGSize) -> CGSize {
        CGSize(width: min(appCanvasSize.width, screenSize.width), height: min(appCanvasSize.height, screenSize.height))
    }

    static func fitScale(content: CGSize, available: CGSize) -> CGFloat {
        guard content.width > 0, content.height > 0, available.width > 0, available.height > 0 else { return 1 }
        return min(1, available.width / content.width, available.height / content.height)
    }

    static func topAnchoredFrame(screenFrame: CGRect, size: CGSize, yOffset: CGFloat = 1) -> NSRect {
        let x = floor(screenFrame.midX - size.width / 2)
        let y = screenFrame.maxY - size.height + yOffset

        return NSRect(origin: CGPoint(x: x, y: y), size: size)
    }
}
