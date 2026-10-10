//
//  WelcomeLandingView.swift
//  Track21
//
//  Green feature-ring welcome screen shown before the email/password form.
//  Five glossy 3D shapes orbit centered title + CTAs.
//  Responsive for portrait and landscape (iPhone / iPad).
//  Pure SwiftUI — no image assets.
//

import SwiftUI

struct WelcomeLandingView: View {
    let onLogInOrSignUp: () -> Void
    let onContinueAsGuest: () -> Void

    private let features: [WelcomeFeature] = [
        WelcomeFeature(
            label: "Talk with Buddy",
            color: Color(hex: "1B5E40"),
            highlight: Color(hex: "4CAF7A"),
            kind: .chatBubble,
            angle: -90,
            size: 78
        ),
        WelcomeFeature(
            label: "Log journal",
            color: Color(hex: "3D8B5C"),
            highlight: Color(hex: "7BC99A"),
            kind: .notebook,
            angle: -48,
            size: 74
        ),
        WelcomeFeature(
            label: "Pro insights",
            color: Color(hex: "6B9B3A"),
            highlight: Color(hex: "A8D46A"),
            kind: .risingBars,
            angle: 48,
            size: 72
        ),
        WelcomeFeature(
            label: "Reminders",
            color: Color(hex: "2E7A55"),
            highlight: Color(hex: "5FBF8A"),
            kind: .bell,
            angle: 132,
            size: 70
        ),
        WelcomeFeature(
            label: "Freeze day",
            color: Color(hex: "4A7A5C"),
            highlight: Color(hex: "8FBF9A"),
            kind: .iceStar,
            angle: -132,
            size: 76
        )
    ]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let isLandscape = w > h * 1.05
            let shortSide = min(w, h)
            let longSide = max(w, h)
            let scale = min(1.15, max(0.72, shortSide / 390))

