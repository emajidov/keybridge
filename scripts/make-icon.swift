// Renders the KeyBridge app icon and writes Resources/AppIcon.icns and docs/icon.png.
// Usage: swift scripts/make-icon.swift
import AppKit

func render(_ px: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: 1024, height: 1024)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high

    // macOS app icon grid: 824pt rounded square centred on a 1024pt canvas.
    let body = NSRect(x: 100, y: 100, width: 824, height: 824)
    let bodyPath = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor(white: 0, alpha: 0.35)
    shadow.shadowOffset = NSSize(width: 0, height: -12)
    shadow.shadowBlurRadius = 24
    shadow.set()
    NSColor.black.setFill()
    bodyPath.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(starting: NSColor(red: 0.27, green: 0.55, blue: 1.0, alpha: 1),
               ending: NSColor(red: 0.07, green: 0.20, blue: 0.62, alpha: 1))!.draw(in: bodyPath, angle: -90)

    func keycap(_ rect: NSRect, _ label: String, _ size: CGFloat) {
        let base = NSBezierPath(roundedRect: rect, xRadius: 64, yRadius: 64)
        NSColor(red: 0.72, green: 0.76, blue: 0.84, alpha: 1).setFill()
        base.fill()
        let top = NSRect(x: rect.minX + 14, y: rect.minY + 30, width: rect.width - 28, height: rect.height - 42)
        let topPath = NSBezierPath(roundedRect: top, xRadius: 52, yRadius: 52)
        NSGradient(starting: .white, ending: NSColor(red: 0.90, green: 0.92, blue: 0.96, alpha: 1))!.draw(in: topPath, angle: -90)
        let p = NSMutableParagraphStyle(); p.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: size, weight: .semibold),
            .foregroundColor: NSColor(red: 0.10, green: 0.16, blue: 0.30, alpha: 1), .paragraphStyle: p]
        let text = NSAttributedString(string: label, attributes: attrs)
        let h = text.size().height
        text.draw(in: NSRect(x: top.minX, y: top.midY - h / 2, width: top.width, height: h))
    }
    keycap(NSRect(x: 190, y: 540, width: 300, height: 270), "ctrl", 104)
    keycap(NSRect(x: 534, y: 214, width: 300, height: 270), "⌘", 150)

    // Bridge arrow from ctrl to ⌘.
    let arrow = NSBezierPath()
    arrow.move(to: NSPoint(x: 340, y: 500))
    arrow.curve(to: NSPoint(x: 492, y: 350), controlPoint1: NSPoint(x: 340, y: 400), controlPoint2: NSPoint(x: 400, y: 350))
    arrow.lineWidth = 34
    arrow.lineCapStyle = .round
    NSColor.white.setStroke()
    arrow.stroke()
    let head = NSBezierPath()
    head.move(to: NSPoint(x: 520, y: 350))
    head.line(to: NSPoint(x: 462, y: 402))
    head.line(to: NSPoint(x: 462, y: 298))
    head.close()
    NSColor.white.setFill()
    head.fill()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for pt in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(pt)x\(pt).png" : "icon_\(pt)x\(pt)@2x.png"
        try! render(pt * scale).representation(using: .png, properties: [:])!.write(to: iconset.appendingPathComponent(name))
    }
}
try! render(512).representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent("docs/icon.png"))
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("Resources/AppIcon.icns").path]
try! p.run(); p.waitUntilExit()
precondition(p.terminationStatus == 0, "iconutil failed")
try? FileManager.default.removeItem(at: iconset)
print("Wrote Resources/AppIcon.icns and docs/icon.png")
