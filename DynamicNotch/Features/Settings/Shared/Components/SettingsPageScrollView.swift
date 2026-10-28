//
//  SettingsPageScrollView.swift
//  DynamicNotch
//
//  Created by Евгений Петрукович on 4/4/26.
//

import SwiftUI

struct SettingsPageScrollView<Content: View>: View {
    private let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        if #available(macOS 26.0, *) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    content
                }
                .frame(maxWidth: 780, alignment: .leading)
                .padding(.vertical, 24)
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
            
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    content
                }
                .frame(maxWidth: 780, alignment: .leading)
                .padding(.vertical, 24)
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
    }
}
