import AppKit
import CoreText

let orange = NSColor(srgbRed: 1.0, green: 0.42, blue: 0.10, alpha: 1.0)
let ink = NSColor(srgbRed: 0.07, green: 0.07, blue: 0.09, alpha: 1.0)
let pale = orange.blended(withFraction: 0.87, of: .white)!
let track = orange.blended(withFraction: 0.87, of: .white)!
let outDir = URL(fileURLWithPath: "brand", isDirectory: true)
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

func context(_ width: Int, _ height: Int, scale: CGFloat = 2) -> (NSBitmapImageRep, CGContext) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                               pixelsWide: Int(CGFloat(width) * scale),
                               pixelsHigh: Int(CGFloat(height) * scale),
                               bitsPerSample: 8,
                               samplesPerPixel: 4,
                               hasAlpha: true,
                               isPlanar: false,
                               colorSpaceName: .deviceRGB,
                               bytesPerRow: 0,
                               bitsPerPixel: 0)!
    let gc = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = gc
    gc.imageInterpolation = .high
    gc.cgContext.scaleBy(x: scale, y: scale)
    gc.cgContext.setAllowsAntialiasing(true)
    gc.cgContext.setShouldAntialias(true)
    return (rep, gc.cgContext)
}

func save(_ rep: NSBitmapImageRep, _ ctx: CGContext, to name: String, width: Int, height: Int) {
    NSGraphicsContext.restoreGraphicsState()
    let image = rep.cgImage!
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let final = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                          bytesPerRow: 0, space: space,
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    final.interpolationQuality = .high
    final.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    let out = NSBitmapImageRep(cgImage: final.makeImage()!)
    let data = out.representation(using: .png, properties: [:])!
    try! data.write(to: outDir.appendingPathComponent(name))
}

func glyphPath(_ character: Character, font: CTFont) -> CGPath {
    var chars = Array(String(character).utf16)
    var glyphs = [CGGlyph](repeating: 0, count: chars.count)
    CTFontGetGlyphsForCharacters(font, &chars, &glyphs, chars.count)
    return CTFontCreatePathForGlyph(font, glyphs[0], nil)!
}

func transformed(_ path: CGPath, scale: CGFloat) -> CGPath {
    var t = CGAffineTransform(scaleX: scale, y: scale)
    return path.copy(using: &t)!
}

func translated(_ path: CGPath, dx: CGFloat, dy: CGFloat) -> CGPath {
    var t = CGAffineTransform(translationX: dx, y: dy)
    return path.copy(using: &t)!
}

func wPath(fittingHeight height: CGFloat) -> CGPath {
    let font = NSFont.systemFont(ofSize: 1000, weight: .black) as CTFont
    let raw = glyphPath("W", font: font)
    let box = raw.boundingBoxOfPath
    let tall = transformed(raw, scale: height / box.height)
    var wide = CGAffineTransform(scaleX: 1.0, y: 1)
    return tall.copy(using: &wide)!
}

func waveLine(_ x: CGFloat, box: CGRect, base: CGFloat, amplitude: CGFloat) -> CGFloat {
    let t = (x - box.minX) / box.width
    return base + amplitude * sin(t * .pi * 4 + .pi / 2)
}

