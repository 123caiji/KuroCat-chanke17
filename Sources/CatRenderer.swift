import Foundation
import CoreGraphics
import AppKit

enum CatHitZone {
    case none
    case head
    case body
    case permissionPill
}

enum CatRenderer {
    static let catBlack = NSColor(calibratedRed: 0.085, green: 0.085, blue: 0.095, alpha: 1.0)

    static let permissionPillRect = CGRect(x: 92, y: 294, width: 176, height: 22)

    /// Base skeleton per SkinBuild; SkinShape multipliers are applied on top (all exact no-ops at 1).
    private struct Build {
        let headLift: CGFloat
        let cheekHalfW, crownCtrlW, crownBaseY, cheekY, cheekCtrlTopY, neckPinchX, neckCtrlY: CGFloat
        let hipHalfW, waistCtrlW, waistCtrlY, botOuterW, botInnerW, botHalfW: CGFloat
        let earFold, earLen, earInX, earInY, earOutX, earOutY, earTipX, earTipY, earTipSpread: CGFloat
        let tailWidth: CGFloat
        let hindLeftX, hindW, hindRightX, hindLeftY, hindLeftH, hindStaggerY, hindStaggerH: CGFloat
        let idleTopDY, idleTopX, idleBotX, shoulderX, limbStartW, limbEndW: CGFloat
        let sleekEyes: Bool
    }
    private static let standardBuild = Build(
        headLift: 0,
        cheekHalfW: 42.5, crownCtrlW: 26.0, crownBaseY: -30.0, cheekY: 5.0, cheekCtrlTopY: -14.0, neckPinchX: 2.5, neckCtrlY: 24.0,
        hipHalfW: 49.0, waistCtrlW: 51.5, waistCtrlY: -48.0, botOuterW: 47.0, botInnerW: 36.0, botHalfW: 24.0,
        earFold: 0.06, earLen: 32.0, earInX: 9.0, earInY: -16.0, earOutX: 35.0, earOutY: -5.0, earTipX: 24.5, earTipY: -20.0, earTipSpread: 3.8,
        tailWidth: 11.0,
        hindLeftX: -35.0, hindW: 17.0, hindRightX: 18.0, hindLeftY: 3.0, hindLeftH: 11.0, hindStaggerY: 4.5, hindStaggerH: 12.5,
        idleTopDY: 30, idleTopX: 18.0, idleBotX: 16.0, shoulderX: 20.0, limbStartW: 19.0, limbEndW: 13.5,
        sleekEyes: false)
    private static let sleekBuild = Build(
        headLift: -3.0,
        cheekHalfW: 42.5, crownCtrlW: 25.0, crownBaseY: -29.5, cheekY: 6.5, cheekCtrlTopY: -13.0, neckPinchX: 6.5, neckCtrlY: 27.5,
        hipHalfW: 44.5, waistCtrlW: 41.0, waistCtrlY: -50.0, botOuterW: 42.0, botInnerW: 32.0, botHalfW: 22.0,
        earFold: 0.14, earLen: 29.5, earInX: 10.0, earInY: -16.5, earOutX: 35.5, earOutY: -4.5, earTipX: 25.0, earTipY: -18.5, earTipSpread: 4.2,
        tailWidth: 9.5,
        hindLeftX: -31.0, hindW: 15.5, hindRightX: 15.5, hindLeftY: 3.5, hindLeftH: 12.0, hindStaggerY: 4.5, hindStaggerH: 12.5,
        idleTopDY: 31, idleTopX: 16.5, idleBotX: 15.0, shoulderX: 18.5, limbStartW: 17.0, limbEndW: 12.5,
        sleekEyes: true)
    private static func build(_ skin: SkinSpec) -> Build { skin.shape.build == .sleek ? sleekBuild : standardBuild }

    /// Scale v around c by k; returns v untouched when k == 1 so default shapes stay bit-identical.
    private static func around(_ v: CGFloat, _ c: CGFloat, _ k: CGFloat) -> CGFloat { k == 1 ? v : c + (v - c) * k }

    /// Hit test in 360x320 logical canvas coordinates for smart click-through & petting.
    static func hitTest(point p: CGPoint, physics: CatPhysics, showPermissionPill: Bool) -> CatHitZone {
        if showPermissionPill && permissionPillRect.insetBy(dx: -4, dy: -4).contains(p) {
            return .permissionPill
        }

        let skin = CatSettings.shared.activeSkin
        let shape = skin.shape
        let cx = CatPhysics.seatAnchor.x + physics.bodyShiftX.value
        let breath = sin(physics.time * 2.1) * 1.6
        let headLift: CGFloat = build(skin).headLift
        let headCenter = CGPoint(x: cx + physics.bodyTilt.value * 42, y: 124 + headLift + physics.headOffsetY.value + breath)

        // Head hit ellipse (strictly on the cat's head — never overlaps keyboard); follows head size + cheeks.
        let hdx = (p.x - headCenter.x) / (44.0 * shape.headScale * shape.cheekFullness)
        let hdy = (p.y - headCenter.y) / (38.0 * shape.headScale)
        if hdx * hdx + hdy * hdy <= 1.0 {
            return .head
        }

        // Torso + keyboard area hit check (follows body width)
        let bdx = (p.x - cx) / (58.0 * shape.bodyWidth)
        let bdy = (p.y - 196.0) / 56.0
        if bdx * bdx + bdy * bdy <= 1.0 {
            return .body
        }

        // Mini keyboard & mouse area (allows dragging by grabbing keyboard too)
        let kbRect = CGRect(x: 58, y: 232, width: 236, height: 64)
        if kbRect.contains(p) {
            return .body
        }

        return .none
    }

    /// Main 60fps draw routine in flipped 360x320 logical coordinate space.
    static func draw(in ctx: CGContext, physics: CatPhysics, showPermissionPill: Bool,
                     permissionPillText: String = "点击开启全局/游戏键盘监听 🔑") {
        ctx.saveGState()
        ctx.setAllowsAntialiasing(true)
        ctx.setShouldAntialias(true)

        let settings = CatSettings.shared
        let skin = settings.activeSkin
        let breath = sin(physics.time * 2.1) * 1.6
        let seatX = CatPhysics.seatAnchor.x + physics.bodyShiftX.value
        let seatY = CatPhysics.seatAnchor.y

        // 1. Mini White Mouse (left of keyboard)
        drawMouse(in: ctx, physics: physics, theme: settings.keyboardTheme)

        // 2. Mini Angled 65% Mechanical Keyboard + Dynamic Keycap Glow
        drawKeyboard(in: ctx, physics: physics, theme: settings.keyboardTheme, eyeTheme: settings.eyeTheme, showLegends: settings.showKeyLegends)

        // 3. Cat Tail (behind body)
        drawTail(in: ctx, seatX: seatX, seatY: seatY, physics: physics, skin: skin)

        // 4. 3D-Projected Ears (behind crown silhouette so seal-point ears emerge cleanly from the cream skull!)
        let headLift: CGFloat = build(skin).headLift
        let headCenter = CGPoint(
            x: seatX + physics.bodyTilt.value * 36 + physics.headYaw.value * 7.5,
            y: 126 + headLift + physics.headOffsetY.value + physics.headPitch.value * 4.8 + breath * 1.1
        )
        drawEarsLayer(in: ctx, center: headCenter, physics: physics, skin: skin)

        // 5. Unified C1-Continuous Head + Neck + Pear Torso Silhouette (+ regions, colour-point mask, marks)
        drawUnifiedSilhouette(
            in: ctx,
            seatX: seatX,
            seatY: seatY,
            headCenter: headCenter,
            breath: breath,
            physics: physics,
            skin: skin
        )

        // 6. Hind Foot (3rd simultaneous key easter egg!)
        if physics.hindFootActive.value > 0.03 {
            drawHindFoot(in: ctx, seatX: seatX, seatY: seatY, physics: physics, skin: skin)
        }

        // 7. 2.5D Turning Head Features: Luminous Eyes & Whiskers (+ optional nose/mouth)
        drawHeadFeatures(in: ctx, center: headCenter, physics: physics, eyeTheme: settings.eyeTheme, skin: skin)

        // 7b. Skin stickers anchored to head / neck / tail tip
        if !skin.decorations.isEmpty {
            drawDecorations(in: ctx, seatX: seatX, seatY: seatY, head: headCenter, physics: physics, skin: skin)
        }

        // 8. Front Arms / Paws (over torso & keyboard/mouse with crisp separation outlines / colour-point socks!)
        drawFrontPaws(in: ctx, seatX: seatX, seatY: seatY, breath: breath, physics: physics, skin: skin)

        // 8. Floating Mechanical Keycap Badges (keyboard + mouse clicks)
        if !physics.floatingKeycaps.isEmpty {
            drawFloatingKeycaps(in: ctx, physics: physics)
        }

        // 9. Subtle Petting Sparkles / Sleep Z
        drawSparkles(in: ctx, physics: physics, eyeTheme: settings.eyeTheme)

        // 10. Optional non-intrusive Permission Pill if global monitoring not yet granted
        if showPermissionPill {
            drawPermissionPill(in: ctx, text: permissionPillText)
        }

        ctx.restoreGState()
    }

    // MARK: - Mini White Mouse

    private static func drawMouse(in ctx: CGContext, physics: CatPhysics, theme: KeyboardTheme) {
        let center = CGPoint(
            x: CatPhysics.mouseBaseCenter.x + physics.mouseOffset.point.x,
            y: CatPhysics.mouseBaseCenter.y + physics.mouseOffset.point.y
        )
        let pressShift = max(physics.mousePressLeft.value, physics.mousePressRight.value) * 1.6

        ctx.saveGState()
        ctx.translateBy(x: center.x, y: center.y + pressShift)
        ctx.rotate(by: 0.22) // angled naturally for the cat's right paw (facing the cat!)

        // Soft underside shadow
        ctx.saveGState()
        ctx.setFillColor(NSColor(calibratedWhite: 0.0, alpha: 0.24).cgColor)
        ctx.fillEllipse(in: CGRect(x: -13.5, y: -13.5 + 4.0, width: 27, height: 31))
        ctx.restoreGState()

        let bodyRect = CGRect(x: -13.5, y: -16.5, width: 27, height: 33)
        let bodyColor: NSColor
        let borderColor: NSColor
        let wheelColor: NSColor
        switch theme {
        case .classicMilk:
            bodyColor = NSColor(calibratedRed: 0.955, green: 0.950, blue: 0.925, alpha: 1.0)
            borderColor = NSColor(calibratedRed: 0.14, green: 0.14, blue: 0.16, alpha: 1.0)
            wheelColor = NSColor(calibratedRed: 0.96, green: 0.69, blue: 0.16, alpha: 1.0)
        case .midnightHacker:
            bodyColor = NSColor(calibratedRed: 0.20, green: 0.21, blue: 0.24, alpha: 1.0)
            borderColor = NSColor(calibratedRed: 0.08, green: 0.08, blue: 0.10, alpha: 1.0)
            wheelColor = NSColor(calibratedRed: 0.78, green: 0.95, blue: 0.25, alpha: 1.0)
        case .retroCream:
            bodyColor = NSColor(calibratedRed: 0.89, green: 0.87, blue: 0.82, alpha: 1.0)
            borderColor = NSColor(calibratedRed: 0.20, green: 0.19, blue: 0.18, alpha: 1.0)
            wheelColor = NSColor(calibratedRed: 0.88, green: 0.42, blue: 0.24, alpha: 1.0)
        }

        // Mouse body (palm-rest dome toward cat at top, click buttons & scroll wheel away from cat at bottom!)
        ctx.setFillColor(bodyColor.cgColor)
        ctx.fillEllipse(in: bodyRect)

        // Subtle click flash highlight (cat-facing: left button = inner right side, right button = outer left side!)
        if physics.mousePressLeft.value > 0.05 {
            ctx.saveGState()
            ctx.addEllipse(in: bodyRect)
            ctx.clip()
            ctx.setFillColor(NSColor(calibratedRed: 0.79, green: 0.95, blue: 0.25, alpha: 0.38 * physics.mousePressLeft.value).cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: 14, height: 17))
            ctx.restoreGState()
        }
        if physics.mousePressRight.value > 0.05 {
            ctx.saveGState()
            ctx.addEllipse(in: bodyRect)
            ctx.clip()
            ctx.setFillColor(NSColor(calibratedRed: 0.79, green: 0.95, blue: 0.25, alpha: 0.38 * physics.mousePressRight.value).cgColor)
            ctx.fill(CGRect(x: -14, y: 0, width: 14, height: 17))
            ctx.restoreGState()
        }

