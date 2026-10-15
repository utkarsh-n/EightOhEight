import SwiftUI

extension Color {
    static let eightInk = Color(red: 0.87, green: 0.86, blue: 0.77)
    static let eightCream = Color(red: 0.88, green: 0.84, blue: 0.63)
    static let eightOrange = Color(red: 0.91, green: 0.40, blue: 0.12)
    static let eightYellow = Color(red: 0.98, green: 0.74, blue: 0.17)
    static let eightRed = Color(red: 0.85, green: 0.20, blue: 0.10)
    static let eightPanel = Color(red: 0.105, green: 0.109, blue: 0.115)
}

struct FasciaTexture: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
                Gradient(colors: [Color(white: 0.18), Color(white: 0.105), Color(white: 0.075)]),
                startPoint: .zero, endPoint: CGPoint(x: size.width * 0.24, y: size.height)))
            for index in 0..<Int(size.height * 2) {
                let y = CGFloat(index) * 0.5
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y + 0.12))
                context.stroke(path, with: .color(.white.opacity(index % 7 == 0 ? 0.023 : 0.007)), lineWidth: 0.4)
            }
            // Deterministic grain keeps the texture quiet and stable during playback.
            for index in 0..<3800 {
                let x = CGFloat((index * 197 + 31) % 12001) / 12001 * size.width
                let y = CGFloat((index * 109 + 17) % 6251) / 6251 * size.height
                context.fill(Path(CGRect(x: x, y: y, width: 0.65, height: 0.65)), with: .color(index % 3 == 0 ? .white.opacity(0.035) : .black.opacity(0.11)))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct PanelScrew: View {
    var body: some View {
        ZStack {
            Circle().fill(.black).shadow(color: .black.opacity(0.9), radius: 2, y: 2)
            Circle().fill(LinearGradient(colors: [Color(white: 0.42), Color(white: 0.08), Color(white: 0.23)], startPoint: .topLeading, endPoint: .bottomTrailing)).padding(1)
            Capsule().fill(Color(white: 0.035)).frame(width: 8, height: 2).rotationEffect(.degrees(-32))
            Capsule().fill(Color(white: 0.025)).frame(width: 2, height: 8).rotationEffect(.degrees(-32))
            Circle().stroke(.white.opacity(0.15), lineWidth: 0.5).padding(2)
        }
        .frame(width: 12, height: 12)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct SideCheek: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(LinearGradient(colors: [Color(white: 0.20), Color(white: 0.045), Color(white: 0.085)], startPoint: .leading, endPoint: .trailing))
            .overlay(alignment: .leading) {
                Rectangle().fill(.white.opacity(0.055)).frame(width: 1.5).padding(.leading, 6)
            }
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: 3).fill(.white.opacity(0.13)).frame(height: 5).padding(.horizontal, 3)
            }
            .shadow(color: .black.opacity(0.9), radius: 4, x: 2, y: 4)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

struct PanelPrint: View {
    let text: String
    var size: CGFloat = 10
    var color: Color = Color.eightInk
    var weight: Font.Weight = .regular
    var body: some View {
        Text(text)
            .font(.system(size: size, weight: weight, design: .rounded))
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .allowsHitTesting(false)
    }
}

struct NamePlate: View {
    let name: String
    var selected = false
    var body: some View {
        Text(name)
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(Color(white: 0.075))
            .lineLimit(1).minimumScaleFactor(0.65)
            .frame(maxWidth: .infinity).frame(height: 23)
            .background(Color.eightCream.gradient, in: RoundedRectangle(cornerRadius: 1.5))
            .overlay(alignment: .bottom) {
                Rectangle().fill(selected ? Color.eightOrange : Color.clear).frame(height: 2)
            }
    }
}
