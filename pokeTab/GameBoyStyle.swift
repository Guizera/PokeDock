import SwiftUI

enum GameBoyPalette {
    static let shell = Color(red: 0.84, green: 0.82, blue: 0.73)
    static let shellShadow = Color(red: 0.58, green: 0.56, blue: 0.50)
    static let bezel = Color(red: 0.24, green: 0.29, blue: 0.31)
    static let dark = Color(red: 0.13, green: 0.24, blue: 0.16)
    static let mid = Color(red: 0.30, green: 0.43, blue: 0.25)
    static let screen = Color(red: 0.68, green: 0.78, blue: 0.48)
    static let light = Color(red: 0.82, green: 0.87, blue: 0.60)
    static let action = Color(red: 0.67, green: 0.18, blue: 0.21)
}

struct GameBoyScreen<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .fill(GameBoyPalette.screen)
                    .overlay {
                        GameBoyScanlines()
                            .opacity(0.08)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(GameBoyPalette.dark, lineWidth: 3)
            }
            .padding(9)
            .background(GameBoyPalette.bezel, in: RoundedRectangle(cornerRadius: 18))
    }
}

struct GameBoySectionTitle: View {
    let title: String
    let symbol: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .black))
            Text(NSLocalizedString(title, comment: "Game Boy section heading").uppercased())
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .tracking(1)
        }
        .foregroundStyle(GameBoyPalette.dark)
    }
}

struct GameBoyActionStyle: ButtonStyle {
    var primary = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .black, design: .monospaced))
            .foregroundStyle(primary ? Color.white : GameBoyPalette.dark)
            .padding(.horizontal, 13)
            .frame(minHeight: 35)
            .background(primary ? GameBoyPalette.action : GameBoyPalette.light, in: RoundedRectangle(cornerRadius: 7))
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(GameBoyPalette.dark, lineWidth: 2)
            }
            .offset(y: configuration.isPressed ? 2 : 0)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct GameBoyScanlines: View {
    var body: some View {
        Canvas { context, size in
            var lines = Path()
            for y in stride(from: CGFloat(0), through: size.height, by: 6) {
                lines.move(to: CGPoint(x: 0, y: y))
                lines.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(lines, with: .color(GameBoyPalette.dark), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}
