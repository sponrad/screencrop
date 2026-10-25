// Draws the 1024 x 1024 app icon: a monitor whose cracked right strip is cropped away.
// Usage: swift scripts/make_icon.swift Resources/AppIcon.png

import AppKit

let size = 1024
let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.png"

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func linearGradient(_ ctx: CGContext, _ colors: [CGColor], from: CGPoint, to: CGPoint) {
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors as CFArray, locations: nil)!
    ctx.drawLinearGradient(gradient, start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}

func roundedRect(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

let ctx = CGContext(
    data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
)!

// Background tile on the standard macOS icon grid (824 pt tile inside a 1024 canvas).
let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: rgb(0x000000, 0.35))
ctx.addPath(roundedRect(tile, 185))
ctx.setFillColor(rgb(0x2A3350))
ctx.fillPath()
ctx.restoreGState()
ctx.saveGState()
ctx.addPath(roundedRect(tile, 185))
ctx.clip()
linearGradient(ctx, [rgb(0x3A4A78), rgb(0x161B2E)], from: CGPoint(x: 512, y: 924), to: CGPoint(x: 512, y: 100))
ctx.restoreGState()

// Stand.
ctx.setFillColor(rgb(0xB8BECC))
ctx.addPath(roundedRect(CGRect(x: 382, y: 232, width: 260, height: 30), 15))
ctx.fillPath()
ctx.move(to: CGPoint(x: 462, y: 262))
ctx.addLine(to: CGPoint(x: 562, y: 262))
ctx.addLine(to: CGPoint(x: 542, y: 336))
ctx.addLine(to: CGPoint(x: 482, y: 336))
ctx.closePath()
ctx.setFillColor(rgb(0x9AA1B2))
ctx.fillPath()

// Bezel.
let bezel = CGRect(x: 180, y: 320, width: 664, height: 470)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 20, color: rgb(0x000000, 0.45))
ctx.addPath(roundedRect(bezel, 40))
ctx.setFillColor(rgb(0x1B1E26))
ctx.fillPath()
ctx.restoreGState()
ctx.addPath(roundedRect(bezel.insetBy(dx: 2, dy: 2), 38))
ctx.setStrokeColor(rgb(0x5A6175))
ctx.setLineWidth(4)
ctx.strokePath()

let screen = bezel.insetBy(dx: 26, dy: 26)
let usableWidth = screen.width * 0.74
let usable = CGRect(x: screen.minX, y: screen.minY, width: usableWidth, height: screen.height)
let dead = CGRect(x: usable.maxX, y: screen.minY, width: screen.width - usableWidth, height: screen.height)

// Working area: wallpaper, menu bar and two windows.
ctx.saveGState()
ctx.addPath(roundedRect(screen, 16))
ctx.clip()
ctx.saveGState()
ctx.clip(to: usable)
linearGradient(ctx, [rgb(0x7FD6FF), rgb(0x8E7CFF)], from: CGPoint(x: usable.minX, y: usable.maxY), to: CGPoint(x: usable.maxX, y: usable.minY))
ctx.setFillColor(rgb(0xFFFFFF, 0.55))
ctx.fill(CGRect(x: usable.minX, y: usable.maxY - 22, width: usable.width, height: 22))
ctx.setFillColor(rgb(0xFFFFFF, 0.92))
ctx.addPath(roundedRect(CGRect(x: usable.minX + 40, y: usable.minY + 110, width: 250, height: 190), 14))
ctx.fillPath()
ctx.setFillColor(rgb(0xFFFFFF, 0.75))
ctx.addPath(roundedRect(CGRect(x: usable.minX + 220, y: usable.minY + 50, width: 220, height: 160), 14))
ctx.fillPath()
ctx.restoreGState()

// Dead strip with the crack.
ctx.setFillColor(rgb(0x050608))
ctx.fill(dead)
ctx.clip(to: dead.insetBy(dx: 0, dy: 0))
let impact = CGPoint(x: dead.midX + 18, y: dead.maxY - 120)
let branches: [[CGPoint]] = [
    [impact, CGPoint(x: impact.x - 30, y: impact.y + 40), CGPoint(x: impact.x - 22, y: impact.y + 80), CGPoint(x: impact.x - 52, y: impact.y + 140)],
    [impact, CGPoint(x: impact.x + 34, y: impact.y + 26), CGPoint(x: impact.x + 70, y: impact.y + 70)],
    [impact, CGPoint(x: impact.x + 40, y: impact.y - 30), CGPoint(x: impact.x + 30, y: impact.y - 90), CGPoint(x: impact.x + 64, y: impact.y - 150)],
    [impact, CGPoint(x: impact.x - 26, y: impact.y - 44), CGPoint(x: impact.x - 14, y: impact.y - 110), CGPoint(x: impact.x - 44, y: impact.y - 180),
     CGPoint(x: impact.x - 30, y: impact.y - 250), CGPoint(x: impact.x - 58, y: impact.y - 320)],
    [impact, CGPoint(x: impact.x - 50, y: impact.y - 8), CGPoint(x: impact.x - 80, y: impact.y + 18)],
    [CGPoint(x: impact.x - 14, y: impact.y - 110), CGPoint(x: impact.x + 24, y: impact.y - 160), CGPoint(x: impact.x + 14, y: impact.y - 220)],
]
ctx.setLineCap(.round)
ctx.setLineJoin(.round)
for (width, alpha) in [(CGFloat(9), CGFloat(0.18)), (4, 0.9)] {
    ctx.setLineWidth(width)
    ctx.setStrokeColor(rgb(0xE8EEFF, alpha))
    for branch in branches {
        ctx.addLines(between: branch)
        ctx.strokePath()
    }
}
ctx.setFillColor(rgb(0xFFFFFF, 0.9))
ctx.fillEllipse(in: CGRect(x: impact.x - 7, y: impact.y - 7, width: 14, height: 14))
ctx.restoreGState()

// Crop corners around the working area.
let crop = usable.insetBy(dx: -8, dy: -8)
let arm: CGFloat = 70
ctx.setStrokeColor(rgb(0xFFC93C))
ctx.setLineWidth(14)
ctx.setLineCap(.round)
ctx.setLineJoin(.round)
for (corner, dx, dy) in [
    (CGPoint(x: crop.minX, y: crop.maxY), arm, -arm),
    (CGPoint(x: crop.maxX, y: crop.maxY), -arm, -arm),
    (CGPoint(x: crop.minX, y: crop.minY), arm, arm),
    (CGPoint(x: crop.maxX, y: crop.minY), -arm, arm),
] {
    ctx.addLines(between: [CGPoint(x: corner.x + dx, y: corner.y), corner, CGPoint(x: corner.x, y: corner.y + dy)])
    ctx.strokePath()
}

let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
print("Wrote \(output)")
