import SwiftUI

// DESIGN §5 Fill — gel: one solid color rising from the bottom (matching
// the pager's bleed strip exactly, so the bottom reads as one section)
// with a continuously flowing wave surface. Pressing it dents the gel like jelly: the dent
// bounces with a damped spring overshoot and sends ripples along the
// surface; dragging trails dents. Light haptic on touch.
// Reduce Motion → static fill, no touch response.
//
// The gesture is a plain zero-distance drag so page swipes still win once
// the finger moves: the pager takes over, the dent just settles.
public struct GelFill: View {
    var color: Color
    var animated: Bool = true
    var wave: Bool = true
    var waveHeight: CGFloat = 16

    @State private var phase = 0.0
    @State private var ripples: [Ripple] = []
    @State private var hapticTick = 0
    @State private var lastHaptic = Date.distantPast
    @State private var lastTouchAt = Date.distantPast
    @State private var lastTrailX: CGFloat = -1

    private struct Ripple {
        var x: Double // 0...1 across the width
        var depth: Double // dent depth: full at the surface, less when deep
        var t0: Double // phase clock
    }

    public var body: some View {
        GeometryReader { g in
            gelCanvas(size: g.size)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in touch(at: v.location, size: g.size) }
                        .onEnded { _ in lastTrailX = -1 },
                    including: animated ? .all : .none
                )
        }
        .sensoryFeedback(.impact(weight: .light), trigger: hapticTick)
        .accessibilityHidden(true)
        .task(id: animated) {
            guard animated else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.0 / 30))
                phase += 1.0 / 30
                if !ripples.isEmpty {
                    ripples = ripples.filter { phase - $0.t0 < 2.5 }
                }
            }
        }
    }

    private func touch(at p: CGPoint, size: CGSize) {
        guard animated, size.width > 0, size.height > 0 else { return }
        let fx = min(1, max(0, p.x / size.width))
        let fy = min(1, max(0, p.y / size.height))
        let now = Date()
        // A touch after a pause is a new press even if the last drag never
        // ended (e.g. the pager stole it mid-swipe).
        let isNew = now.timeIntervalSince(lastTouchAt) > 1.0
        lastTouchAt = now
        if now.timeIntervalSince(lastHaptic) > 0.5 {
            lastHaptic = now
            hapticTick += 1
        }
        if isNew || abs(fx - lastTrailX) > 0.04 {
            lastTrailX = fx
            // Pressing near the surface dents deeply; pressing deep down
            // barely dents the surface and mostly wobbles it.
            let depth = 34 * (1 - 0.55 * fy)
            ripples = Array((ripples + [Ripple(x: Double(fx), depth: depth, t0: phase)])
                .filter { phase - $0.t0 < 2.5 }.suffix(8))
        }
    }

    private func surfaceY(x: CGFloat, w: CGFloat, t: Double) -> CGFloat {
        var y = wave ? waveHeight * 0.5 : 0
        if animated, wave {
            y += sin(x / w * 4 * .pi + t * 2.4) * waveHeight * 0.28
            y += sin(x / w * 9 * .pi - t * 3.4 + 1.3) * waveHeight * 0.16
        }
        for r in ripples {
            let age = t - r.t0
            guard age >= 0, age < 2.5 else { continue }
            let env = exp(-age * 2.0)
            let dx = x - CGFloat(r.x) * w
            // Jelly dent: damped spring overshoot (dent → bulge → settle).
            let dentW: CGFloat = 46
            y += -r.depth * env * cos(age * 9)
                * exp(-(dx * dx) / (2 * dentW * dentW))
            // Traveling surface ripple running outward from the press.
            let dist = abs(dx)
            y += sin(dist / 55 * 2 * .pi - age * 11) * env * 10 * exp(-dist / 220)
        }
        return max(0, y)
    }

    private func surfacePath(w: CGFloat, t: Double) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: surfaceY(x: 0, w: w, t: t)))
        var x: CGFloat = 4
        while x <= w {
            path.addLine(to: CGPoint(x: x, y: surfaceY(x: x, w: w, t: t)))
            x += 4
        }
        return path
    }

    private func gelCanvas(size: CGSize) -> some View {
        Canvas { ctx, _ in
            let w = size.width, h = size.height
            let t = phase
            guard w > 0, h > 0 else { return }
            var path = surfacePath(w: w, t: t)
            path.addLine(to: CGPoint(x: w, y: h))
            path.addLine(to: CGPoint(x: 0, y: h))
            path.closeSubpath()
            ctx.fill(path, with: .color(color))
            // Wet gloss along the surface.
            ctx.stroke(surfacePath(w: w, t: t),
                       with: .color(.white.opacity(0.45)), lineWidth: 2.5)
        }
    }
}
