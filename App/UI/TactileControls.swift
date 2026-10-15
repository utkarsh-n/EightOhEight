import SwiftUI
import UIKit

struct TactileKnob: View {
    @Binding var value: Double
    let label: String
    var cap: Color = .white
    var diameter: CGFloat = 40
    var haptics = true
    var displayValue: (Double) -> String = { String(Int($0 * 100)) }
    var identifier: String = ""
    @State private var origin: Double?
    @State private var active = false
    @State private var lastDetent = -1

    private var angle: Double { -135 + value * 270 }

    var body: some View {
        ZStack {
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = diameter * 0.62
                for tick in 0...10 {
                    let degrees = -225.0 + Double(tick) * 27
                    let radians = degrees * .pi / 180
                    let cosine = CGFloat(cos(radians))
                    let sine = CGFloat(sin(radians))
                    let outerRadius: CGFloat = radius + 3.5
                    let start = CGPoint(x: center.x + cosine * radius, y: center.y + sine * radius)
                    let end = CGPoint(x: center.x + cosine * outerRadius, y: center.y + sine * outerRadius)
                    var path = Path()
                    path.move(to: start)
                    path.addLine(to: end)
                    context.stroke(path, with: .color(tick == 0 || tick == 10 ? Color.eightOrange.opacity(0.85) : Color.eightInk.opacity(0.78)), lineWidth: 1)
                }
            }
            .frame(width: diameter * 1.5, height: diameter * 1.5)
            Circle().fill(.black).frame(width: diameter, height: diameter)
                .shadow(color: .black.opacity(0.95), radius: 3, x: 1.5, y: 3)
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                for rib in 0..<32 {
                    let radians = Double(rib) / 32 * 2 * .pi
                    let cosine = CGFloat(cos(radians))
                    let sine = CGFloat(sin(radians))
                    let innerRadius: CGFloat = diameter * 0.39
                    let outerRadius: CGFloat = diameter * 0.48
                    let start = CGPoint(x: center.x + cosine * innerRadius, y: center.y + sine * innerRadius)
                    let end = CGPoint(x: center.x + cosine * outerRadius, y: center.y + sine * outerRadius)
                    var path = Path()
                    path.move(to: start)
                    path.addLine(to: end)
                    context.stroke(path, with: .color(rib < 16 ? .white.opacity(0.14) : .white.opacity(0.055)), lineWidth: 1.6)
                }
            }.frame(width: diameter, height: diameter)
            Circle().fill(LinearGradient(colors: [Color(white: 0.23), Color(white: 0.045), Color(white: 0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: diameter * 0.76, height: diameter * 0.76)
            Circle().stroke(.black.opacity(0.8), lineWidth: 1).frame(width: diameter * 0.72, height: diameter * 0.72)
            ZStack {
                Circle().fill(cap.gradient).frame(width: diameter * 0.38, height: diameter * 0.38)
                    .shadow(color: .black.opacity(0.8), radius: 0.7, y: 1)
                Capsule().fill(Color.eightInk).frame(width: 2.5, height: diameter * 0.15)
                    .offset(y: -diameter * 0.315)
            }.rotationEffect(.degrees(angle))
            if active {
                valuePopup
                    .offset(y: -diameter * 0.92)
                    .zIndex(20)
            }
        }
        .frame(width: max(62, diameter * 1.5), height: max(62, diameter * 1.5))
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                if origin == nil { origin = value; active = true; lastDetent = Int(value * 20) }
                let distance = -gesture.translation.height + gesture.translation.width * 0.35
                value = min(1, max(0, (origin ?? value) + Double(distance) / 150))
                let detent = Int(value * 20)
                if haptics, detent != lastDetent {
                    UISelectionFeedbackGenerator().selectionChanged()
                    lastDetent = detent
                }
            }
            .onEnded { _ in origin = nil; active = false })
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(displayValue(value))
        .accessibilityHint("Swipe up or down to adjust. Drag vertically to turn the knob.")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(1, value + 0.05)
            case .decrement: value = max(0, value - 0.05)
            @unknown default: break
            }
        }
        .accessibilityIdentifier(identifier.isEmpty ? label : identifier)
    }
    private var valuePopup: some View {
        Text(displayValue(value))
            .font(.system(size: 12, weight: .semibold, design: .monospaced))
            .foregroundStyle(Color.eightInk)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Color.black.opacity(0.93), in: RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.white.opacity(0.15)))
    }
}

struct TactileSelector: View {
    @Binding var selection: Int
    let count: Int
    let label: String
    var diameter: CGFloat = 43
    var cap: Color = Color.eightInk
    var haptics = true
    var labels: [String] = []
    var identifier = ""
    private var binding: Binding<Double> {
        Binding(get: { Double(selection) / Double(max(1, count - 1)) }, set: { selection = Int(($0 * Double(max(1, count - 1))).rounded()) })
    }
    var body: some View {
        TactileKnob(value: binding, label: label, cap: cap, diameter: diameter, haptics: haptics, displayValue: { value in
            let index = Int((value * Double(max(1, count - 1))).rounded())
            return labels.indices.contains(index) ? labels[index] : String(index + 1)
        }, identifier: identifier)
    }
}