func drawW(in rect: CGRect, ctx: CGContext) {
    let path = wPath(fittingHeight: rect.height)
    let rawBox = path.boundingBoxOfPath
    let placed = translated(path,
                            dx: rect.midX - rawBox.midX,
                            dy: rect.midY - rawBox.midY)
    let box = placed.boundingBoxOfPath
    let rounding = placed.copy(strokingWithWidth: box.height * 0.028,
                               lineCap: .round, lineJoin: .round, miterLimit: 10)
    let silhouette = CGMutablePath()
    silhouette.addPath(placed)
    silhouette.addPath(rounding)
    let boxR = silhouette.boundingBoxOfPath
    let fillBase = boxR.minY + boxR.height * 0.43
    let bandHeight = boxR.height * 0.13
    let amplitude = boxR.height * 0.006
    let stripe = bandHeight * 0.30

    ctx.saveGState()
    ctx.addPath(silhouette)
    ctx.clip()

    ctx.setFillColor(pale.cgColor)
    ctx.fill(boxR.insetBy(dx: -4, dy: -4))

    let band = CGMutablePath()
    let bandTop = fillBase + bandHeight
    band.move(to: CGPoint(x: boxR.minX - 6, y: bandTop))
    band.addLine(to: CGPoint(x: boxR.maxX + 6, y: bandTop))
    band.addLine(to: CGPoint(x: boxR.maxX + 6, y: waveLine(boxR.maxX + 6, box: boxR, base: fillBase, amplitude: amplitude)))
    var x = boxR.maxX + 6
    while x > boxR.minX - 6 {
        x -= 2
        band.addLine(to: CGPoint(x: x, y: waveLine(x, box: boxR, base: fillBase, amplitude: amplitude)))
    }
    band.closeSubpath()

    ctx.saveGState()
    ctx.addPath(band)
    ctx.clip()
    ctx.setFillColor(orange.withAlphaComponent(0.35).cgColor)
    ctx.fill(boxR.insetBy(dx: -8, dy: -8))
    ctx.setStrokeColor(orange.withAlphaComponent(0.55).cgColor)
    ctx.setLineWidth(stripe)
    var offset = boxR.minX - boxR.height
    while offset < boxR.maxX + boxR.height {
        ctx.move(to: CGPoint(x: offset, y: boxR.minY - 10))
        ctx.addLine(to: CGPoint(x: offset + boxR.height + 20, y: boxR.minY - 10 + boxR.height + 20))
        ctx.strokePath()
        offset += stripe * 2
    }
    ctx.restoreGState()

    ctx.setStrokeColor(orange.cgColor)
    ctx.setLineWidth(max(2, boxR.height * 0.008))
    ctx.move(to: CGPoint(x: boxR.minX - 6, y: bandTop))
    ctx.addLine(to: CGPoint(x: boxR.maxX + 6, y: bandTop))
    ctx.strokePath()

    let solid = CGMutablePath()
    solid.move(to: CGPoint(x: boxR.minX - 6, y: boxR.minY - 10))
    solid.addLine(to: CGPoint(x: boxR.minX - 6, y: waveLine(boxR.minX - 6, box: boxR, base: fillBase, amplitude: amplitude)))
    x = boxR.minX - 6
    while x < boxR.maxX + 6 {
        x += 2
        solid.addLine(to: CGPoint(x: x, y: waveLine(x, box: boxR, base: fillBase, amplitude: amplitude)))
    }
    solid.addLine(to: CGPoint(x: boxR.maxX + 6, y: boxR.minY - 10))
    solid.closeSubpath()
    ctx.setFillColor(orange.cgColor)
    ctx.addPath(solid)
    ctx.fillPath()

    ctx.restoreGState()
}

func squircle(_ rect: CGRect) -> CGPath {
    let radius = rect.width * 0.2237
    return CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func drawIconTile(in rect: CGRect, ctx: CGContext) {
    let h = rect.height * 0.66
    let w = h * 1.25
    let wRect = CGRect(x: rect.midX - w / 2, y: rect.midY - h / 2, width: w, height: h)
    drawW(in: wRect, ctx: ctx)
}

func renderAppIcon() {
    let (rep, ctx) = context(1024, 1024)
    ctx.setFillColor(NSColor.white.cgColor)
    ctx.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
    drawIconTile(in: CGRect(x: 0, y: 0, width: 1024, height: 1024), ctx: ctx)
    save(rep, ctx, to: "wonday-appicon-1024.png", width: 1024, height: 1024)
}

func renderIconPreview() {
    let (rep, ctx) = context(1200, 1200)
    let tile = CGRect(x: 130, y: 130, width: 940, height: 940)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 40,
                  color: NSColor.black.withAlphaComponent(0.18).cgColor)
    ctx.addPath(squircle(tile))
    ctx.setFillColor(NSColor.white.cgColor)
    ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(squircle(tile))
    ctx.clip()
    drawIconTile(in: tile, ctx: ctx)
    ctx.restoreGState()
    save(rep, ctx, to: "wonday-icon.png", width: 1200, height: 1200)
}

func attributed(_ string: String, font: NSFont, color: NSColor, tracking: CGFloat) -> NSAttributedString {
    NSAttributedString(string: string, attributes: [
        .font: font,
        .foregroundColor: color,
        .kern: tracking * font.pointSize
    ])
}

func drawWordmark(size: CGFloat, color: NSColor, at origin: CGPoint, ctx: CGContext) -> CGRect {
    let font = NSFont.systemFont(ofSize: size, weight: .black)
    let ctFont = font as CTFont
    let line = CTLineCreateWithAttributedString(attributed("wonday", font: font, color: color, tracking: -0.030))
    let xHeight = CTFontGetXHeight(ctFont)
    let ringDiameter = xHeight * 1.16
    let stroke = size * 0.122

    ctx.setFillColor(color.cgColor)
    let runs = CTLineGetGlyphRuns(line) as! [CTRun]
    for run in runs {
        let count = CTRunGetGlyphCount(run)
        var glyphs = [CGGlyph](repeating: 0, count: count)
        var positions = [CGPoint](repeating: .zero, count: count)
        var advances = [CGSize](repeating: .zero, count: count)
        var indices = [CFIndex](repeating: 0, count: count)
        CTRunGetGlyphs(run, CFRangeMake(0, 0), &glyphs)
        CTRunGetPositions(run, CFRangeMake(0, 0), &positions)
        CTRunGetAdvances(run, CFRangeMake(0, 0), &advances)
        CTRunGetStringIndices(run, CFRangeMake(0, 0), &indices)
        let attributes = CTRunGetAttributes(run) as NSDictionary
        let runFont = attributes[kCTFontAttributeName as String] as! CTFont

        for i in 0..<count {
            let p = CGPoint(x: origin.x + positions[i].x, y: origin.y + positions[i].y)
            if indices[i] == 1 {
                let center = CGPoint(x: p.x + advances[i].width / 2 + size * 0.010, y: origin.y + ringDiameter / 2 - xHeight * 0.02)
                drawRing(center: center, diameter: ringDiameter, stroke: stroke, ctx: ctx)
            } else {
                var g = glyphs[i]
                var pos = p
                CTFontDrawGlyphs(runFont, &g, &pos, 1, ctx)
            }
        }
    }
    let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
    return bounds.offsetBy(dx: origin.x, dy: origin.y)
}