            ZStack {
                WelcomeColors.background.ignoresSafeArea()

                Ellipse()
                    .fill(WelcomeColors.ambient.opacity(isLandscape ? 0.45 : 0.55))
                    .frame(
                        width: (isLandscape ? longSide : shortSide) * 0.72,
                        height: shortSide * 0.55
                    )
                    .blur(radius: 40 * scale)
                    .allowsHitTesting(false)

                featureRing(
                    width: w,
                    height: h,
                    isLandscape: isLandscape,
                    scale: scale
                )

                centerContent(width: w, isLandscape: isLandscape, scale: scale)
                    .padding(.horizontal, isLandscape ? w * 0.22 : 36 * scale)
                    .padding(.vertical, isLandscape ? 8 : 12)
            }
            .frame(width: w, height: h)
        }
        .background(WelcomeColors.background.ignoresSafeArea())
    }

    // MARK: - Center CTAs

    private func centerContent(
        width: CGFloat,
        isLandscape: Bool,
        scale: CGFloat
    ) -> some View {
        let titleSize = isLandscape
            ? min(36, 28 * scale + 4)
            : min(38, 30 * scale + 4)
        let tagSize = isLandscape
            ? min(14, 12 * scale + 1)
            : min(15, 12.5 * scale + 1)
        let buttonMax = isLandscape
            ? min(280, width * 0.42)
            : min(300, width * 0.72)

        return VStack(spacing: isLandscape ? 8 * scale : 10 * scale) {
            Text("Track 21")
                .font(.system(size: titleSize, weight: .bold, design: .rounded))
                .foregroundStyle(WelcomeColors.ink)
                .minimumScaleFactor(0.8)
                .lineLimit(1)

            Text("21-day habits. Finish what you start.")
                .font(.system(size: tagSize, weight: .medium))
                .foregroundStyle(WelcomeColors.ink.opacity(0.72))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.85)
                .lineLimit(2)

            Button(action: onLogInOrSignUp) {
                Text("Log In or Sign Up")
                    .font(.system(size: isLandscape ? 15 : 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: buttonMax)
                    .padding(.vertical, isLandscape ? 12 : 15)
                    .background(WelcomeColors.cta)
                    .clipShape(Capsule())
                    .shadow(color: WelcomeColors.cta.opacity(0.28), radius: 10, y: 4)
            }
            .buttonStyle(.plain)
            .padding(.top, isLandscape ? 2 : 4)
            .accessibilityIdentifier("welcomeLogInOrSignUp")

            Button(action: onContinueAsGuest) {
                Text("Continue as Guest")
                    .font(.system(size: isLandscape ? 13 : 15, weight: .semibold))
                    .foregroundStyle(WelcomeColors.cta)
                    .frame(maxWidth: buttonMax)
                    .padding(.vertical, isLandscape ? 10 : 13)
                    .background(Color.white.opacity(0.92))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(WelcomeColors.cta.opacity(0.55), lineWidth: 1.5)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("welcomeContinueAsGuest")
        }
        .frame(maxWidth: buttonMax + 24)
    }

    // MARK: - Feature ring

    private func featureRing(
        width: CGFloat,
        height: CGFloat,
        isLandscape: Bool,
        scale: CGFloat
    ) -> some View {
        let metrics = ringMetrics(width: width, height: height, isLandscape: isLandscape, scale: scale)

        return ZStack {
            ForEach(features) { feature in
                ringItem(
                    feature,
                    centerX: width / 2,
                    centerY: height / 2,
                    rx: metrics.rx,
                    ry: metrics.ry,
                    blobScale: metrics.blobScale,
                    labelFont: metrics.labelFont,
                    labelOutset: metrics.labelOutset,
                    canvasW: width,
                    canvasH: height,
                    clearX: metrics.clearX,
                    clearY: metrics.clearY,
                    isLandscape: isLandscape
                )
            }
        }
        .frame(width: width, height: height)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private struct RingMetrics {
        let rx: CGFloat
        let ry: CGFloat
        let blobScale: CGFloat
        let labelFont: CGFloat
        let labelOutset: CGFloat
        let clearX: CGFloat
        let clearY: CGFloat
    }

    private func ringMetrics(
        width: CGFloat,
        height: CGFloat,
        isLandscape: Bool,
        scale: CGFloat
    ) -> RingMetrics {
        if isLandscape {
            return RingMetrics(
                rx: width * 0.38,
                ry: height * 0.34,
                blobScale: scale * 0.78,
                labelFont: max(9, 10 * scale),
                labelOutset: 16 * scale,
                clearX: min(160, width * 0.28),
                clearY: min(90, height * 0.28)
            )
        }

        // Portrait primary: push the ring out toward the screen edges so
        // the five shapes frame the CTAs instead of clustering mid-screen.
        // (Earlier pass still capped ry too low → empty top/bottom margins
        // with shapes hugging the buttons.)
        let topPad: CGFloat = 50
        let bottomPad: CGFloat = 36
        let sidePad: CGFloat = 14
        let approxBlob: CGFloat = 52 * scale
        let labelRoom: CGFloat = 18
        let rxRaw = width * 0.5 - sidePad - approxBlob * 0.55
        let ryRaw = height * 0.5 - max(topPad, bottomPad) - approxBlob * 0.55 - labelRoom
        return RingMetrics(
            rx: max(min(rxRaw, width * 0.45), width * 0.36),
            ry: max(min(ryRaw, height * 0.43), height * 0.32),
            blobScale: scale * 0.64,
            labelFont: max(9, 10 * scale),
            labelOutset: 10 * scale,
            clearX: min(158, width * 0.42),
            clearY: min(168, height * 0.26)
        )
    }

    @ViewBuilder
    private func ringItem(
        _ feature: WelcomeFeature,
        centerX: CGFloat,
        centerY: CGFloat,
        rx: CGFloat,
        ry: CGFloat,
        blobScale: CGFloat,
        labelFont: CGFloat,
        labelOutset: CGFloat,
        canvasW: CGFloat,
        canvasH: CGFloat,
        clearX: CGFloat,
        clearY: CGFloat,
        isLandscape: Bool
    ) -> some View {
        let rad = feature.angle * .pi / 180
        let blobSize = feature.size * blobScale
        let placed = blobPosition(
            centerX: centerX,
            centerY: centerY,
            rx: rx,
            ry: ry,
            rad: rad,
            clearX: clearX,
            clearY: clearY
        )
        let label = labelPosition(
            bx: placed.x,
            by: placed.y,
            rad: rad,
            blobSize: blobSize,
            labelOutset: labelOutset,
            centerX: centerX,
            centerY: centerY,
            clearX: clearX,
            clearY: clearY,
            canvasW: canvasW,
            canvasH: canvasH,
            isLandscape: isLandscape
        )

        glossyShape(feature, size: blobSize)
            .position(x: placed.x, y: placed.y)

        Text(feature.label)
            .font(.system(size: labelFont, weight: .semibold))
            .foregroundStyle(WelcomeColors.ink.opacity(0.88))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.95))
                    .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
            )
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .fixedSize()
            .position(x: label.x, y: label.y)
    }

    private func blobPosition(
        centerX: CGFloat,
        centerY: CGFloat,
        rx: CGFloat,
        ry: CGFloat,
        rad: Double,
        clearX: CGFloat,
        clearY: CGFloat
    ) -> CGPoint {
        let rawBX = centerX + cos(rad) * rx
        let rawBY = centerY + sin(rad) * ry
        let dx = rawBX - centerX
        let dy = rawBY - centerY
        guard abs(dx) < clearX && abs(dy) < clearY else {
            return CGPoint(x: rawBX, y: rawBY)
        }
        let push = max(clearX / max(abs(dx), 1), clearY / max(abs(dy), 1))
        return CGPoint(x: centerX + dx * push, y: centerY + dy * push)
    }

    private func labelPosition(
        bx: CGFloat,
        by: CGFloat,
        rad: Double,
        blobSize: CGFloat,
        labelOutset: CGFloat,
        centerX: CGFloat,
        centerY: CGFloat,
        clearX: CGFloat,
        clearY: CGFloat,
        canvasW: CGFloat,
        canvasH: CGFloat,
        isLandscape: Bool
    ) -> CGPoint {
        let outward = blobSize * 0.55 + labelOutset
        let rawLX = bx + cos(rad) * outward
        let rawLY = by + sin(rad) * outward
        let edgePad: CGFloat = isLandscape ? 8 : 6
        let labelHalfW: CGFloat = isLandscape ? 54 : 58
        let labelHalfH: CGFloat = 12
        let topGuard: CGFloat = isLandscape ? 0 : 44
        let bottomGuard: CGFloat = isLandscape ? 0 : 20

        func clamp(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(
                x: min(max(x, edgePad + labelHalfW), canvasW - edgePad - labelHalfW),
                y: min(
                    max(y, edgePad + labelHalfH + topGuard),
                    canvasH - edgePad - labelHalfH - bottomGuard
                )
            )
        }

        let clamped = clamp(rawLX, rawLY)
        if abs(clamped.x - centerX) < clearX * 0.85 && abs(clamped.y - centerY) < clearY * 0.85 {
            let altX = bx + (bx >= centerX ? 1 : -1) * (blobSize * 0.35 + 36)
            let altY = by + (by >= centerY ? 1 : -1) * (blobSize * 0.15 + 10)
            return clamp(altX, altY)
        }
        return clamped
    }

    // MARK: - Glossy 3D shape + eyes

    private func glossyShape(_ feature: WelcomeFeature, size: CGFloat) -> some View {
        let bodyH = size * feature.kind.aspect
        let gradient = LinearGradient(
            colors: [
                feature.highlight,
                feature.color,
                feature.color.opacity(0.85)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        let gloss = LinearGradient(
            colors: [
                Color.white.opacity(0.55),
                Color.white.opacity(0.08),
                Color.clear
            ],
            startPoint: .topLeading,
            endPoint: UnitPoint(x: 0.55, y: 0.55)
        )

        return ZStack {
            filledShape(feature.kind, style: .solid(Color.black.opacity(0.18)))
                .frame(width: size, height: bodyH)
                .blur(radius: size * 0.08)
                .offset(y: size * 0.06)

            filledShape(feature.kind, style: .solidGradient(gradient))
                .frame(width: size, height: bodyH)
                .overlay(
                    filledShape(feature.kind, style: .solidGradient(gloss))
                        .frame(width: size, height: bodyH)
                        .blendMode(.screen)
                        .allowsHitTesting(false)
                )
                .overlay(
                    strokedShape(feature.kind, color: Color.white.opacity(0.35), lineWidth: 1.2)
                        .frame(width: size, height: bodyH)
                )
                .shadow(color: feature.color.opacity(0.35), radius: size * 0.12, y: size * 0.06)

            shapeDetail(feature.kind, size: size)

            HStack(spacing: size * 0.11) {
                Capsule()
                    .fill(Color.white)
                    .frame(width: size * 0.085, height: size * 0.20)
                    .shadow(color: .black.opacity(0.15), radius: 1, y: 0.5)
                Capsule()
                    .fill(Color.white)
                    .frame(width: size * 0.085, height: size * 0.20)
                    .shadow(color: .black.opacity(0.15), radius: 1, y: 0.5)
            }
            .offset(y: -size * 0.02)
        }
        .frame(width: size * 1.15, height: size * 1.15)
    }

    private enum FillStyle {
        case solid(Color)
        case solidGradient(LinearGradient)
    }

    @ViewBuilder
    private func filledShape(_ kind: WelcomeShapeKind, style: FillStyle) -> some View {
        switch kind {
        case .chatBubble:
            switch style {
            case .solid(let c): ChatBubbleShape().fill(c)
            case .solidGradient(let g): ChatBubbleShape().fill(g)
            }
        case .notebook:
            switch style {
            case .solid(let c): NotebookShape().fill(c)
            case .solidGradient(let g): NotebookShape().fill(g)
            }
        case .risingBars:
            switch style {
            case .solid(let c): RisingBarsShape().fill(c)
            case .solidGradient(let g): RisingBarsShape().fill(g)
            }
        case .bell:
            switch style {
            case .solid(let c): BellShape().fill(c)
            case .solidGradient(let g): BellShape().fill(g)
            }
        case .iceStar:
            switch style {
            case .solid(let c): IceStarShape().fill(c)
            case .solidGradient(let g): IceStarShape().fill(g)
            }
        }
    }

    @ViewBuilder
    private func strokedShape(_ kind: WelcomeShapeKind, color: Color, lineWidth: CGFloat) -> some View {
        switch kind {
        case .chatBubble: ChatBubbleShape().stroke(color, lineWidth: lineWidth)
        case .notebook: NotebookShape().stroke(color, lineWidth: lineWidth)
        case .risingBars: RisingBarsShape().stroke(color, lineWidth: lineWidth)
        case .bell: BellShape().stroke(color, lineWidth: lineWidth)
        case .iceStar: IceStarShape().stroke(color, lineWidth: lineWidth)
        }
    }

    @ViewBuilder
    private func shapeDetail(_ kind: WelcomeShapeKind, size: CGFloat) -> some View {
        switch kind {
        case .notebook:
            VStack(spacing: size * 0.08) {
                Capsule().fill(Color.white.opacity(0.55)).frame(width: size * 0.42, height: 2)
                Capsule().fill(Color.white.opacity(0.55)).frame(width: size * 0.42, height: 2)
                Capsule().fill(Color.white.opacity(0.55)).frame(width: size * 0.28, height: 2)
            }
            .offset(x: size * 0.04, y: size * 0.14)
        default:
            EmptyView()
        }
    }
}

// MARK: - Model

private struct WelcomeFeature: Identifiable {
    var id: String { label }
    let label: String
    let color: Color
    let highlight: Color
    let kind: WelcomeShapeKind
    let angle: Double
    let size: CGFloat
}

private enum WelcomeShapeKind {
    case chatBubble, notebook, risingBars, bell, iceStar

    var aspect: CGFloat {
        switch self {
        case .chatBubble: return 0.92
        case .notebook: return 1.08
        case .risingBars: return 0.95
        case .bell: return 1.05
        case .iceStar: return 1.0
        }
    }
}

private enum WelcomeColors {
    static let background = Color(lightHex: "FFFFFF", darkHex: "101814")
    static let ambient = Color(lightHex: "D4F0DC", darkHex: "1A3A28")
    static let ink = Color(lightHex: "0A2F24", darkHex: "E2F5E8")
    static let cta = Color(lightHex: "0A2F24", darkHex: "1B5E40")
}

// MARK: - Meaningful shapes

private struct ChatBubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let bubble = CGRect(x: w * 0.06, y: h * 0.04, width: w * 0.88, height: h * 0.72)
        path.addRoundedRect(in: bubble, cornerSize: CGSize(width: w * 0.22, height: h * 0.22))
        path.move(to: CGPoint(x: w * 0.22, y: h * 0.72))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.12, y: h * 0.96),
            control: CGPoint(x: w * 0.18, y: h * 0.84)
        )
        path.addQuadCurve(
            to: CGPoint(x: w * 0.38, y: h * 0.74),
            control: CGPoint(x: w * 0.26, y: h * 0.88)
        )
        path.closeSubpath()
        return path
    }
}