struct TinyLED: View {
    let lit: Bool
    var color: Color = .red
    var diameter: CGFloat = 7
    var body: some View {
        Circle().fill(Color(white: 0.035))
            .overlay { Circle().fill(lit ? color : Color(red: 0.20, green: 0.035, blue: 0.026)).padding(1) }
            .overlay(alignment: .topLeading) { Circle().fill(.white.opacity(lit ? 0.9 : 0.1)).frame(width: 2, height: 2).offset(x: 2, y: 1.5) }
            .shadow(color: lit ? color.opacity(0.6) : .clear, radius: lit ? 3 : 0)
            .frame(width: diameter, height: diameter)
            .allowsHitTesting(false).accessibilityHidden(true)
    }
}

struct TactileStepKey: View {
    let index: Int
    let enabled: Bool
    let current: Bool
    let action: () -> Void
    var color: Color {
        switch index / 4 {
        case 0: Color.eightRed
        case 1: Color.eightOrange
        case 2: Color.eightYellow
        default: Color.eightInk
        }
    }
    var body: some View {
        Button(action: action) {
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 3).fill(.black).offset(y: 4)
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(LinearGradient(stops: [.init(color: color.opacity(0.96), location: 0), .init(color: color, location: 0.18), .init(color: color.opacity(0.85), location: 0.24), .init(color: color, location: 0.31), .init(color: color.opacity(0.77), location: 1)], startPoint: .top, endPoint: .bottom))
                    .overlay(alignment: .top) { RoundedRectangle(cornerRadius: 1).fill(.white.opacity(0.34)).frame(height: 1.5).padding(.horizontal, 2).padding(.top, 1) }
                    .overlay(alignment: .bottom) { Rectangle().fill(.black.opacity(0.24)).frame(height: 3) }
                    .overlay(RoundedRectangle(cornerRadius: 2.5).stroke(.black.opacity(0.45), lineWidth: 0.7))
                TinyLED(lit: enabled || current, color: current ? .white : Color(red: 1, green: 0.035, blue: 0.015), diameter: 9).padding(.top, 6)
            }
        }
        .buttonStyle(PhysicalPressStyle())
        .accessibilityLabel("Step \(index + 1)")
        .accessibilityValue(enabled ? "On" : "Off")
        .accessibilityHint("Programs this step for the selected instrument.")
        .accessibilityIdentifier("step-\(index + 1)")
    }
}

struct PhysicalPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .offset(y: configuration.isPressed ? 2 : 0)
            .brightness(configuration.isPressed ? -0.1 : 0)
            .animation(.easeOut(duration: 0.07), value: configuration.isPressed)
    }
}

struct HardwareToggle: View {
    let isOn: Bool
    let label: String
    let action: () -> Void
    var vertical = true
    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 2).fill(.black).frame(width: vertical ? 17 : 35, height: vertical ? 35 : 16)
                    .overlay(RoundedRectangle(cornerRadius: 2).stroke(.white.opacity(0.14), lineWidth: 0.6))
                RoundedRectangle(cornerRadius: 1)
                    .fill(LinearGradient(colors: [Color(white: 0.24), .black, Color(white: 0.14)], startPoint: .top, endPoint: .bottom))
                    .frame(width: vertical ? 14 : 16, height: vertical ? 15 : 12)
                    .overlay {
                        VStack(spacing: 2) { ForEach(0..<3) { _ in Rectangle().fill(.white.opacity(0.15)).frame(height: 0.6) } }.padding(.horizontal, 3)
                    }
                    .offset(x: vertical ? 0 : (isOn ? 8 : -8), y: vertical ? (isOn ? -8 : 8) : 0)
            }.frame(width: 44, height: 44)
        }
        .buttonStyle(PhysicalPressStyle())
        .accessibilityLabel(label)
        .accessibilityValue(isOn ? "Upper voice" : "Lower voice")
        .accessibilityIdentifier(label)
    }
}

struct TransportKey: View {
    let title: String
    var color: Color = Color.eightInk
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            ZStack {
                Rectangle().fill(.black)
                Rectangle().fill(LinearGradient(colors: [Color(white: 0.62), Color(white: 0.20), Color(white: 0.44)], startPoint: .topLeading, endPoint: .bottomTrailing)).padding(3)
                Rectangle().fill(.black).padding(5)
                Rectangle().fill(color.gradient).padding(7)
                Rectangle().stroke(.white.opacity(0.55), lineWidth: 1).padding(9)
                Text(title)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineLimit(title.contains("\n") ? 2 : 1)
                    .minimumScaleFactor(0.75)
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, title.contains("\n") ? 10 : 5)
                    .padding(.vertical, 10)
            }.shadow(color: .black.opacity(0.5), radius: 1, y: 2)
        }
        .buttonStyle(PhysicalPressStyle())
        .accessibilityLabel(title.replacingOccurrences(of: "\n", with: " "))
        .accessibilityIdentifier(title.lowercased().replacingOccurrences(of: "\n", with: "-"))
    }
}
