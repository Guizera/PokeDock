import SwiftUI

/// Subtle, code-drawn ambience behind the Dock controls. No timer runs when motion is disabled.
struct DockThemeEffect: View {
    let theme: DockTheme
    let isEnabled: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let animated = isEnabled && !reduceMotion
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !animated)) { timeline in
            Canvas { context, size in
                let time = animated ? timeline.date.timeIntervalSinceReferenceDate : 0
                switch theme {
                case .meadow: drawLeaves(in: context, size: size, time: time)
                case .electric: drawLightning(in: context, size: size, time: time, animated: animated)
                case .night: drawNight(in: context, size: size, time: time)
                case .ocean: drawWaves(in: context, size: size, time: time)
                case .volcanic: drawEmbers(in: context, size: size, time: time)
                case .psychic: drawOrbs(in: context, size: size, time: time)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawLeaves(in context: GraphicsContext, size: CGSize, time: TimeInterval) {
        for index in 0..<12 {
            let seed = Double(index)
            let progress = fraction(seed * 0.173 + time * (0.035 + seed.truncatingRemainder(dividingBy: 3) * 0.009))
            let x = (1 - progress) * (size.width + 40) - 20
            let y = size.height * fraction(seed * 0.317) + sin(time * 1.4 + seed) * 9
            var leaf = Path()
            leaf.move(to: CGPoint(x: -8, y: 0))
            leaf.addQuadCurve(to: CGPoint(x: 8, y: 0), control: CGPoint(x: 0, y: -7))
            leaf.addQuadCurve(to: CGPoint(x: -8, y: 0), control: CGPoint(x: 0, y: 7))
            let transform = CGAffineTransform(translationX: x, y: y)
                .rotated(by: sin(time + seed) * 0.7)
            context.fill(leaf.applying(transform), with: .color(.white.opacity(0.10 + 0.07 * fraction(seed * 0.29))))
        }
    }

    private func drawLightning(in context: GraphicsContext, size: CGSize, time: TimeInterval, animated: Bool) {
        for index in 0..<3 {
            let phase = fraction(time * 0.82 + Double(index) * 0.34)
            let pulse = max(0, 1 - abs(phase - 0.16) / 0.17)
            let flash = animated ? 0.12 + 0.88 * pulse : (index == 0 ? 0.65 : 0.12)
            let x = size.width * (0.17 + Double(index) * 0.32)
            var bolt = Path()
            bolt.move(to: CGPoint(x: x - 16, y: -8))
            bolt.addLines([
                CGPoint(x: x + 8, y: size.height * 0.28),
                CGPoint(x: x - 3, y: size.height * 0.45),
                CGPoint(x: x + 20, y: size.height * 0.70),
                CGPoint(x: x + 5, y: size.height + 8)
            ])
            context.stroke(bolt, with: .color(.yellow.opacity(0.20 * flash)), lineWidth: 12)
            context.stroke(bolt, with: .color(.white.opacity(0.70 * flash)), lineWidth: 2.5)
        }
    }

    private func drawNight(in context: GraphicsContext, size: CGSize, time: TimeInterval) {
        for index in 0..<4 {
            let seed = Double(index)
            let x = size.width * (0.12 + seed * 0.29) + sin(time * 0.24 + seed * 2) * 22
            let y = size.height * (0.25 + 0.18 * seed.truncatingRemainder(dividingBy: 3))
            let mist = Path(ellipseIn: CGRect(x: x - 96, y: y - 17, width: 192, height: 34))
            context.fill(mist, with: .color(.white.opacity(0.055)))
        }
        for index in 0..<18 {
            let seed = Double(index)
            let x = size.width * fraction(seed * 0.618)
            let y = size.height * fraction(seed * 0.371)
            let twinkle = 0.10 + 0.20 * (0.5 + 0.5 * sin(time * 1.1 + seed * 2.4))
            let star = Path(ellipseIn: CGRect(x: x, y: y, width: 2.5, height: 2.5))
            context.fill(star, with: .color(.white.opacity(twinkle)))
        }
    }

    private func drawWaves(in context: GraphicsContext, size: CGSize, time: TimeInterval) {
        for index in 0..<3 {
            let y = size.height * (0.3 + Double(index) * 0.27)
            var wave = Path()
            wave.move(to: CGPoint(x: 0, y: y))
            for step in 1...30 {
                let x = size.width * Double(step) / 30
                wave.addLine(to: CGPoint(x: x, y: y + sin(x * 0.025 + time * 0.8 + Double(index)) * 7))
            }
            context.stroke(wave, with: .color(.white.opacity(0.12)), lineWidth: 2)
        }
    }

    private func drawEmbers(in context: GraphicsContext, size: CGSize, time: TimeInterval) {
        for index in 0..<17 {
            let seed = Double(index)
            let x = size.width * fraction(seed * 0.618) + sin(time + seed) * 8
            let y = size.height * (1 - fraction(seed * 0.249 + time * 0.08))
            let radius = 2 + 3 * fraction(seed * 0.371)
            let ember = Path(ellipseIn: CGRect(x: x, y: y, width: radius, height: radius))
            context.fill(ember, with: .color(.orange.opacity(0.30 + 0.25 * fraction(seed * 0.157))))
        }
    }

    private func drawOrbs(in context: GraphicsContext, size: CGSize, time: TimeInterval) {
        for index in 0..<9 {
            let seed = Double(index)
            let x = size.width * fraction(seed * 0.618) + sin(time * 0.55 + seed) * 12
            let y = size.height * fraction(seed * 0.317) + cos(time * 0.7 + seed) * 8
            let radius = 5 + 8 * fraction(seed * 0.273)
            let orb = Path(ellipseIn: CGRect(x: x, y: y, width: radius, height: radius))
            context.fill(orb, with: .color(.white.opacity(0.08)))
            context.stroke(orb, with: .color(.pink.opacity(0.18)), lineWidth: 1)
        }
    }

    private func fraction(_ value: Double) -> Double { value - floor(value) }
}