private struct NotebookShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let page = CGRect(x: w * 0.12, y: h * 0.06, width: w * 0.76, height: h * 0.88)
        path.addRoundedRect(in: page, cornerSize: CGSize(width: w * 0.12, height: h * 0.10))
        path.addRoundedRect(
            in: CGRect(x: w * 0.12, y: h * 0.06, width: w * 0.14, height: h * 0.88),
            cornerSize: CGSize(width: w * 0.06, height: h * 0.06)
        )
        return path
    }
}

private struct RisingBarsShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let gap = w * 0.08
        let barW = (w - gap * 2) / 3
        let heights: [CGFloat] = [0.42, 0.68, 0.92]
        let radii = barW * 0.28

        for (i, frac) in heights.enumerated() {
            let x = CGFloat(i) * (barW + gap)
            let barH = h * frac
            let y = h - barH
            let bar = CGRect(x: x, y: y, width: barW, height: barH)
            path.addRoundedRect(in: bar, cornerSize: CGSize(width: radii, height: radii))
        }
        return path
    }
}

private struct BellShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        path.move(to: CGPoint(x: w * 0.18, y: h * 0.42))
        path.addCurve(
            to: CGPoint(x: w * 0.50, y: h * 0.08),
            control1: CGPoint(x: w * 0.18, y: h * 0.22),
            control2: CGPoint(x: w * 0.30, y: h * 0.08)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.82, y: h * 0.42),
            control1: CGPoint(x: w * 0.70, y: h * 0.08),
            control2: CGPoint(x: w * 0.82, y: h * 0.22)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.92, y: h * 0.72),
            control1: CGPoint(x: w * 0.82, y: h * 0.55),
            control2: CGPoint(x: w * 0.88, y: h * 0.65)
        )
        path.addLine(to: CGPoint(x: w * 0.08, y: h * 0.72))
        path.addCurve(
            to: CGPoint(x: w * 0.18, y: h * 0.42),
            control1: CGPoint(x: w * 0.12, y: h * 0.65),
            control2: CGPoint(x: w * 0.18, y: h * 0.55)
        )
        path.closeSubpath()
        path.addEllipse(in: CGRect(x: w * 0.38, y: h * 0.74, width: w * 0.24, height: h * 0.18))
        return path
    }
}

private struct IceStarShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let cx = w / 2
        let cy = h / 2
        let points = 6
        let outerR = min(w, h) * 0.48
        let innerR = outerR * 0.48

        for i in 0..<(points * 2) {
            let angle = (Double(i) * .pi / Double(points)) - .pi / 2
            let r = i.isMultiple(of: 2) ? outerR : innerR
            let pt = CGPoint(x: cx + CGFloat(cos(angle)) * r, y: cy + CGFloat(sin(angle)) * r)
            if i == 0 {
                path.move(to: pt)
            } else {
                path.addLine(to: pt)
            }
        }
        path.closeSubpath()
        path.addEllipse(in: CGRect(
            x: cx - outerR * 0.28,
            y: cy - outerR * 0.28,
            width: outerR * 0.56,
            height: outerR * 0.56
        ))
        return path
    }
}

#Preview {
    WelcomeLandingView(onLogInOrSignUp: {}, onContinueAsGuest: {})
}
