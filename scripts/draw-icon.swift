#!/usr/bin/env swift
// draw-icon.swift — render the bgbgone.app icon at a chosen pixel size.
// Usage: swift draw-icon.swift <size> <output.png>
//
// Uses Core Graphics + AppKit only (ships with macOS). Mirrors the design
// brief: white squircle tile, checkerboard "removed background" plate, blue
// portrait silhouette in front.
import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

guard CommandLine.arguments.count == 3,
      let size = Int(CommandLine.arguments[1])
else {
    fputs("usage: draw-icon.swift <size> <output.png>\n", stderr); exit(1)
}
let outURL = URL(fileURLWithPath: CommandLine.arguments[2])
let dim = CGFloat(size)

// MARK: - Drawing
guard let cs = CGColorSpace(name: CGColorSpace.sRGB),
      let ctx = CGContext(
        data: nil,
        width: size, height: size,
        bitsPerComponent: 8, bytesPerRow: 0,
        space: cs,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      )
else { fputs("CGContext failed\n", stderr); exit(1) }

// Flip into top-left-origin image coordinates so the math reads naturally.
ctx.translateBy(x: 0, y: dim)
ctx.scaleBy(x: 1, y: -1)

let tileRect = CGRect(x: 0, y: 0, width: dim, height: dim)

// Outer rounded squircle path. Apple's macOS 26 icon mask is ~22% radius.
let outerRadius = dim * 0.22
let outerPath = CGPath(roundedRect: tileRect, cornerWidth: outerRadius, cornerHeight: outerRadius, transform: nil)

// Clip everything to the outer mask first so antialiasing is clean.
ctx.saveGState()
ctx.addPath(outerPath); ctx.clip()

// Background gradient (top white → bottom soft blue-grey).
do {
    let colors: [CGColor] = [
        CGColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 1),
        CGColor(red: 0.91, green: 0.93, blue: 0.96, alpha: 1),
    ]
    let g = CGGradient(colorsSpace: cs, colors: colors as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(g, start: CGPoint(x: dim/2, y: 0), end: CGPoint(x: dim/2, y: dim), options: [])
}

// Inner card — checkerboard "removed background" plate (88% of tile, centered).
let cardInset = dim * 0.140
let cardRect = CGRect(x: cardInset, y: cardInset, width: dim - 2*cardInset, height: dim - 2*cardInset)
let cardRadius = dim * 0.11
let cardPath = CGPath(roundedRect: cardRect, cornerWidth: cardRadius, cornerHeight: cardRadius, transform: nil)

ctx.saveGState()
ctx.addPath(cardPath); ctx.clip()

// Checker pattern, scaled to icon size.
let checkSize = max(dim / 16, 2)
let cardOriginX = cardRect.minX
let cardOriginY = cardRect.minY
let cardW = cardRect.width
let cardH = cardRect.height
let darkColor = CGColor(red: 0.83, green: 0.85, blue: 0.89, alpha: 1)
let lightColor = CGColor(red: 1, green: 1, blue: 1, alpha: 1)

// Fill white first.
ctx.setFillColor(lightColor)
ctx.fill(cardRect)
ctx.setFillColor(darkColor)
var row = 0
var y = cardOriginY
while y < cardOriginY + cardH {
    let xOffset = row.isMultiple(of: 2) ? CGFloat(0) : checkSize
    var x = cardOriginX + xOffset
    while x < cardOriginX + cardW {
        ctx.fill(CGRect(x: x, y: y, width: checkSize, height: checkSize))
        x += checkSize * 2
    }
    y += checkSize
    row += 1
}

// Card stroke
ctx.setLineWidth(max(1, dim / 512))
ctx.setStrokeColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.08))
ctx.addPath(cardPath); ctx.strokePath()

ctx.restoreGState() // un-clip card

// Subject — portrait silhouette in blue, positioned over the card.
// Soft shadow first, then the subject on top.
let headCx = dim * 0.50
let headCy = dim * 0.405
let headR  = dim * 0.144
let bodyTop = dim * 0.58
let bodyBottom = dim * 0.86
let bodyHalfW = dim * 0.254

func drawSilhouette(in ctx: CGContext, color: CGColor) {
    ctx.saveGState()
    ctx.setFillColor(color)
    // Head
    ctx.fillEllipse(in: CGRect(x: headCx - headR, y: headCy - headR, width: 2*headR, height: 2*headR))
    // Shoulders/torso — rounded top, flat bottom
    let bodyPath = CGMutablePath()
    let topR = (bodyBottom - bodyTop) * 0.65
    bodyPath.move(to: CGPoint(x: headCx - bodyHalfW, y: bodyBottom))
    bodyPath.addLine(to: CGPoint(x: headCx - bodyHalfW, y: bodyTop + topR))
    bodyPath.addQuadCurve(to: CGPoint(x: headCx + bodyHalfW, y: bodyTop + topR),
                          control: CGPoint(x: headCx, y: bodyTop - topR * 0.2))
    bodyPath.addLine(to: CGPoint(x: headCx + bodyHalfW, y: bodyBottom))
    bodyPath.closeSubpath()
    ctx.addPath(bodyPath); ctx.fillPath()
    ctx.restoreGState()
}

// Drop shadow underneath the subject.
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -dim * 0.014), blur: dim * 0.028, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.22))
drawSilhouette(in: ctx, color: CGColor(red: 0.039, green: 0.40, blue: 0.85, alpha: 1))
ctx.restoreGState()

// Subject foreground with vertical gradient overlay.
ctx.saveGState()
let subjectPath = CGMutablePath()
subjectPath.addEllipse(in: CGRect(x: headCx - headR, y: headCy - headR, width: 2*headR, height: 2*headR))
let topR = (bodyBottom - bodyTop) * 0.65
let bodyPath = CGMutablePath()
bodyPath.move(to: CGPoint(x: headCx - bodyHalfW, y: bodyBottom))
bodyPath.addLine(to: CGPoint(x: headCx - bodyHalfW, y: bodyTop + topR))
bodyPath.addQuadCurve(to: CGPoint(x: headCx + bodyHalfW, y: bodyTop + topR),
                      control: CGPoint(x: headCx, y: bodyTop - topR * 0.2))
bodyPath.addLine(to: CGPoint(x: headCx + bodyHalfW, y: bodyBottom))
bodyPath.closeSubpath()
subjectPath.addPath(bodyPath)
ctx.addPath(subjectPath); ctx.clip()

let subjectColors: [CGColor] = [
    CGColor(red: 0.229, green: 0.65, blue: 1.00, alpha: 1),
    CGColor(red: 0.00,  green: 0.36, blue: 0.78, alpha: 1),
]
let subjectGradient = CGGradient(colorsSpace: cs, colors: subjectColors as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(subjectGradient,
                       start: CGPoint(x: dim/2, y: dim * 0.27),
                       end:   CGPoint(x: dim/2, y: dim * 0.88),
                       options: [])
ctx.restoreGState()

ctx.restoreGState() // outer mask

// MARK: - Export
guard let cgImage = ctx.makeImage() else { fputs("makeImage failed\n", stderr); exit(1) }
guard let dest = CGImageDestinationCreateWithURL(outURL as CFURL, UTType.png.identifier as CFString, 1, nil)
else { fputs("CGImageDestination failed\n", stderr); exit(1) }
CGImageDestinationAddImage(dest, cgImage, nil)
guard CGImageDestinationFinalize(dest) else { fputs("finalize failed\n", stderr); exit(1) }

print("wrote \(outURL.path) (\(size)×\(size))")
