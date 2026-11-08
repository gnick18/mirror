// Draws the app icon: the phone remote's home-screen icon (portal/web/apple-touch-icon.png)
// redrawn at 1024 px with no transparency.
//
// Run from the ios folder:
//   swift tools/make_icon.swift McQueenMirror/Assets.xcassets/AppIcon.appiconset/AppIcon.png

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let unit = CGFloat(size) / 180  // the web icon was drawn on a 180 px grid, so the numbers below use it
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
ctx.translateBy(x: 0, y: CGFloat(size))
ctx.scaleBy(x: unit, y: -unit)  // top-left origin, in 180 px units

func gray(_ level: CGFloat) -> CGColor {
    CGColor(colorSpace: space, components: [level / 255, level / 255, level / 255, 1])!
}

func bar(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ level: CGFloat) {
    ctx.setFillColor(gray(level))
    let r = min(h / 2, 1.5)
    ctx.addPath(CGPath(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerWidth: r, cornerHeight: r, transform: nil))
    ctx.fillPath()
}

func streak(from a: CGPoint, to b: CGPoint, width: CGFloat, _ level: CGFloat) {
    ctx.setStrokeColor(gray(level))
    ctx.setLineWidth(width)
    ctx.setLineCap(.round)
    ctx.move(to: a)
    ctx.addLine(to: b)
    ctx.strokePath()
}

// Near-black background, a touch lighter at the top.
let background = CGGradient(colorsSpace: space, colors: [gray(30), gray(4)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(background, start: .zero, end: CGPoint(x: 0, y: 180), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

// Grey floor line under the mirror.
ctx.setFillColor(gray(115))
ctx.fill(CGRect(x: 44, y: 161, width: 92, height: 3))

// The mirror: a tall, narrow white outline with nearly square corners.
ctx.setStrokeColor(gray(250))
ctx.setLineWidth(4)
ctx.addPath(CGPath(roundedRect: CGRect(x: 62, y: 18, width: 56, height: 134), cornerWidth: 2.5, cornerHeight: 2.5, transform: nil))
ctx.strokePath()

// Clock and date at the top left, weather at the top right.
bar(68, 27, 24, 8, 255)
bar(68, 39, 18, 3, 151)
ctx.setFillColor(gray(150))
ctx.fillEllipse(in: CGRect(x: 102.5, y: 26.5, width: 9, height: 9))

// Two faint reflection streaks in the empty middle.
streak(from: CGPoint(x: 96.5, y: 76), to: CGPoint(x: 72.5, y: 103.5), width: 3.6, 86)
streak(from: CGPoint(x: 107, y: 87), to: CGPoint(x: 84.5, y: 111), width: 2.6, 60)

// Agenda lines along the bottom.
bar(68, 128, 36, 3, 126)
bar(68, 135, 30, 3, 126)
bar(68, 142, 24, 3, 126)

let out = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "AppIcon.png")
let dest = CGImageDestinationCreateWithURL(out as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
guard CGImageDestinationFinalize(dest) else { fatalError("could not write \(out.path)") }
print("wrote \(out.path)")
