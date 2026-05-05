import SwiftUI

struct LiquidGlass: View {
    var cornerRadius: CGFloat = 16
    var tint: Color = .white.opacity(0.2)
    var highlight: Color = .white.opacity(0.6)
    var shadow: Color = .black.opacity(0.25)
    var intensity: Double = 0.6
    var interactive: Bool = true

    #if os(macOS)
    @State private var pointerLocation: CGPoint = .zero
    #else
    // On iOS/tvOS/watchOS no pointerLocation needed
    #endif

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background blur material with corner radius
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                
                // Gradient tint overlay
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                tint.opacity(intensity),
                                tint.opacity(intensity * 0.4)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Inner highlight stroke with blend mode overlay
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(highlight, lineWidth: 1.5)
                    .blendMode(.overlay)

                // Soft outer shadow
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(shadow.opacity(0.5), lineWidth: 1)
                    .shadow(color: shadow, radius: 8, x: 0, y: 4)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                
                // Specular highlight
                if interactive {
                    // Specular highlight shape
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    highlight.opacity(0.6),
                                    highlight.opacity(0)
                                ]),
                                center: .center,
                                startRadius: 0,
                                endRadius: geo.size.width * 0.5
                            )
                        )
                        .frame(width: geo.size.width * 1.5, height: geo.size.width * 1.5)
                        .position(pointerPosition(in: geo.size))
                        .animation(.easeOut(duration: 0.3), value: pointerLocation)
                        .allowsHitTesting(false)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            #if os(macOS)
            .onHover { hover in
                if hover {
                    // do nothing on hover start; keep tracking mouse move
                } else {
                    // When mouse leaves, reset pointer to center
                    pointerLocation = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                }
            }
            .background(
                MouseTrackingView { location in
                    pointerLocation = location
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            )
            #endif
        }
        .aspectRatio(1, contentMode: .fit)
    }

    #if os(macOS)
    // Calculate the specular highlight position, clamped inside the view bounds
    private func pointerPosition(in size: CGSize) -> CGPoint {
        let x = min(max(pointerLocation.x, 0), size.width)
        let y = min(max(pointerLocation.y, 0), size.height)
        return CGPoint(x: x, y: y)
    }
    #else
    private func pointerPosition(in size: CGSize) -> CGPoint {
        CGPoint(x: size.width * 0.3, y: size.height * 0.3)
    }
    #endif
}

#if os(macOS)
/// NSViewRepresentable to track mouse location inside the view
fileprivate struct MouseTrackingView: NSViewRepresentable {
    var onMove: (CGPoint) -> Void

    func makeNSView(context: Context) -> NSTrackingView {
        let view = NSTrackingView()
        view.onMove = onMove
        return view
    }

    func updateNSView(_ nsView: NSTrackingView, context: Context) { }
    
    class NSTrackingView: NSView {
        var onMove: ((CGPoint) -> Void)?

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            trackingAreas.forEach { removeTrackingArea($0) }
            let options: NSTrackingArea.Options = [.mouseMoved, .activeInActiveApp, .inVisibleRect]
            let trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
            addTrackingArea(trackingArea)
        }

        override func mouseMoved(with event: NSEvent) {
            let location = convert(event.locationInWindow, from: nil)
            onMove?(location)
        }
    }
}
#endif

struct LiquidGlassContainerStyle: ViewModifier {
    var cornerRadius: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        colorScheme == .dark
                        ? Color.white.opacity(0.1)
                        : Color.black.opacity(0.08),
                        lineWidth: 1
                    )
            )
    }
}

extension View {
    func liquidGlassContainer(
        cornerRadius: CGFloat = 16,
        tint: Color = .white.opacity(0.18),
        intensity: Double = 0.6
    ) -> some View {
        self
            .padding()
            .background(
                LiquidGlass(
                    cornerRadius: cornerRadius,
                    tint: tint,
                    intensity: intensity
                )
            )
            .modifier(LiquidGlassContainerStyle(cornerRadius: cornerRadius))
    }
}

#Preview {
    VStack(spacing: 20) {
        Text("Liquid Glass Panel")
            .font(.title.weight(.semibold))
            .foregroundColor(.primary)

        VStack(spacing: 12) {
            HStack {
                Text("Volume")
                Slider(value: .constant(0.5))
            }
            HStack {
                Text("Balance")
                Slider(value: .constant(0.3))
            }
            HStack {
                Text("Bass")
                Slider(value: .constant(0.7))
            }
        }
        .padding()
        .liquidGlassContainer(cornerRadius: 24, tint: .blue.opacity(0.25), intensity: 0.7)
        .frame(maxWidth: 340)
    }
    .padding(40)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(
        LinearGradient(
            colors: [
                Color.blue.opacity(0.15),
                Color.purple.opacity(0.1)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    )
}
