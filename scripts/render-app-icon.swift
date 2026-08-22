#!/usr/bin/swift

import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: render-app-icon.swift OUTPUT_ICNS\n".utf8))
    exit(2)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])

let variants: [(type: String, pixels: Int)] = [
    ("icp4", 16),
    ("icp5", 32),
    ("icp6", 64),
    ("ic07", 128),
    ("ic08", 256),
    ("ic09", 512),
    ("ic10", 1024),
]

func roundedRect(_ rect: CGRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func renderIcon(pixels: Int) throws -> Data {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: bitmap)
    else { throw CocoaError(.fileWriteUnknown) }

    let scale = CGFloat(pixels) / 1024
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.cgContext.scaleBy(x: scale, y: scale)
    context.cgContext.setShouldAntialias(true)

    let background = roundedRect(CGRect(x: 54, y: 54, width: 916, height: 916), radius: 220)
    let backgroundGradient = NSGradient(
        starting: NSColor(red: 0.16, green: 0.18, blue: 0.21, alpha: 1),
        ending: NSColor(red: 0.055, green: 0.065, blue: 0.08, alpha: 1)
    )!
    backgroundGradient.draw(in: background, angle: -90)

    NSColor.white.withAlphaComponent(0.10).setStroke()
    background.lineWidth = 8
    background.stroke()

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.32)
    shadow.shadowBlurRadius = 34
    shadow.shadowOffset = NSSize(width: 0, height: -15)
    shadow.set()

    let bubble = roundedRect(CGRect(x: 194, y: 270, width: 636, height: 484), radius: 126)
    NSColor(red: 0.96, green: 0.96, blue: 0.94, alpha: 1).setFill()
    bubble.fill()

    let tail = NSBezierPath()
    tail.move(to: CGPoint(x: 286, y: 310))
    tail.line(to: CGPoint(x: 250, y: 190))
    tail.line(to: CGPoint(x: 398, y: 294))
    tail.close()
    tail.fill()

    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.cgContext.scaleBy(x: scale, y: scale)

    let ink = NSColor(red: 0.105, green: 0.12, blue: 0.145, alpha: 1)
    ink.setFill()
    roundedRect(CGRect(x: 294, y: 558, width: 436, height: 48), radius: 24).fill()
    roundedRect(CGRect(x: 294, y: 442, width: 344, height: 48), radius: 24).fill()

    NSGraphicsContext.restoreGraphicsState()
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    return png
}

func appendBigEndian(_ value: UInt32, to data: inout Data) {
    var encoded = value.bigEndian
    withUnsafeBytes(of: &encoded) { data.append(contentsOf: $0) }
}

var elements = Data()
for variant in variants {
    let png = try renderIcon(pixels: variant.pixels)
    elements.append(Data(variant.type.utf8))
    appendBigEndian(UInt32(png.count + 8), to: &elements)
    elements.append(png)
}

var icns = Data("icns".utf8)
appendBigEndian(UInt32(elements.count + 8), to: &icns)
icns.append(elements)
try icns.write(to: outputURL, options: .atomic)
