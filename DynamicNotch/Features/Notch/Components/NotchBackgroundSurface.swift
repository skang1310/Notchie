import SwiftUI

struct NotchBackgroundSurface: View {
    let style: NotchBackgroundStyle
    let topCornerRadius: CGFloat
    let bottomCornerRadius: CGFloat
    let isDynamicIsland: Bool
    let dynamicIslandCornerRadius: CGFloat
    let strokeColor: Color
    var strokeWidth: CGFloat = 2.0
    var height: CGFloat? = nil
    var baseWidth: CGFloat? = nil
    var baseHeight: CGFloat? = nil
    
    var body: some View {
        if isDynamicIsland {
            let shape = DynamicIslandShape(cornerRadius: dynamicIslandCornerRadius)
            baseSurface(shape: shape)
                .contentShape(shape)
                .overlay {
                    shape.stroke(strokeColor, lineWidth: strokeWidth)
                }
        } else {
            let shape = NotchShape(topCornerRadius: topCornerRadius, bottomCornerRadius: bottomCornerRadius)
            baseSurface(shape: shape)
                .contentShape(shape)
                .overlay {
                    shape.stroke(strokeColor, lineWidth: strokeWidth)
                }
        }
    }
    
    @ViewBuilder
    private func baseSurface<S: Shape>(shape: S) -> some View {
        let isExpanded = (height ?? 0) > ((baseHeight ?? 38) + 24)
        switch style {
        case .black:
            ZStack {
                shape.fill(.black)
                if isExpanded {
                    shape.fill(
                        LinearGradient(
                            colors: [
                                .black,
                                .black,
                                Color.white.opacity(0.035),
                                Color.white.opacity(0.065)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    shape.stroke(
                        LinearGradient(
                            colors: [
                                .clear,
                                Color.white.opacity(0.08),
                                Color.white.opacity(0.18)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.9
                    )
                }
            }
        }
    }
}
