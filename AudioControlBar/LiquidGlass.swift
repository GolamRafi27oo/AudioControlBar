import SwiftUI

enum GlassProminence { case regular, clear }

struct AdaptiveGlassModifier<S: Shape>: ViewModifier {
    let shape: S
    let tint: Color?
    let prominence: GlassProminence
    let interactive: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.modifier(NativeGlassModifier(shape: shape, tint: tint, prominence: prominence, interactive: interactive))
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay {
                    shape.stroke(
                        LinearGradient(colors: [.white.opacity(0.42), .white.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 0.75
                    )
                }
                .shadow(color: .black.opacity(0.10), radius: 14, y: 7)
        }
    }
}

@available(macOS 26.0, *)
private struct NativeGlassModifier<S: Shape>: ViewModifier {
    let shape: S
    let tint: Color?
    let prominence: GlassProminence
    let interactive: Bool

    func body(content: Content) -> some View {
        var glass: Glass = prominence == .clear ? .clear : .regular
        if let tint { glass = glass.tint(tint) }
        if interactive { glass = glass.interactive() }
        return content.glassEffect(glass, in: shape)
    }
}

extension View {
    func adaptiveGlass<S: Shape>(in shape: S, tint: Color? = nil, prominence: GlassProminence = .regular, interactive: Bool = false) -> some View {
        modifier(AdaptiveGlassModifier(shape: shape, tint: tint, prominence: prominence, interactive: interactive))
    }

    func glassCard(tint: Color? = nil) -> some View {
        adaptiveGlass(in: RoundedRectangle(cornerRadius: 22, style: .continuous), tint: tint)
    }
}

struct GlassBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color(red: 0.055, green: 0.065, blue: 0.09), Color(red: 0.09, green: 0.075, blue: 0.13)]
                    : [Color(red: 0.92, green: 0.96, blue: 1), Color(red: 0.97, green: 0.93, blue: 1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(Color.blue.opacity(colorScheme == .dark ? 0.28 : 0.22))
                .frame(width: 270, height: 270)
                .blur(radius: 55)
                .offset(x: -155, y: -210)
            Circle()
                .fill(Color.purple.opacity(colorScheme == .dark ? 0.22 : 0.16))
                .frame(width: 240, height: 240)
                .blur(radius: 60)
                .offset(x: 175, y: 210)
        }
        .ignoresSafeArea()
    }
}

struct GlassIconButton: View {
    let systemName: String
    let help: String
    var tint: Color? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 30, height: 30)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(tint ?? .primary)
        .adaptiveGlass(in: Circle(), tint: tint?.opacity(0.16), prominence: .clear, interactive: true)
        .help(help)
    }
}