        // Button split seam pointing forward (bottom, away from cat!)
        ctx.setStrokeColor(borderColor.withAlphaComponent(0.32).cgColor)
        ctx.setLineWidth(1.05)
        ctx.move(to: CGPoint(x: 0, y: 16))
        ctx.addLine(to: CGPoint(x: 0, y: 1.5))
        ctx.strokePath()

        // Signature amber scroll wheel on the front (bottom) half facing away from cat
        let wheelRect = CGRect(x: -1.9, y: 2.5, width: 3.8, height: 8.5)
        let wheelPath = CGPath(roundedRect: wheelRect, cornerWidth: 1.9, cornerHeight: 1.9, transform: nil)
        ctx.setFillColor(wheelColor.cgColor)
        ctx.addPath(wheelPath)
        ctx.fillPath()

        // Outer crisp outline
        ctx.setStrokeColor(borderColor.cgColor)
        ctx.setLineWidth(1.7)
        ctx.strokeEllipse(in: bodyRect)

        ctx.restoreGState()
    }

    // MARK: - Mini Angled 65% Mechanical Keyboard (facing the cat!)

    private static func drawKeyboard(
        in ctx: CGContext,
        physics: CatPhysics,
        theme: KeyboardTheme,
        eyeTheme: EyeColorTheme,
        showLegends: Bool
    ) {
        let tl = KeyboardLayout.screenQuadPoint(su: -0.012, sv: -0.04)
        let tr = KeyboardLayout.screenQuadPoint(su: 1.012, sv: -0.04)
        let bl = KeyboardLayout.screenQuadPoint(su: -0.016, sv: 1.04)
        let br = KeyboardLayout.screenQuadPoint(su: 1.016, sv: 1.04)

        let caseDepth: CGFloat = 4.5

        // Soft ambient drop shadow beneath keyboard
        ctx.saveGState()
        let shadowPath = roundedQuadPath(
            tl: CGPoint(x: tl.x, y: tl.y + caseDepth + 2),
            tr: CGPoint(x: tr.x, y: tr.y + caseDepth + 2),
            br: CGPoint(x: br.x, y: br.y + caseDepth + 3),
            bl: CGPoint(x: bl.x, y: bl.y + caseDepth + 3),
            radius: 6
        )
        ctx.setFillColor(NSColor(calibratedWhite: 0, alpha: 0.22).cgColor)
        ctx.addPath(shadowPath)
        ctx.fillPath()
        ctx.restoreGState()

        // Dark 3D chassis lower lip
        let baseColor: NSColor
        let deckColor: NSColor
        let keyColor: NSColor
        let keyBorderColor: NSColor
        let accentColor: NSColor

        switch theme {
        case .classicMilk:
            baseColor = NSColor(calibratedRed: 0.10, green: 0.10, blue: 0.12, alpha: 1.0)
            deckColor = NSColor(calibratedRed: 0.14, green: 0.14, blue: 0.16, alpha: 1.0)
            keyColor = NSColor(calibratedRed: 0.968, green: 0.964, blue: 0.942, alpha: 1.0)
            keyBorderColor = NSColor(calibratedRed: 0.78, green: 0.77, blue: 0.74, alpha: 0.75)
            accentColor = NSColor(calibratedRed: 0.97, green: 0.70, blue: 0.16, alpha: 1.0)
        case .midnightHacker:
            baseColor = NSColor(calibratedRed: 0.06, green: 0.06, blue: 0.08, alpha: 1.0)
            deckColor = NSColor(calibratedRed: 0.10, green: 0.11, blue: 0.13, alpha: 1.0)
            keyColor = NSColor(calibratedRed: 0.21, green: 0.22, blue: 0.25, alpha: 1.0)
            keyBorderColor = NSColor(calibratedRed: 0.11, green: 0.11, blue: 0.13, alpha: 0.95)
            accentColor = NSColor(calibratedRed: 0.77, green: 0.94, blue: 0.25, alpha: 1.0)
        case .retroCream:
            baseColor = NSColor(calibratedRed: 0.25, green: 0.24, blue: 0.22, alpha: 1.0)
            deckColor = NSColor(calibratedRed: 0.38, green: 0.36, blue: 0.33, alpha: 1.0)
            keyColor = NSColor(calibratedRed: 0.90, green: 0.88, blue: 0.82, alpha: 1.0)
            keyBorderColor = NSColor(calibratedRed: 0.68, green: 0.65, blue: 0.60, alpha: 0.85)
            accentColor = NSColor(calibratedRed: 0.88, green: 0.42, blue: 0.24, alpha: 1.0)
        }

        let lowerChassis = roundedQuadPath(
            tl: CGPoint(x: tl.x, y: tl.y + caseDepth),
            tr: CGPoint(x: tr.x, y: tr.y + caseDepth),
            br: CGPoint(x: br.x, y: br.y + caseDepth),
            bl: CGPoint(x: bl.x, y: bl.y + caseDepth),
            radius: 5.5
        )
        ctx.setFillColor(baseColor.cgColor)
        ctx.addPath(lowerChassis)
        ctx.fillPath()

        let topChassis = roundedQuadPath(tl: tl, tr: tr, br: br, bl: bl, radius: 5.0)
        ctx.setFillColor(deckColor.cgColor)
        ctx.addPath(topChassis)
        ctx.fillPath()

        // Individual keycaps — tight clean mechanical spacing matching the reference video
        let padU: CGFloat = 0.0028
        let padV: CGFloat = 0.014
        let glowBaseColor = eyeTheme.glowColor

        for cap in KeyboardLayout.keycaps {
            let glow = physics.keyGlow[cap.key] ?? 0
            // 180° rotated to face the cat: su = 1 - u, sv = 1 - v
            let su0 = (1.0 - (cap.xUnits + cap.widthUnits)) + padU
            let su1 = (1.0 - cap.xUnits) - padU
            let sv0 = (1.0 - CGFloat(cap.row + 1) / 5.0) + padV
            let sv1 = (1.0 - CGFloat(cap.row) / 5.0) - padV

            let pressDy = glow * 1.9
            let kTL = offsetY(KeyboardLayout.screenQuadPoint(su: su0, sv: sv0), pressDy)
            let kTR = offsetY(KeyboardLayout.screenQuadPoint(su: su1, sv: sv0), pressDy)
            let kBR = offsetY(KeyboardLayout.screenQuadPoint(su: su1, sv: sv1), pressDy)
            let kBL = offsetY(KeyboardLayout.screenQuadPoint(su: su0, sv: sv1), pressDy)

            let kPath = roundedQuadPath(tl: kTL, tr: kTR, br: kBR, bl: kBL, radius: 1.6)

            var fill = cap.isAmberAccent ? accentColor : keyColor
            if glow > 0.02 {
                fill = blendColor(fill, glowBaseColor, t: glow * 0.55)
            }

            ctx.setFillColor(fill.cgColor)
            ctx.addPath(kPath)
            ctx.fillPath()

            ctx.setStrokeColor(keyBorderColor.cgColor)
            ctx.setLineWidth(0.65)
            ctx.addPath(kPath)
            ctx.strokePath()

            if showLegends {
                let isSpace = cap.key == .space
                let legend = isSpace ? "space" : keycapLegend(cap.key)
                if !legend.isEmpty {
                    var cx = (kTL.x + kTR.x + kBR.x + kBL.x) * 0.25
                    var cy = (kTL.y + kTR.y + kBR.y + kBL.y) * 0.25
                    if isSpace {
                        // The spacebar sits right under the cat: its legs hide the middle, and an
                        // unlabeled visible end looked like an odd blank patch beside the cat.
                        // Label the end that stays visible instead.
                        let sp = KeyboardLayout.screenQuadPoint(su: su0 + (su1 - su0) * 0.82, sv: (sv0 + sv1) * 0.5)
                        cx = sp.x
                        cy = sp.y + pressDy
                    }
                    let textColor: NSColor
                    if cap.isAmberAccent || theme != .midnightHacker {
                        textColor = NSColor(calibratedRed: 0.14, green: 0.14, blue: 0.16, alpha: 0.78)
                    } else {
                        textColor = NSColor(calibratedRed: 0.88, green: 0.90, blue: 0.92, alpha: 0.82)
                    }
                    let fontSize: CGFloat = legend.count <= 1 ? 5.2 : 4.2
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: NSFont.systemFont(ofSize: fontSize, weight: .semibold),
                        .foregroundColor: textColor
                    ]
                    let str = NSAttributedString(string: legend, attributes: attrs)
                    let sz = str.size()
                    ctx.saveGState()
                    ctx.translateBy(x: cx, y: cy)
                    // Keyboard faces the cat (180°), so legends read upright from the cat's seat.
                    ctx.rotate(by: .pi + 0.052)
                    NSGraphicsContext.saveGraphicsState()
                    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
                    str.draw(at: CGPoint(x: -sz.width * 0.5, y: -sz.height * 0.5))
                    NSGraphicsContext.restoreGraphicsState()
                    ctx.restoreGState()
                }
            }
        }

        // Signature soft chartreuse backlit glow halos on active keys!
        for (key, glow) in physics.keyGlow where glow > 0.05 {
            let center = KeyboardLayout.canvasPoint(for: key)
            drawRadialGlow(
                in: ctx,
                center: center,
                radius: 17.0 + glow * 6.0,
                color: glowBaseColor.withAlphaComponent(0.36 * glow)
            )
        }
    }

    // MARK: - Skin part mapping helpers

    /// Head-local point -> canvas, on the skin's head surface (dome / plane) or flat skull space.
    private static func headPoint(_ p: CGPoint, skull: Bool, skin: SkinSpec, head: CGPoint, physics: CatPhysics) -> CGPoint {
        let depth: CGFloat = skin.headSurface == .dome
            ? 29.6 * sqrt(max(0, 1 - pow(p.x / 46, 2) - pow(p.y / 40, 2))) : 27.5
        var projected = skull ? p : projectHead3D(x: p.x, y: p.y, z: depth,
                                                  yawRad: physics.headYaw.value * 0.50,
                                                  pitchRad: physics.headPitch.value * 0.36).pt
        let hs = skin.shape.headScale
        projected.x *= hs; projected.y *= hs
        let c = cos(physics.headTilt.value), s = sin(physics.headTilt.value)
        return CGPoint(x: head.x + projected.x*c - projected.y*s,
                       y: head.y + projected.x*s + projected.y*c)
    }
    private static func bodyPoint(_ p: CGPoint, skin: SkinSpec, seatX: CGFloat, seatY: CGFloat, physics: CatPhysics) -> CGPoint {
        let bw = skin.shape.bodyWidth
        let sy = physics.bodySquash.value, sx = 1 + (1 - sy) * 0.55
        let c = cos(physics.bodyTilt.value), s = sin(physics.bodyTilt.value)
        return CGPoint(x: seatX + p.x*bw*sx*c - p.y*sy*s,
                       y: seatY + p.x*bw*sx*s + p.y*sy*c)
    }
    private static func polyline(_ points: [CGPoint], closed: Bool, map: (CGPoint) -> CGPoint) -> CGMutablePath {
        let path = CGMutablePath()
        for (i, point) in points.enumerated() {
            let p = map(point)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        if closed { path.closeSubpath() }
        return path
    }
    /// Strokes get round caps, except tail-space strokes (bands around the tail) which are cut flat.
    private static func drawMark(in ctx: CGContext, _ mark: SkinMark, cap: CGLineCap = .round, map: (CGPoint) -> CGPoint) {
        ctx.saveGState()
        let path = polyline(mark.points, closed: !mark.stroke, map: map)
        let color = mark.color.ns
        if !mark.stroke {
            path.closeSubpath(); ctx.setFillColor(color.cgColor); ctx.addPath(path); ctx.fillPath()
        } else {
            ctx.setStrokeColor(color.cgColor); ctx.setLineWidth(mark.width)
            ctx.setLineCap(cap); ctx.setLineJoin(.round); ctx.addPath(path); ctx.strokePath()
        }
        ctx.restoreGState()
    }
    private static func drawRegion(in ctx: CGContext, _ region: SkinRegion, map: (CGPoint) -> CGPoint) {
        ctx.setFillColor(region.fill.ns.cgColor)
        ctx.addPath(polyline(region.flat, closed: true, map: map))
        ctx.fillPath()
    }

    // MARK: - Tail

    private struct TailCurve {
        let root: CGPoint, c1: CGPoint, c2: CGPoint, tip: CGPoint, thickness: CGFloat
        /// Tail space: x = 0 (root) .. 100 (tip) along the curve, y = offset along the left-hand normal.
        func at(_ p: CGPoint) -> CGPoint {
            let t = max(0, min(1, p.x / 100))
            let u = 1-t
            let q = CGPoint(x: u*u*u*root.x + 3*u*u*t*c1.x + 3*u*t*t*c2.x + t*t*t*tip.x,
                            y: u*u*u*root.y + 3*u*u*t*c1.y + 3*u*t*t*c2.y + t*t*t*tip.y)
            let dx = 3*u*u*(c1.x-root.x)+6*u*t*(c2.x-c1.x)+3*t*t*(tip.x-c2.x)
            let dy = 3*u*u*(c1.y-root.y)+6*u*t*(c2.y-c1.y)+3*t*t*(tip.y-c2.y)
            let length = max(0.001, hypot(dx,dy)), n = p.y * thickness
            return CGPoint(x: q.x + -dy/length*n, y: q.y + dx/length*n)
        }
    }
    private static func tailCurve(seatX: CGFloat, seatY: CGFloat, physics: CatPhysics, skin: SkinSpec) -> TailCurve {
        let p = physics.tailPhase
        let hunt = max(0, min(1, physics.huntIntensity.value))
        let wag1 = sin(p) * (8.0 + hunt * 5.5)
        let wag2 = cos(p * 1.3) * (6.0 + hunt * 4.5)
        // Tail drops lower & swishes tautly when stalking/hunting!
        let huntDrop = hunt * 14.0
        let bw = skin.shape.bodyWidth, tl = skin.shape.tailLength
        let shift: CGFloat = bw == 1 ? 0 : 34 * bw - 34   // tail root stays on the (wider/narrower) hip

        // Signature low sweep out to the right, then playful upward curl at the tip!
        let root = CGPoint(x: seatX + 34 + shift, y: seatY - 6)
        var c1 = CGPoint(x: seatX + 64 + shift, y: seatY + 2 + wag1 * 0.35 + huntDrop * 0.4)
        var c2 = CGPoint(x: seatX + 66 + wag2 * 0.4 + shift, y: seatY - 26 + wag1 * 0.7 + huntDrop)
        var tip = CGPoint(x: seatX + 91 + wag2 * 0.5 + shift, y: seatY - 30 + wag1 * 0.85 + huntDrop)
        c1 = CGPoint(x: around(c1.x, root.x, tl), y: around(c1.y, root.y, tl))
        c2 = CGPoint(x: around(c2.x, root.x, tl), y: around(c2.y, root.y, tl))
        tip = CGPoint(x: around(tip.x, root.x, tl), y: around(tip.y, root.y, tl))
        return TailCurve(root: root, c1: c1, c2: c2, tip: tip, thickness: skin.shape.tailThickness)
    }

    private static func drawTail(in ctx: CGContext, seatX: CGFloat, seatY: CGFloat, physics: CatPhysics, skin: SkinSpec) {
        let curve = tailCurve(seatX: seatX, seatY: seatY, physics: physics, skin: skin)
        let width = build(skin).tailWidth * skin.shape.tailThickness

        ctx.saveGState()
        ctx.setStrokeColor(skin.palette.tail.ns.cgColor)
        ctx.setLineWidth(width)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.move(to: curve.root)
        ctx.addCurve(to: curve.tip, control1: curve.c1, control2: curve.c2)
        let tailLine = ctx.path
        ctx.strokePath()
        if skin.hasPartArt(.tail) || skin.palette.tailTip != nil, let line = tailLine {
            // Everything below lands only on the tail's own pixels.
            ctx.saveGState()
            ctx.addPath(line.copy(strokingWithWidth: width, lineCap: .round, lineJoin: .round, miterLimit: 10))
            ctx.clip()
            let map: (CGPoint) -> CGPoint = { curve.at($0) }
            for region in skin.regions where region.space == .tail { drawRegion(in: ctx, region, map: map) }
            if let tipColor = skin.palette.tailTip {
                // Last 22% of the tail: de Casteljau split at t = 0.78, stroked with the tail width.
                let t: CGFloat = 0.78, u = 1 - t
                func lerp(_ a: CGPoint, _ b: CGPoint) -> CGPoint { CGPoint(x: u*a.x + t*b.x, y: u*a.y + t*b.y) }
                let a = lerp(curve.root, curve.c1), b = lerp(curve.c1, curve.c2), q = lerp(curve.c2, curve.tip)
                let d = lerp(a, b), e = lerp(b, q), s = lerp(d, e)
                ctx.setStrokeColor(tipColor.ns.cgColor)
                ctx.setLineWidth(width + 2)
                ctx.setLineCap(.round)
                ctx.move(to: s)
                ctx.addCurve(to: curve.tip, control1: e, control2: q)
                ctx.strokePath()
            }
            for mark in skin.marks where mark.space == .tail { drawMark(in: ctx, mark, cap: .butt, map: map) }
            ctx.restoreGState()
        }
        ctx.restoreGState()
    }

    // MARK: - Unified C1-Continuous Cat Silhouette (Crown -> Cheeks -> Plush Neck -> Pear Hips)

    private static func drawUnifiedSilhouette(
        in ctx: CGContext,
        seatX: CGFloat,
        seatY: CGFloat,
        headCenter: CGPoint,
        breath: CGFloat,
        physics: CatPhysics,
        skin: SkinSpec
    ) {
        let bd = build(skin)
        let pal = skin.palette
        let yaw = physics.headYaw.value
        let pitch = physics.headPitch.value
        let hTilt = physics.headTilt.value
        let bTilt = physics.bodyTilt.value
        let hs = skin.shape.headScale, bw = skin.shape.bodyWidth

        let cH = cos(hTilt), sH = sin(hTilt)
        func H(_ lx: CGFloat, _ ly: CGFloat) -> CGPoint {
            let x = lx * hs, y = ly * hs
            return CGPoint(
                x: headCenter.x + x * cH - y * sH,
                y: headCenter.y + x * sH + y * cH
            )
        }

        let cB = cos(bTilt), sB = sin(bTilt)
        let sy = physics.bodySquash.value
        let sx = 1.0 + (1.0 - sy) * 0.55
        func B(_ lx: CGFloat, _ ly: CGFloat) -> CGPoint {
            let rx = lx * bw * sx
            let ry = ly * sy
            return CGPoint(
                x: seatX + rx * cB - ry * sB,
                y: seatY + rx * sB + ry * cB
            )
        }

        let cheekShift = yaw * 3.0
        let crownDrop = pitch * 2.0
        let cheekHalfW: CGFloat = bd.cheekHalfW * skin.shape.cheekFullness
        let crownCtrlW: CGFloat = bd.crownCtrlW
        let crownBaseY: CGFloat = bd.crownBaseY
        let cheekY: CGFloat = bd.cheekY
        let neckPinchX: CGFloat = bd.neckPinchX
        let neckCtrlY: CGFloat = bd.neckCtrlY
        let hipHalfW: CGFloat = bd.hipHalfW
        let waistCtrlW: CGFloat = bd.waistCtrlW
        let waistCtrlY: CGFloat = bd.waistCtrlY
        let botOuterW: CGFloat = bd.botOuterW
        let botInnerW: CGFloat = bd.botInnerW
        let botHalfW: CGFloat = bd.botHalfW
        let leftCheekX: CGFloat = -cheekHalfW + cheekShift * 0.4
        let rightCheekX: CGFloat = cheekHalfW + cheekShift * 0.4

        // ONE single tangent-continuous closed cubic Bezier path — mathematically impossible to form any ledge or protrusion!
        let crown  = H(cheekShift * 0.2, crownBaseY + crownDrop)
        let rCheek = H(rightCheekX, cheekY)
        let rHip   = B(hipHalfW, -14)
        let rBot   = B(botHalfW, 12)
        let lBot   = B(-botHalfW, 12)
        let lHip   = B(-hipHalfW, -14)
        let lCheek = H(leftCheekX, cheekY)

        let cheekCtrlTopY: CGFloat = bd.cheekCtrlTopY
        let path = CGMutablePath()
        path.move(to: crown)
        path.addCurve(to: rCheek, control1: H(crownCtrlW + cheekShift * 0.3, crownBaseY + crownDrop), control2: H(rightCheekX + 1.5, cheekCtrlTopY))
        path.addCurve(to: rHip,   control1: H(rightCheekX - neckPinchX, neckCtrlY), control2: B(waistCtrlW, waistCtrlY + breath * 0.5))
        path.addCurve(to: rBot,   control1: B(botOuterW, 5), control2: B(botInnerW, 12))
        path.addLine(to: lBot)
        path.addCurve(to: lHip,   control1: B(-botInnerW, 12), control2: B(-botOuterW, 5))
        path.addCurve(to: lCheek, control1: B(-waistCtrlW, waistCtrlY + breath * 0.5), control2: H(leftCheekX + neckPinchX, neckCtrlY))
        path.addCurve(to: crown,  control1: H(leftCheekX - 1.5, cheekCtrlTopY), control2: H(-crownCtrlW + cheekShift * 0.3, crownBaseY + crownDrop))
        path.closeSubpath()

        let partSpaces: [SkinSpace] = [.head, .skull, .body]
        let hasRegions = skin.regions.contains { partSpaces.contains($0.space) }
        let hasMarks = skin.marks.contains { partSpaces.contains($0.space) }
        let headMap: (CGPoint) -> CGPoint = { CatRenderer.headPoint($0, skull: false, skin: skin, head: headCenter, physics: physics) }
        let skullMap: (CGPoint) -> CGPoint = { CatRenderer.headPoint($0, skull: true, skin: skin, head: headCenter, physics: physics) }
        let bodyMap: (CGPoint) -> CGPoint = { CatRenderer.bodyPoint($0, skin: skin, seatX: seatX, seatY: seatY, physics: physics) }

        ctx.saveGState()
        if pal.bodyShade == nil {
            ctx.setFillColor(pal.body.ns.cgColor)
            ctx.addPath(path)
            ctx.fillPath()
        }
        if pal.bodyShade != nil || skin.colorpoint || hasRegions || hasMarks {
            ctx.saveGState(); ctx.addPath(path); ctx.clip()
            let cs = CGColorSpaceCreateDeviceRGB()

            if let shade = pal.bodyShade {
                // Warm oat-milk cream gradient + soft toasted back shading
                let bodyColors = [pal.body.ns.cgColor, shade.ns.cgColor] as CFArray
                if let grad = CGGradient(colorsSpace: cs, colors: bodyColors, locations: [0.15, 1.0]) {
                    ctx.drawLinearGradient(
                        grad,
                        start: CGPoint(x: seatX, y: headCenter.y - 34),
                        end: CGPoint(x: seatX, y: seatY + 18),
                        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
                    )
                }
            }

            // Curve regions: head/skull above the jaw line, body below it.
            for region in skin.regions where partSpaces.contains(region.space) {
                ctx.saveGState()
                let side = SkinSpec.jawSide(head: region.space != .body, cheekFullness: skin.shape.cheekFullness)
                ctx.addPath(polyline(side, closed: true, map: headMap))
                ctx.clip()
                drawRegion(in: ctx, region, map: region.space == .body ? bodyMap : (region.space == .skull ? skullMap : headMap))
                ctx.restoreGState()
            }

            if let point = pal.points {
                let mid = pal.pointsMid ?? point
                let yawRad = yaw * 0.50
                let pitchRad = pitch * 0.36
                ctx.saveGState()
                ctx.translateBy(x: headCenter.x, y: headCenter.y)
                ctx.rotate(by: hTilt)
                if hs != 1 { ctx.scaleBy(x: hs, y: hs) }

                // 2.5D Rotating Seal-Point "挖煤" Face Mask (layered soft mocha halo + velvety seal-brown muzzle!)
                let maskCenter = projectHead3D(x: 0, y: 3.0, z: 27.0, yawRad: yawRad, pitchRad: pitchRad).pt
                let maskScaleX = max(0.76, cos(yawRad * 0.7))
                let maskScaleY = max(0.82, cos(pitchRad * 0.7))

                // Layer 1: Soft wide eye-and-cheek mocha mask halo (startRadius: 0 so there is NEVER a center hole!)
                ctx.saveGState()
                ctx.translateBy(x: maskCenter.x, y: maskCenter.y)
                ctx.scaleBy(x: maskScaleX * 1.24, y: maskScaleY * 0.88)
                let maskColors = [
                    point.ns.cgColor,
                    point.withAlpha(0.92).cgColor,
                    mid.withAlpha(0.62).cgColor,
                    mid.withAlpha(0.0).cgColor
                ] as CFArray
                if let maskGrad = CGGradient(colorsSpace: cs, colors: maskColors, locations: [0.0, 0.42, 0.74, 1.0]) {
                    ctx.drawRadialGradient(
                        maskGrad,
                        startCenter: .zero, startRadius: 0,
                        endCenter: .zero, endRadius: 31.5,
                        options: [.drawsBeforeStartLocation]
                    )
                }
                ctx.restoreGState()

                // Layer 2: Soft warm cocoa muzzle depth below eyes
                let muzzleCenter = projectHead3D(x: 0, y: 7.5, z: 28.0, yawRad: yawRad, pitchRad: pitchRad).pt
                ctx.saveGState()
                ctx.translateBy(x: muzzleCenter.x, y: muzzleCenter.y)
                ctx.scaleBy(x: maskScaleX * 1.04, y: maskScaleY * 0.76)
                let muzzleColors = [
                    point.ns.cgColor,
                    point.withAlpha(0.85).cgColor,
                    point.withAlpha(0.0).cgColor
                ] as CFArray
                if let muzGrad = CGGradient(colorsSpace: cs, colors: muzzleColors, locations: [0.0, 0.50, 1.0]) {
                    ctx.drawRadialGradient(
                        muzGrad,
                        startCenter: .zero, startRadius: 0,
                        endCenter: .zero, endRadius: 19.5,
                        options: [.drawsBeforeStartLocation]
                    )
                }
                ctx.restoreGState()
                ctx.restoreGState()
            }

            for mark in skin.marks {
                switch mark.space {
                case .body: drawMark(in: ctx, mark, map: bodyMap)
                case .skull: drawMark(in: ctx, mark, map: skullMap)
                case .head: drawMark(in: ctx, mark, map: headMap)
                default: break
                }
            }
            ctx.restoreGState()
        }
        ctx.restoreGState()

        // Ultra-soft plush rim (the Siamese cream body; never a harsh dark outline)
        if let outline = pal.outline {
            ctx.saveGState()
            ctx.setStrokeColor(outline.ns.cgColor)
            ctx.setLineWidth(1.0)
            ctx.addPath(path)
            ctx.strokePath()
            ctx.restoreGState()
        }

        // Tucked hind paws peeking softly along bottom edge
        ctx.saveGState()
        ctx.translateBy(x: seatX, y: seatY)
        ctx.rotate(by: bTilt)
        ctx.scaleBy(x: sx, y: sy)
        ctx.setFillColor(pal.paws.ns.cgColor)

        let stagger = skin.shape.pawStagger
        let hindW: CGFloat = bd.hindW
        let leftHindX: CGFloat = bw == 1 ? bd.hindLeftX : (bd.hindLeftX + hindW * 0.5) * bw - hindW * 0.5
        let rightHindX: CGFloat = bw == 1 ? bd.hindRightX : (bd.hindRightX + hindW * 0.5) * bw - hindW * 0.5
        let leftHindY: CGFloat = bd.hindLeftY
        let leftHindH: CGFloat = bd.hindLeftH
        let rightHindY: CGFloat = bd.hindLeftY + (bd.hindStaggerY - bd.hindLeftY) * stagger
        let rightHindH: CGFloat = bd.hindLeftH + (bd.hindStaggerH - bd.hindLeftH) * stagger
        let rightTucked = physics.hindFootActive.value < 0.35

        ctx.fillEllipse(in: CGRect(x: leftHindX, y: leftHindY, width: hindW, height: leftHindH))
        if rightTucked {
            ctx.fillEllipse(in: CGRect(x: rightHindX, y: rightHindY, width: hindW, height: rightHindH))
        }

        // Subtle bottom rim highlights on tucked haunches
        let rimColor = skin.colorpoint ? pal.body.withAlpha(0.55) : pal.crease.withAlpha(0.58)
        ctx.setStrokeColor(rimColor.cgColor)
        ctx.setLineWidth(1.3)
        ctx.setLineCap(.round)
        ctx.addArc(center: CGPoint(x: leftHindX + hindW * 0.5, y: leftHindY + leftHindH * 0.5), radius: 7.5, startAngle: 0.25, endAngle: .pi - 0.25, clockwise: false)
        ctx.strokePath()
        if rightTucked {
            ctx.addArc(center: CGPoint(x: rightHindX + hindW * 0.5, y: rightHindY + rightHindH * 0.5), radius: 7.5, startAngle: 0.25, endAngle: .pi - 0.25, clockwise: false)
            ctx.strokePath()
        }
        if let pads = pal.pawPads {
            ctx.setFillColor(pads.ns.cgColor)
            for side in 0..<(rightTucked ? 2 : 1) {
                let cx = (side == 1 ? rightHindX : leftHindX) + hindW * 0.5
                let cy = side == 1 ? rightHindY + rightHindH * 0.5 : leftHindY + leftHindH * 0.5
                ctx.fillEllipse(in: CGRect(x: cx - 2.7, y: cy + 1.6 - 1.9, width: 5.4, height: 3.8))
                for tx: CGFloat in [-3.4, 0, 3.4] {
                    let ty = cy - 1.7 - (tx == 0 ? 0.8 : 0)
                    ctx.fillEllipse(in: CGRect(x: cx + tx - 1.25, y: ty - 1.1, width: 2.5, height: 2.2))
                }
            }
        }
        ctx.restoreGState()
    }

    // MARK: - 3rd Key Hind Foot Easter Egg

    private static func drawHindFoot(in ctx: CGContext, seatX: CGFloat, seatY: CGFloat, physics: CatPhysics, skin: SkinSpec) {
        let hip = CGPoint(x: seatX + 26 * skin.shape.bodyWidth, y: seatY + 2)
        let target = physics.hindFoot.point
        let mid = CGPoint(
            x: (hip.x + target.x) * 0.5 + 10,
            y: (hip.y + target.y) * 0.5 - 8
        )

        drawLimb(
            in: ctx,
            start: hip,
            control: mid,
            end: target,
            startWidth: 15.0,
            endWidth: 12.0,
            outlineOnLeftSide: true,
            outlineAlpha: 0.85 * physics.hindFootActive.value,
            skin: skin
        )
    }

    // MARK: - 2.5D Spherical Head Projection Helper

    /// Projects a 3D point on the cat's head ellipsoid rotated by (yawRad, pitchRad)
    /// into 2D head-local coordinates — creating true Live2D-style 2.5D head turning!
    private static func projectHead3D(
        x: CGFloat, y: CGFloat, z: CGFloat,
        yawRad: CGFloat, pitchRad: CGFloat
    ) -> (pt: CGPoint, z: CGFloat) {
        // 1. Yaw around Y axis (positive yaw = turning right toward viewer's right)
        let cy = cos(yawRad)
        let sy = sin(yawRad)
        let x1 = x * cy + z * sy
        let z1 = -x * sy + z * cy

        // 2. Pitch around X axis (positive pitch = nodding down)
        let cp = cos(pitchRad)
        let sp = sin(pitchRad)
        let y2 = y * cp + z1 * sp
        let z2 = -y * sp + z1 * cp

        return (CGPoint(x: x1, y: y2), z2)
    }

    // MARK: - 2.5D Ears Layer (drawn behind unified silhouette so seal-point ears emerge organically!)

    private static func drawEarsLayer(
        in ctx: CGContext,
        center: CGPoint,
        physics: CatPhysics,
        skin: SkinSpec
    ) {
        ctx.saveGState()
        ctx.translateBy(x: center.x, y: center.y)
        ctx.rotate(by: physics.headTilt.value)
        if skin.shape.headScale != 1 { ctx.scaleBy(x: skin.shape.headScale, y: skin.shape.headScale) }

        let yawRad = physics.headYaw.value * 0.50
        let pitchRad = physics.headPitch.value * 0.36
        let fold = physics.earFold.value
        let twitch = physics.earTwitch.value * 0.045

        drawEar3D(in: ctx, isLeft: true, yawRad: yawRad, pitchRad: pitchRad, fold: fold, twitch: twitch, skin: skin)
        drawEar3D(in: ctx, isLeft: false, yawRad: yawRad, pitchRad: pitchRad, fold: fold, twitch: -twitch, skin: skin)

        ctx.restoreGState()
    }

    // MARK: - 2.5D Head Features (Luminous Eyes & Whiskers)

    private static func drawHeadFeatures(
        in ctx: CGContext,
        center: CGPoint,
        physics: CatPhysics,
        eyeTheme: EyeColorTheme,
        skin: SkinSpec
    ) {
        ctx.saveGState()
        ctx.translateBy(x: center.x, y: center.y)
        ctx.rotate(by: physics.headTilt.value)
        if skin.shape.headScale != 1 { ctx.scaleBy(x: skin.shape.headScale, y: skin.shape.headScale) }

        let yaw = physics.headYaw.value      // -1 (left) .. +1 (right)
        let pitch = physics.headPitch.value  // -1 (up)   .. +1 (down)
        let yawRad = yaw * 0.50              // ~±28.5° authentic head turn
        let pitchRad = pitch * 0.36          // ~±20.5° authentic head nod

        // 1. 3D-Projected Eyes with authentic spherical foreshortening & parallax!
        drawEye3D(in: ctx, isLeft: true, yawRad: yawRad, pitchRad: pitchRad, physics: physics, eyeTheme: eyeTheme, skin: skin)
        drawEye3D(in: ctx, isLeft: false, yawRad: yawRad, pitchRad: pitchRad, physics: physics, eyeTheme: eyeTheme, skin: skin)

        // 1b. Optional little kitty nose + delicate `:3` mouth hint (小豆泥 charm on the Siamese!)
        if skin.palette.nose != nil || skin.palette.mouth != nil {
            ctx.saveGState()
            if let noseColor = skin.palette.nose {
                let nose = projectHead3D(x: 0, y: 8.2, z: 29.0, yawRad: yawRad, pitchRad: pitchRad).pt
                // Tiny warm dark-rose-espresso triangle nose
                let nPath = CGMutablePath()
                nPath.move(to: CGPoint(x: nose.x - 2.3, y: nose.y - 1.1))
                nPath.addQuadCurve(to: CGPoint(x: nose.x + 2.3, y: nose.y - 1.1), control: CGPoint(x: nose.x, y: nose.y - 1.6))
                nPath.addQuadCurve(to: CGPoint(x: nose.x, y: nose.y + 1.5), control: CGPoint(x: nose.x + 1.8, y: nose.y + 0.6))
                nPath.addQuadCurve(to: CGPoint(x: nose.x - 2.3, y: nose.y - 1.1), control: CGPoint(x: nose.x - 1.8, y: nose.y + 0.6))
                nPath.closeSubpath()
                ctx.setFillColor(noseColor.ns.cgColor)
                ctx.addPath(nPath)
                ctx.fillPath()
            }
            if let mouthColor = skin.palette.mouth {
                let mouthL = projectHead3D(x: -4.2, y: 12.2, z: 28.4, yawRad: yawRad, pitchRad: pitchRad).pt
                let mouthM = projectHead3D(x: 0, y: 11.2, z: 28.8, yawRad: yawRad, pitchRad: pitchRad).pt
                let mouthR = projectHead3D(x: 4.2, y: 12.2, z: 28.4, yawRad: yawRad, pitchRad: pitchRad).pt
                // Delicate light-mocha `ω` kitty mouth
                ctx.setStrokeColor(mouthColor.ns.cgColor)
                ctx.setLineWidth(1.05)
                ctx.setLineCap(.round)
                ctx.move(to: mouthL)
                ctx.addQuadCurve(to: mouthM, control: CGPoint(x: (mouthL.x + mouthM.x) * 0.5, y: mouthL.y + 1.6))
                ctx.addQuadCurve(to: mouthR, control: CGPoint(x: (mouthM.x + mouthR.x) * 0.5, y: mouthR.y + 1.6))
                ctx.strokePath()
            }
            ctx.restoreGState()
        }

        // 2. 3D-Projected Whiskers (outer-side whiskers poke out past silhouette when turning!)
        drawWhiskers3D(in: ctx, yawRad: yawRad, pitchRad: pitchRad, physics: physics, skin: skin)

        ctx.restoreGState()
    }

    private static func drawEar3D(
        in ctx: CGContext,
        isLeft: Bool,
        yawRad: CGFloat,
        pitchRad: CGFloat,
        fold: CGFloat,
        twitch: CGFloat,
        skin: SkinSpec
    ) {
        let bd = build(skin)
        let sign: CGFloat = isLeft ? -1.0 : 1.0
        let foldAngle = sign * (bd.earFold + fold * 0.34) + twitch
        let earLen: CGFloat = bd.earLen

        let tipDx = sin(foldAngle) * earLen
        let tipDy = -cos(foldAngle) * earLen

        // Bases anchored comfortably inside the upper skull contour so they merge seamlessly at every yaw/pitch!
        var innerBase3D = projectHead3D(x: sign * bd.earInX, y: bd.earInY, z: 0.0, yawRad: yawRad, pitchRad: pitchRad).pt
        var outerBase3D = projectHead3D(x: sign * bd.earOutX, y: bd.earOutY, z: -2.0, yawRad: yawRad, pitchRad: pitchRad).pt
        var tip3D       = projectHead3D(x: sign * bd.earTipX + tipDx, y: bd.earTipY + tipDy, z: -3.0, yawRad: yawRad, pitchRad: pitchRad).pt
        let es = skin.shape.earSize
        if es != 1 { // grow / shrink around the middle of the ear base
            let m = CGPoint(x: (innerBase3D.x + outerBase3D.x) * 0.5, y: (innerBase3D.y + outerBase3D.y) * 0.5)
            innerBase3D = CGPoint(x: around(innerBase3D.x, m.x, es), y: around(innerBase3D.y, m.y, es))
            outerBase3D = CGPoint(x: around(outerBase3D.x, m.x, es), y: around(outerBase3D.y, m.y, es))
            tip3D = CGPoint(x: around(tip3D.x, m.x, es), y: around(tip3D.y, m.y, es))
        }

        // Soft plush rounded-tip feline ear
        let ep = skin.shape.earPointiness
        let tipSpread: CGFloat = bd.earTipSpread / ep
        let tipLeft  = CGPoint(x: tip3D.x - sign * tipSpread, y: tip3D.y + 2.8)
        let tipRight = CGPoint(x: tip3D.x + sign * tipSpread, y: tip3D.y + 3.2)

        let ear = CGMutablePath()
        ear.move(to: innerBase3D)
        ear.addQuadCurve(
            to: tipLeft,
            control: CGPoint(x: (innerBase3D.x + tipLeft.x) * 0.5 - sign * 1.5, y: (innerBase3D.y + tipLeft.y) * 0.5 - 2.0)
        )
        ear.addQuadCurve(to: tipRight, control: CGPoint(x: tip3D.x, y: tip3D.y - 2.2 * ep))
        ear.addQuadCurve(
            to: outerBase3D,
            control: CGPoint(x: (outerBase3D.x + tipRight.x) * 0.5 + sign * 2.5, y: (outerBase3D.y + tipRight.y) * 0.5 - 2.0)
        )
        ear.closeSubpath()

        ctx.saveGState()
        ctx.setFillColor(skin.palette.earOuter.ns.cgColor)
        ctx.addPath(ear)
        ctx.fillPath()

        // Optional inner ear hollow (warm dusty cocoa on the Siamese)
        if let innerColor = skin.palette.earInner {
            let inI = CGPoint(x: innerBase3D.x + (tip3D.x - innerBase3D.x) * 0.24 + sign * 3.0,
                              y: innerBase3D.y + (tip3D.y - innerBase3D.y) * 0.16)
            let outI = CGPoint(x: outerBase3D.x + (tip3D.x - outerBase3D.x) * 0.20 - sign * 3.8,
                               y: outerBase3D.y + (tip3D.y - outerBase3D.y) * 0.18)
            let tipI = CGPoint(x: (innerBase3D.x + outerBase3D.x) * 0.16 + tip3D.x * 0.68,
                               y: (innerBase3D.y + outerBase3D.y) * 0.14 + tip3D.y * 0.72 + 2.5)
            let inner = CGMutablePath()
            inner.move(to: inI)
            inner.addQuadCurve(to: tipI, control: CGPoint(x: (inI.x + tipI.x) * 0.5 - sign * 0.8, y: (inI.y + tipI.y) * 0.5))
            inner.addQuadCurve(to: outI, control: CGPoint(x: (outI.x + tipI.x) * 0.5 + sign * 1.2, y: (outI.y + tipI.y) * 0.5))
            inner.closeSubpath()
            ctx.setFillColor(innerColor.ns.cgColor)
            ctx.addPath(inner)
            ctx.fillPath()
        }

        let space: SkinSpace = isLeft ? .leftEar : .rightEar
        if skin.hasPartArt(space) {
            // Ear space: (-50,0) inner base, (50,0) outer base, (0,-100) tip; mirrored per ear.
            let m = CGPoint(x: (innerBase3D.x + outerBase3D.x) * 0.5, y: (innerBase3D.y + outerBase3D.y) * 0.5)
            let inB = innerBase3D, outB = outerBase3D, tipP = tip3D
            let map: (CGPoint) -> CGPoint = { p in
                let u = p.x / 100, v = -p.y / 100
                return CGPoint(x: m.x + u * (outB.x - inB.x) + v * (tipP.x - m.x), y: m.y + u * (outB.y - inB.y) + v * (tipP.y - m.y))
            }
            ctx.saveGState()
            ctx.addPath(ear)
            ctx.clip()
            for region in skin.regions where region.space == space { drawRegion(in: ctx, region, map: map) }
            for mark in skin.marks where mark.space == space { drawMark(in: ctx, mark, map: map) }
            ctx.restoreGState()
        }
        ctx.restoreGState()
    }

    private static func drawEye3D(
        in ctx: CGContext,
        isLeft: Bool,
        yawRad: CGFloat,
        pitchRad: CGFloat,
        physics: CatPhysics,
        eyeTheme: EyeColorTheme,
        skin: SkinSpec
    ) {
        let sign: CGFloat = isLeft ? -1.0 : 1.0
        let customIris = skin.palette.iris   // a skin's iris overrides the eye-colour menu
        let eyeColor = customIris?.ns ?? eyeTheme.primaryColor
        let siameseBlue = customIris == nil && eyeTheme == .siameseBlue

        // Eye sits on the front surface of the 3D head sphere at (±17.5, -2.0, +28.0)
        let proj = projectHead3D(x: sign * 17.2, y: -2.0, z: 27.5, yawRad: yawRad, pitchRad: pitchRad)

        // Authentic spherical foreshortening: the eye turning away toward the edge narrows horizontally!
        let eyeNormalAngle = yawRad + sign * 0.34
        let foreshortenX = max(0.64, min(1.06, cos(eyeNormalAngle) / cos(0.34)))
        let foreshortenY = max(0.78, min(1.03, cos(pitchRad * 0.85)))

        ctx.saveGState()
        ctx.translateBy(x: proj.pt.x, y: proj.pt.y)
        ctx.scaleBy(x: foreshortenX, y: foreshortenY)

        // Mode 1: Happy closed glowing lime-green curved line eyes (petting head!)
        if physics.isHappyClosedEyes {
            ctx.setStrokeColor(eyeColor.cgColor)
            ctx.setLineWidth(2.6)
            ctx.setLineCap(.round)
            ctx.move(to: CGPoint(x: -11.5, y: 1.0))
            ctx.addQuadCurve(
                to: CGPoint(x: 11.5, y: 1.0),
                control: CGPoint(x: sign * 1.5, y: 3.4)
            )
            ctx.strokePath()
            ctx.restoreGState()
            return
        }

        // Mode 2: Blissful half-squint glowing lime slits (petting back/body!)
        if physics.isBlissfulSquint {
            ctx.setFillColor(eyeColor.cgColor)
            let slit = CGMutablePath()
            slit.move(to: CGPoint(x: -11.5, y: -0.5))
            slit.addQuadCurve(to: CGPoint(x: 11.5, y: -0.5), control: CGPoint(x: 0, y: 0.6))
            slit.addQuadCurve(to: CGPoint(x: -11.5, y: -0.5), control: CGPoint(x: 0, y: 4.8))
            slit.closeSubpath()
            ctx.addPath(slit)
            ctx.fillPath()
            ctx.restoreGState()
            return
        }

        let hunt = max(0, min(1, physics.huntIntensity.value))

        // Subtle feline eye angle (straightens slightly when wide-eyed hunting!)
        ctx.rotate(by: sign * (0.06 * (1.0 - hunt * 0.6)))

        // Eyes grow rounder & slightly larger in full hunting focus!
        let isSiameseEye = build(skin).sleekEyes && siameseBlue
        let rx: CGFloat = (isSiameseEye ? 11.4 + hunt * 1.3 : 12.0 + hunt * 1.1)
        let ry: CGFloat = (isSiameseEye ? 9.8 + hunt * 2.0 : 10.8 + hunt * 1.8)
        let eyeRect = CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2)

        // Clip to the visible opening before painting any iris/pupil pixels.
        // Painting a lid over an antialiased oval leaves a colored fringe.
        ctx.saveGState()
        ctx.addEllipse(in: eyeRect)
        ctx.clip()

        let closure = max(0, min(1, physics.effectiveEyeClosure))
        if closure >= 1 {
            ctx.restoreGState()
            ctx.restoreGState()
            return
        }
        if closure > 0 {
            ctx.clip(to: CGRect(x: -rx - 2, y: -ry + 2 * ry * closure,
                                width: 2 * rx + 4, height: 2 * ry * (1 - closure)))
        }

        // Luminous iris (flat-art translucent pale crystal ice-blue top-to-bottom wash for Siamese!)
        ctx.setFillColor(eyeColor.cgColor)
        ctx.fill(eyeRect)
        if siameseBlue {
            let cs = CGColorSpaceCreateDeviceRGB()
            let irisCols = [
                NSColor(calibratedRed: 0.56, green: 0.77, blue: 0.90, alpha: 1.0).cgColor,  // #8FC4E6 soft cool upper iris
                NSColor(calibratedRed: 0.71, green: 0.87, blue: 0.96, alpha: 1.0).cgColor,  // #B5DEF5 airy pale sky blue
                NSColor(calibratedRed: 0.86, green: 0.945, blue: 0.99, alpha: 1.0).cgColor  // #DBF1FC clear luminous lower iris
            ] as CFArray
            if let irisGrad = CGGradient(colorsSpace: cs, colors: irisCols, locations: [0.0, 0.55, 1.0]) {
                ctx.drawLinearGradient(
                    irisGrad,
                    start: CGPoint(x: 0, y: -ry),
                    end: CGPoint(x: 0, y: ry),
                    options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
                )
            }
        }

        // Pupil morphs smoothly from vertical almond slit -> HUGE round black boba pupil when hunting!
        let gaze = physics.eyeGaze.point
        let px = gaze.x * (4.2 - hunt * 1.2)
        let py = gaze.y * (3.6 - hunt * 1.0)
        let pScale = physics.pupilScale.value
        let normalW: CGFloat = 5.0 * pScale
        let normalH: CGFloat = 13.5 * min(1.12, pScale)
        let huntDiameter: CGFloat = 18.8 // huge round boba pupil leaving an electric chartreuse ring!
        let pupilW = normalW + (huntDiameter - normalW) * hunt
        let pupilH = normalH + (huntDiameter - normalH) * hunt
        let pupilRect = CGRect(x: px - pupilW * 0.5, y: py - pupilH * 0.5, width: pupilW, height: pupilH)
        // Photo-sampled hazel: #DAB257 outside, a narrow #8D9180 ring by the pupil.
        // Paint inside the existing lid clip and follow the animated pupil position/size.
        if customIris == nil && eyeTheme == .referenceHazel {
            for i in 0...24 {
                let t = CGFloat(i) / 24
                let mix = t * t * (3 - 2 * t)
                ctx.setFillColor(NSColor(calibratedRed: (218 - 77 * mix)/255,
                    green: (178 - 33 * mix)/255, blue: (87 + 41 * mix)/255, alpha: 1).cgColor)
                let rim = (1 - t) * 2.2
                ctx.fillEllipse(in: pupilRect.insetBy(dx: -rim, dy: -rim))
            }
        }
        ctx.setFillColor(catBlack.cgColor)
        ctx.fillEllipse(in: pupilRect)

        // Tiny crisp white specular sparkle dot (subtle catchlight on translucent Siamese blue eyes + hunting boba sparkle!)
        if hunt > 0.25 {
            let glintAlpha = min(1.0, (hunt - 0.25) / 0.55) * 0.92
            ctx.setFillColor(NSColor(calibratedWhite: 1.0, alpha: glintAlpha).cgColor)
            let glintR: CGFloat = 2.1 + hunt * 0.9
            ctx.fillEllipse(in: CGRect(
                x: px - pupilW * 0.22 - glintR * 0.5,
                y: py - pupilH * 0.22 - glintR * 0.5,
                width: glintR * 2,
                height: glintR * 2
            ))
        } else if siameseBlue {
            ctx.setFillColor(NSColor(calibratedWhite: 1.0, alpha: 0.86).cgColor)
            let glintR: CGFloat = 1.65
            ctx.fillEllipse(in: CGRect(
                x: px - 2.9 - glintR,
                y: py - 3.6 - glintR,
                width: glintR * 2,
                height: glintR * 2
            ))
        }

        ctx.restoreGState()
        ctx.restoreGState()
    }

    private static func drawWhiskers3D(
        in ctx: CGContext,
        yawRad: CGFloat,
        pitchRad: CGFloat,
        physics: CatPhysics,
        skin: SkinSpec
    ) {
        let wiggle = sin(physics.time * 4.5) * (max(physics.petHeadIntensity, physics.petBodyIntensity) * 1.2)
        ctx.saveGState()
        ctx.setStrokeColor(skin.palette.whiskers.ns.cgColor)
        ctx.setLineWidth(1.0)
        ctx.setLineCap(.round)

        // 3D cheek whiskers — when turning left, left whiskers naturally poke past silhouette
        // while right whiskers sweep inward across the cheek (exact Xiaohongshu effect!)
        for sign in [-1.0, 1.0] as [CGFloat] {
            let rows: [(CGFloat, CGFloat, CGFloat)] = [
                (10.5, 36.5, 8.8 + wiggle),
                (14.2, 37.8, 14.2 + wiggle * 0.5),
                (18.0, 35.5, 19.6 - wiggle * 0.4)
            ]
            for (y0, xEnd, yEnd) in rows {
                let p0 = projectHead3D(x: sign * 24.0, y: y0, z: 23.0, yawRad: yawRad, pitchRad: pitchRad).pt
                let p2 = projectHead3D(x: sign * xEnd, y: yEnd, z: 14.0, yawRad: yawRad, pitchRad: pitchRad).pt
                let ctrl = CGPoint(x: (p0.x + p2.x) * 0.5, y: (p0.y + p2.y) * 0.5 - 0.8)
                ctx.move(to: p0)
                ctx.addQuadCurve(to: p2, control: ctrl)
            }
        }
        ctx.strokePath()
        ctx.restoreGState()
    }

    // MARK: - Decorations (anchored PNG stickers)

    private static func drawDecorations(in ctx: CGContext, seatX: CGFloat, seatY: CGFloat, head: CGPoint, physics: CatPhysics, skin: SkinSpec) {
        let yawRad = physics.headYaw.value * 0.50, pitchRad = physics.headPitch.value * 0.36
        for deco in skin.decorations {
            var at = CGPoint.zero
            var rot: CGFloat = 0, kx: CGFloat = 1, ky: CGFloat = 1
            switch deco.anchor {
            case .headTop, .face:
                let baseY: CGFloat = deco.anchor == .headTop ? -30 : 4
                at = headPoint(CGPoint(x: deco.offsetX, y: baseY + deco.offsetY), skull: false, skin: skin, head: head, physics: physics)
                rot = physics.headTilt.value
                kx = max(0.55, cos(yawRad)) * skin.shape.headScale
                ky = max(0.70, cos(pitchRad)) * skin.shape.headScale
            case .neck:
                at = bodyPoint(CGPoint(x: deco.offsetX, y: -64 + deco.offsetY), skin: skin, seatX: seatX, seatY: seatY, physics: physics)
                rot = physics.bodyTilt.value
            case .tailTip:
                let curve = tailCurve(seatX: seatX, seatY: seatY, physics: physics, skin: skin)
                at = CGPoint(x: curve.tip.x + deco.offsetX, y: curve.tip.y + deco.offsetY)
            }
            let scale = 0.5 * deco.scale   // stickers are authored at 2x: 1 image px = 0.5 canvas units
            let w = CGFloat(deco.image.width), h = CGFloat(deco.image.height)
            ctx.saveGState()
            ctx.translateBy(x: at.x, y: at.y)
            ctx.rotate(by: rot + deco.rotation * .pi / 180)
            ctx.scaleBy(x: scale * kx, y: scale * ky)
            // The canvas is flipped (y down); flip locally so the PNG is upright.
            ctx.translateBy(x: 0, y: h * 0.5)
            ctx.scaleBy(x: 1, y: -1)
            ctx.interpolationQuality = .high
            ctx.draw(deco.image, in: CGRect(x: -w * 0.5, y: 0, width: w, height: h))
            ctx.restoreGState()
        }
    }

    // MARK: - Front Paws (Idle Sitting & Dynamic Reaching with Signature Outlines / Colour-point Socks)

    private static func drawFrontPaws(
        in ctx: CGContext,
        seatX: CGFloat,
        seatY: CGFloat,
        breath: CGFloat,
        physics: CatPhysics,
        skin: SkinSpec
    ) {
        let lPos = physics.leftPaw.point
        let rPos = physics.rightPaw.point

        let lDist = hypot(lPos.x - CatPhysics.leftPawRest.x, lPos.y - CatPhysics.leftPawRest.y)
        let rDist = hypot(rPos.x - CatPhysics.rightPawRest.x, rPos.y - CatPhysics.rightPawRest.y)

        // Attach to the transformed chest, below the moving face rather than its white blaze.
        let bd = build(skin)
        let bw = skin.shape.bodyWidth
        let headLift: CGFloat = bd.headLift
        let idleTopY: CGFloat = seatY - bd.idleTopDY
        let idleTopX: CGFloat = bd.idleTopX * bw
        let idleBotX: CGFloat = bd.idleBotX * bw
        let shX: CGFloat = bd.shoulderX * bw
        func shoulder(_ x: CGFloat) -> CGPoint {
            let sy = physics.bodySquash.value, sx = 1 + (1 - sy) * 0.55
            let c = cos(physics.bodyTilt.value), s = sin(physics.bodyTilt.value)
            let faceBottom = 126 + headLift + physics.headOffsetY.value + physics.headPitch.value * 4.8 + breath * 1.1 + 42
            return CGPoint(x: seatX + x*sx*c + 58*sy*s,
                           y: max(seatY + x*sx*s - 58*sy*c, faceBottom))
        }
        let leftShoulder = shoulder(-shX)
        let rightShoulder = shoulder(shX)

        // Left arm
        if lDist < 6.0 && !physics.leftPawOnMouse && !physics.leftPawTyping {
            drawIdleFrontLeg(in: ctx, top: CGPoint(x: seatX - idleTopX, y: idleTopY), bottom: CGPoint(x: seatX - idleBotX, y: seatY + 12), isLeft: true, skin: skin)
        } else {
            let mid = CGPoint(
                x: (leftShoulder.x + lPos.x) * 0.5 - (physics.leftPawOnMouse ? 8 : 4),
                y: (leftShoulder.y + lPos.y) * 0.5 - 6
            )
            drawLimb(
                in: ctx,
                start: leftShoulder,
                control: mid,
                end: lPos,
                startWidth: bd.limbStartW,
                endWidth: bd.limbEndW,
                outlineOnLeftSide: false,
                outlineAlpha: 0.78,
                skin: skin
            )
        }

        // Right arm
        if rDist < 6.0 && !physics.rightPawTyping {
            drawIdleFrontLeg(in: ctx, top: CGPoint(x: seatX + idleTopX, y: idleTopY), bottom: CGPoint(x: seatX + idleBotX, y: seatY + 12), isLeft: false, skin: skin)
        } else {
            let mid = CGPoint(
                x: (rightShoulder.x + rPos.x) * 0.5 + 4,
                y: (rightShoulder.y + rPos.y) * 0.5 - 6
            )
            drawLimb(
                in: ctx,
                start: rightShoulder,
                control: mid,
                end: rPos,
                startWidth: bd.limbStartW,
                endWidth: bd.limbEndW,
                outlineOnLeftSide: true,
                outlineAlpha: 0.78,
                skin: skin
            )
        }
    }

    /// Signature tucked sitting front legs (black with mint lines OR colour-point cream-to-chocolate socks!)
    private static func drawIdleFrontLeg(in ctx: CGContext, top: CGPoint, bottom: CGPoint, isLeft: Bool, skin: SkinSpec) {
        let pal = skin.palette
        let sign: CGFloat = isLeft ? -1.0 : 1.0
        ctx.saveGState()

        if let point = pal.points {
            // Creamy upper leg dipping smoothly into adorable seal-point chocolate socks resting on the keyboard!
            let mid = pal.pointsMid ?? point
            let legRect = CGRect(x: bottom.x - 7.5, y: top.y, width: 15.0, height: bottom.y - top.y + 5.0)
            let legPath = CGPath(roundedRect: legRect, cornerWidth: 6.5, cornerHeight: 6.5, transform: nil)
            ctx.saveGState()
            ctx.addPath(legPath)
            ctx.clip()
            let cs = CGColorSpaceCreateDeviceRGB()
            let colors = [
                pal.body.withAlpha(0.0).cgColor,
                mid.withAlpha(0.75).cgColor,
                point.ns.cgColor
            ] as CFArray
            if let grad = CGGradient(colorsSpace: cs, colors: colors, locations: [0.05, 0.50, 0.82]) {
                ctx.drawLinearGradient(
                    grad,
                    start: CGPoint(x: top.x, y: top.y),
                    end: CGPoint(x: bottom.x, y: bottom.y + 5.0),
                    options: []
                )
            }
            ctx.restoreGState()
        } else {
            // Smooth shoulder-fade leg fill so palette.legs shows cleanly on idle sitting legs too
            // ("idleLegs": "legs"; the built-in coats use "chest" and keep their approved look)
            if skin.idleLegsTinted {
            let legShape = CGMutablePath()
            legShape.move(to: CGPoint(x: top.x + sign * 8.5, y: top.y))
            legShape.addQuadCurve(
                to: CGPoint(x: bottom.x + sign * 7.5, y: bottom.y - 1),
                control: CGPoint(x: top.x + sign * 9.5, y: (top.y + bottom.y) * 0.5)
            )
            legShape.addQuadCurve(
                to: CGPoint(x: bottom.x + sign * 0.8, y: bottom.y + 5.2),
                control: CGPoint(x: bottom.x + sign * 7.0, y: bottom.y + 5.2)
            )
            legShape.addQuadCurve(
                to: CGPoint(x: bottom.x - sign * 6.0, y: bottom.y - 1),
                control: CGPoint(x: bottom.x - sign * 6.2, y: bottom.y + 5.2)
            )
            legShape.addQuadCurve(
                to: CGPoint(x: top.x - sign * 7.0, y: top.y + 4),
                control: CGPoint(x: top.x - sign * 6.5, y: (top.y + bottom.y) * 0.5)
            )
            legShape.closeSubpath()
            ctx.saveGState()
            ctx.addPath(legShape)
            ctx.clip()
            let cs = CGColorSpaceCreateDeviceRGB()
            let legCols = [pal.legs.withAlpha(0.0).cgColor, pal.legs.ns.cgColor, pal.legs.ns.cgColor] as CFArray
            if let legGrad = CGGradient(colorsSpace: cs, colors: legCols, locations: [0.04, 0.32, 1.0]) {
                ctx.drawLinearGradient(
                    legGrad,
                    start: CGPoint(x: top.x, y: top.y),
                    end: CGPoint(x: bottom.x, y: bottom.y + 5.0),
                    options: [.drawsAfterEndLocation]
                )
            }
            ctx.restoreGState()
            }

            ctx.setFillColor(pal.paws.ns.cgColor)
            let cuff = CGRect(x: bottom.x - 7.5, y: bottom.y - 13, width: 15, height: 18)
            ctx.addPath(CGPath(roundedRect: cuff, cornerWidth: 6.5, cornerHeight: 6.5, transform: nil))
            ctx.fillPath()
        }
        ctx.setStrokeColor(pal.crease.ns.cgColor)
        ctx.setLineWidth(1.45)
        ctx.setLineCap(.round)

        // Outer separation crease
        ctx.move(to: CGPoint(x: top.x + sign * 8.5, y: top.y))
        ctx.addQuadCurve(
            to: CGPoint(x: bottom.x + sign * 7.5, y: bottom.y - 1),
            control: CGPoint(x: top.x + sign * 9.5, y: (top.y + bottom.y) * 0.5)
        )
        // Inner separation crease
        ctx.move(to: CGPoint(x: top.x - sign * 7.0, y: top.y + 4))
        ctx.addQuadCurve(
            to: CGPoint(x: bottom.x - sign * 6.0, y: bottom.y - 1),
            control: CGPoint(x: top.x - sign * 6.5, y: (top.y + bottom.y) * 0.5)
        )
        ctx.strokePath()
        ctx.restoreGState()
    }

    /// Smooth tapered limb + plump rounded paw (solid legs, white socks OR colour-point cream-to-espresso socks!)
    private static func drawLimb(
        in ctx: CGContext,
        start: CGPoint,
        control: CGPoint,
        end: CGPoint,
        startWidth: CGFloat,
        endWidth: CGFloat,
        outlineOnLeftSide: Bool,
        outlineAlpha: CGFloat,
        skin: SkinSpec
    ) {
        let pal = skin.palette
        let steps = 14
        var leftEdge: [CGPoint] = []
        var rightEdge: [CGPoint] = []

        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let p = quadPoint(start, control, end, t: t)
            let tan = quadTangent(start, control, end, t: t)
            let len = max(0.001, hypot(tan.x, tan.y))
            let nx = -tan.y / len
            let ny = tan.x / len
            let halfW = (startWidth + (endWidth - startWidth) * t) * 0.5
            leftEdge.append(CGPoint(x: p.x + nx * halfW, y: p.y + ny * halfW))
            rightEdge.append(CGPoint(x: p.x - nx * halfW, y: p.y - ny * halfW))
        }

        let limbPath = CGMutablePath()
        limbPath.move(to: leftEdge[0])
        for pt in leftEdge.dropFirst() { limbPath.addLine(to: pt) }
        for pt in rightEdge.reversed() { limbPath.addLine(to: pt) }
        let tangent = quadTangent(start, control, end, t: 0)
        let length = max(0.001, hypot(tangent.x, tangent.y))
        limbPath.addQuadCurve(to: leftEdge[0], control: CGPoint(
            x: start.x - tangent.x/length*startWidth*0.5,
            y: start.y - tangent.y/length*startWidth*0.5))
        limbPath.closeSubpath()

        let pawR = endWidth * 0.58
        let pawRect = CGRect(x: end.x - pawR, y: end.y - pawR * 0.85, width: pawR * 2, height: pawR * 1.7)
        let lineColor = pal.outline ?? pal.crease

        ctx.saveGState()
        if let point = pal.points {
            // Colour-point chocolate-dipped socks gradient along the limb!
            // Starts transparent at shoulder (0.0) so it melts 100% seamlessly into the creamy chest!
            let mid = pal.pointsMid ?? point
            ctx.saveGState()
            ctx.addPath(limbPath)
            ctx.clip()
            let cs = CGColorSpaceCreateDeviceRGB()
            let colors = [
                pal.body.withAlpha(0.0).cgColor,
                pal.body.ns.cgColor,
                mid.ns.cgColor,
                point.ns.cgColor
            ] as CFArray
            if let grad = CGGradient(colorsSpace: cs, colors: colors, locations: [0.0, 0.16, 0.48, 0.78]) {
                ctx.drawLinearGradient(grad, start: start, end: end, options: [.drawsAfterEndLocation])
            }
            ctx.restoreGState()

            // Solid rich espresso-chocolate rounded paw tip (no winding-rule overlap artifacts!)
            ctx.setFillColor(pal.paws.ns.cgColor)
            ctx.fillEllipse(in: pawRect)

            // Clean outer edge outline on the arm (fading in below shoulder) so it reads crisply over light backgrounds
            ctx.setStrokeColor(lineColor.withAlpha(0.72).cgColor)
            ctx.setLineWidth(1.25)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            let outerEdge = outlineOnLeftSide ? rightEdge : leftEdge
            if outerEdge.count > 4 {
                ctx.move(to: outerEdge[3])
                for idx in 4..<(outerEdge.count - 1) { ctx.addLine(to: outerEdge[idx]) }
                ctx.strokePath()
            }
        } else {
            ctx.setFillColor(pal.legs.ns.cgColor)
            ctx.addPath(limbPath)
            if let chest = pal.belly, chest != pal.legs {
                // White chest fading into the leg colour along the first 30% of the arm.
                ctx.saveGState(); ctx.clip()
                let colors = [chest.ns.cgColor, pal.legs.ns.cgColor] as CFArray
                if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.30]) {
                    ctx.drawLinearGradient(gradient, start: start, end: end,
                                           options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
                }
                ctx.restoreGState()
            } else { ctx.fillPath() }
            if pal.paws == pal.legs { ctx.fillEllipse(in: pawRect) }
            else {
                let cuff = CGMutablePath()
                let first = Int(CGFloat(steps) * 0.72)
                cuff.move(to: leftEdge[first])
                for pt in leftEdge.dropFirst(first + 1) { cuff.addLine(to: pt) }
                for pt in rightEdge.dropFirst(first).reversed() { cuff.addLine(to: pt) }
                cuff.closeSubpath()
                ctx.setFillColor(pal.paws.ns.cgColor); ctx.addPath(cuff); ctx.fillPath()
                ctx.fillEllipse(in: pawRect)
            }
        }

        // Crisp separation stroke along upper-to-mid arm where it crosses the torso
        let highlightEdge = outlineOnLeftSide ? leftEdge : rightEdge
        if highlightEdge.count > 6 {
            let strokeColor = skin.colorpoint
                ? lineColor.withAlpha(outlineAlpha * 0.78)
                : pal.crease.withAlpha(outlineAlpha * 0.9)
            ctx.setStrokeColor(strokeColor.cgColor)
            ctx.setLineWidth(1.35)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            let startIdx = 2
            let endIdx = Int(CGFloat(highlightEdge.count - 1) * 0.68)
            ctx.move(to: highlightEdge[startIdx])
            for idx in (startIdx + 1)...endIdx {
                ctx.addLine(to: highlightEdge[idx])
            }
            ctx.strokePath()
        }
        ctx.restoreGState()
    }

    // MARK: - Floating Mechanical Keycap Popups

    private static func drawFloatingKeycaps(in ctx: CGContext, physics: CatPhysics) {
        for badge in physics.floatingKeycaps {
            let progress = badge.age / badge.lifetime
            // Spring pop-in scale (starts crisp and readable immediately!)
            let scale: CGFloat
            if badge.age < 0.09 {
                let t = badge.age / 0.09
                scale = 0.72 + 0.38 * sin(t * .pi * 0.65)
            } else if badge.age < 0.18 {
                let t = (badge.age - 0.09) / 0.09
                scale = 1.10 - 0.10 * t
            } else {
                scale = 1.0
            }

            let alpha: CGFloat = progress < 0.62 ? 1.0 : max(0, 1.0 - (progress - 0.62) / 0.38)

            let charCount = badge.label.count
            let fontSize: CGFloat = charCount <= 1 ? 11.5 : 10.0
            let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor(calibratedRed: 0.12, green: 0.12, blue: 0.14, alpha: 1.0)
            ]
            let attrStr = NSAttributedString(string: badge.label, attributes: attrs)
            let strSize = attrStr.size()
            let w: CGFloat = max(23, ceil(strSize.width) + 12)
            let h: CGFloat = 22

            ctx.saveGState()
            ctx.setAlpha(alpha)
            ctx.translateBy(x: badge.position.x, y: badge.position.y)
            ctx.rotate(by: badge.rotation)
            ctx.scaleBy(x: scale, y: scale)

            // 3D bottom keycap edge / shadow
            let baseRect = CGRect(x: -w * 0.5, y: -h * 0.5 + 2.5, width: w, height: h)
            let basePath = CGPath(roundedRect: baseRect, cornerWidth: 5.5, cornerHeight: 5.5, transform: nil)
            ctx.setFillColor(NSColor(calibratedRed: 0.15, green: 0.15, blue: 0.17, alpha: 0.95).cgColor)
            ctx.addPath(basePath)
            ctx.fillPath()

            // Crisp white mechanical keycap top face
            let faceRect = CGRect(x: -w * 0.5, y: -h * 0.5, width: w, height: h)
            let facePath = CGPath(roundedRect: faceRect, cornerWidth: 5.2, cornerHeight: 5.2, transform: nil)
            ctx.setFillColor(NSColor(calibratedRed: 0.975, green: 0.972, blue: 0.952, alpha: 1.0).cgColor)
            ctx.addPath(facePath)
            ctx.fillPath()

            ctx.setStrokeColor(NSColor(calibratedRed: 0.16, green: 0.16, blue: 0.18, alpha: 1.0).cgColor)
            ctx.setLineWidth(1.45)
            ctx.addPath(facePath)
            ctx.strokePath()

            // Centered bold key label
            let drawPt = CGPoint(x: -strSize.width * 0.5, y: -strSize.height * 0.5 - 0.5)
            NSGraphicsContext.saveGraphicsState()
            let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: true)
            NSGraphicsContext.current = nsCtx
            attrStr.draw(at: drawPt)
            NSGraphicsContext.restoreGraphicsState()

            ctx.restoreGState()
        }
    }

    // MARK: - Subtle Petting Sparkles & Sleep Z

    private static func drawSparkles(in ctx: CGContext, physics: CatPhysics, eyeTheme: EyeColorTheme) {
        for sp in physics.sparkles {
            let p = sp.age / sp.lifetime
            let alpha = sin(min(1.0, p) * .pi)
            ctx.saveGState()
            ctx.setAlpha(alpha * 0.85)
            if sp.isSleepZ {
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 11 + p * 3, weight: .bold),
                    .foregroundColor: eyeTheme.primaryColor
                ]
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
                NSAttributedString(string: "z", attributes: attrs).draw(at: sp.position)
                NSGraphicsContext.restoreGraphicsState()
            } else {
                // Tiny glowing chartreuse 4-point star
                let r: CGFloat = 3.5 + p * 1.5
                ctx.translateBy(x: sp.position.x, y: sp.position.y)
                ctx.setFillColor(eyeTheme.primaryColor.cgColor)
                let star = CGMutablePath()
                star.move(to: CGPoint(x: 0, y: -r))
                star.addQuadCurve(to: CGPoint(x: r, y: 0), control: CGPoint(x: 0.8, y: -0.8))
                star.addQuadCurve(to: CGPoint(x: 0, y: r), control: CGPoint(x: 0.8, y: 0.8))
                star.addQuadCurve(to: CGPoint(x: -r, y: 0), control: CGPoint(x: -0.8, y: 0.8))
                star.addQuadCurve(to: CGPoint(x: 0, y: -r), control: CGPoint(x: -0.8, y: -0.8))
                star.closeSubpath()
                ctx.addPath(star)
                ctx.fillPath()
            }
            ctx.restoreGState()
        }
    }

    // MARK: - Non-Intrusive Permission Pill

    private static func drawPermissionPill(in ctx: CGContext, text: String) {
        let r = permissionPillRect
        let path = CGPath(roundedRect: r, cornerWidth: 11, cornerHeight: 11, transform: nil)

        ctx.saveGState()
        ctx.setFillColor(NSColor(calibratedRed: 0.11, green: 0.11, blue: 0.13, alpha: 0.90).cgColor)
        ctx.addPath(path)
        ctx.fillPath()

        ctx.setStrokeColor(NSColor(calibratedRed: 0.79, green: 0.95, blue: 0.25, alpha: 0.90).cgColor)
        ctx.setLineWidth(1.2)
        ctx.addPath(path)
        ctx.strokePath()

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10.5, weight: .semibold),
            .foregroundColor: NSColor(calibratedRed: 0.95, green: 0.97, blue: 0.90, alpha: 1.0)
        ]
        let str = NSAttributedString(string: text, attributes: attrs)
        let sz = str.size()
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
        str.draw(at: CGPoint(x: r.midX - sz.width * 0.5, y: r.midY - sz.height * 0.5 - 0.5))
        NSGraphicsContext.restoreGraphicsState()

        ctx.restoreGState()
    }

    // MARK: - Geometry & Color Helpers

    private static func keycapLegend(_ key: PhysicalKey) -> String {
        switch key {
        case .escape: return "ESC"
        case .tab: return "⇥"
        case .capsLock: return "⇪"
        case .leftShift, .rightShift: return "⇧"
        case .leftControl, .rightControl: return "⌃"
        case .leftOption, .rightOption: return "⌥"
        case .leftCommand, .rightCommand: return "⌘"
        case .backspace: return "⌫"
        case .enter: return "↵"
        case .space: return ""
        default: return key.badgeLabel
        }
    }

    private static func offsetY(_ pt: CGPoint, _ dy: CGFloat) -> CGPoint {
        CGPoint(x: pt.x, y: pt.y + dy)
    }

    private static func quadPoint(_ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint, t: CGFloat) -> CGPoint {
        let mt = 1 - t
        return CGPoint(
            x: mt * mt * p0.x + 2 * mt * t * p1.x + t * t * p2.x,
            y: mt * mt * p0.y + 2 * mt * t * p1.y + t * t * p2.y
        )
    }

    private static func quadTangent(_ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint, t: CGFloat) -> CGPoint {
        let mt = 1 - t
        return CGPoint(
            x: 2 * mt * (p1.x - p0.x) + 2 * t * (p2.x - p1.x),
            y: 2 * mt * (p1.y - p0.y) + 2 * t * (p2.y - p1.y)
        )
    }

    private static func roundedQuadPath(
        tl: CGPoint, tr: CGPoint, br: CGPoint, bl: CGPoint, radius: CGFloat
    ) -> CGPath {
        let p = CGMutablePath()
        let midTop = CGPoint(x: (tl.x + tr.x) * 0.5, y: (tl.y + tr.y) * 0.5)
        p.move(to: midTop)
        p.addArc(tangent1End: tr, tangent2End: br, radius: radius)
        p.addArc(tangent1End: br, tangent2End: bl, radius: radius)
        p.addArc(tangent1End: bl, tangent2End: tl, radius: radius)
        p.addArc(tangent1End: tl, tangent2End: tr, radius: radius)
        p.closeSubpath()
        return p
    }

    private static func blendColor(_ a: NSColor, _ b: NSColor, t: CGFloat) -> NSColor {
        let ca = a.usingColorSpace(.deviceRGB) ?? a
        let cb = b.usingColorSpace(.deviceRGB) ?? b
        let clamped = max(0, min(1, t))
        return NSColor(
            calibratedRed: ca.redComponent + (cb.redComponent - ca.redComponent) * clamped,
            green: ca.greenComponent + (cb.greenComponent - ca.greenComponent) * clamped,
            blue: ca.blueComponent + (cb.blueComponent - ca.blueComponent) * clamped,
            alpha: ca.alphaComponent + (cb.alphaComponent - ca.alphaComponent) * clamped
        )
    }

    private static func drawRadialGlow(in ctx: CGContext, center: CGPoint, radius: CGFloat, color: NSColor) {
        let cs = CGColorSpaceCreateDeviceRGB()
        let colors = [color.cgColor, color.withAlphaComponent(0.0).cgColor] as CFArray
        let locs: [CGFloat] = [0.0, 1.0]
        if let grad = CGGradient(colorsSpace: cs, colors: colors, locations: locs) {
            ctx.saveGState()
            ctx.drawRadialGradient(
                grad,
                startCenter: center, startRadius: 0,
                endCenter: center, endRadius: radius,
                options: []
            )
            ctx.restoreGState()
        }
    }
}