func drawRing(center: CGPoint, diameter: CGFloat, stroke: CGFloat, ctx: CGContext) {
    let radius = (diameter - stroke) / 2
    ctx.saveGState()
    ctx.setLineWidth(stroke)
    ctx.setLineCap(.butt)

    ctx.setStrokeColor(track.cgColor)
    ctx.addArc(center: center, radius: radius, startAngle: .pi, endAngle: .pi / 2, clockwise: true)
    ctx.strokePath()

    ctx.setStrokeColor(orange.cgColor)
    ctx.addArc(center: center, radius: radius, startAngle: .pi / 2, endAngle: -.pi, clockwise: true)
    ctx.strokePath()

    ctx.restoreGState()
}

func renderWordmark(transparent: Bool) {
    let width = 2400
    let height = 900
    let (rep, ctx) = context(width, height)
    if !transparent {
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
    }
    let target: CGFloat = 2040
    let probeSize: CGFloat = 500
    let probe = CTLineCreateWithAttributedString(attributed("wonday", font: NSFont.systemFont(ofSize: probeSize, weight: .black), color: ink, tracking: -0.030))
    let probeBounds = CTLineGetBoundsWithOptions(probe, .useGlyphPathBounds)
    let size = probeSize * target / probeBounds.width

    let font = NSFont.systemFont(ofSize: size, weight: .black)
    let line = CTLineCreateWithAttributedString(attributed("wonday", font: font, color: ink, tracking: -0.030))
    let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
    let origin = CGPoint(x: (CGFloat(width) - bounds.width) / 2 - bounds.minX,
                         y: (CGFloat(height) - bounds.height) / 2 - bounds.minY)
    _ = drawWordmark(size: size, color: ink, at: origin, ctx: ctx)
    save(rep, ctx, to: transparent ? "wonday-wordmark-transparent.png" : "wonday-wordmark.png", width: width, height: height)
}

func renderLockup(dark: Bool) {
    let width = 1800
    let height = 600
    let (rep, ctx) = context(width, height)
    if dark {
        let pill = CGRect(x: 40, y: 80, width: 1720, height: 440)
        ctx.addPath(CGPath(roundedRect: pill, cornerWidth: 90, cornerHeight: 90, transform: nil))
        ctx.setFillColor(ink.cgColor)
        ctx.fillPath()
    }
    let iconRect = CGRect(x: 0, y: 190, width: 220, height: 220)
    let textColor = dark ? NSColor.white : ink
    let font = NSFont.systemFont(ofSize: 200, weight: .black)
    let line = CTLineCreateWithAttributedString(attributed("Wonday", font: font, color: textColor, tracking: -0.03))
    let tb = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
    let gap: CGFloat = 80
    let groupWidth = iconRect.width + gap + tb.width
    let startX = (CGFloat(width) - groupWidth) / 2
    let iconX = startX
    let textX = startX + iconRect.width + gap - tb.minX
    let textOrigin = CGPoint(x: textX, y: iconRect.midY - tb.midY)
    let placedIcon = iconRect.offsetBy(dx: iconX, dy: 0)
    ctx.saveGState()
    if !dark {
        ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 26,
                      color: NSColor.black.withAlphaComponent(0.14).cgColor)
    }
    ctx.addPath(squircle(placedIcon))
    ctx.setFillColor(NSColor.white.cgColor)
    ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(squircle(placedIcon))
    ctx.clip()
    drawIconTile(in: placedIcon, ctx: ctx)
    ctx.restoreGState()
    ctx.textPosition = textOrigin
    CTLineDraw(line, ctx)

    save(rep, ctx, to: dark ? "wonday-lockup-dark.png" : "wonday-lockup-light.png", width: width, height: height)
}

renderAppIcon()
renderIconPreview()
renderWordmark(transparent: false)
renderWordmark(transparent: true)
renderLockup(dark: false)
renderLockup(dark: true)
print("rendered to \(outDir.path)")
