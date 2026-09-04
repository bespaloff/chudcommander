#!/usr/bin/env swift

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

guard CommandLine.arguments.count == 3 else {
    fputs("Usage: prepare-icon.swift <input.png> <output.png>\n", stderr)
    exit(2)
}

let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])

guard
    let source = CGImageSourceCreateWithURL(inputURL as CFURL, nil),
    let inputImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
else {
    fputs("Could not read \(inputURL.path)\n", stderr)
    exit(1)
}

let width = inputImage.width
let height = inputImage.height
let bytesPerPixel = 4
let bytesPerRow = width * bytesPerPixel
var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
var cleanedImage: CGImage?

pixels.withUnsafeMutableBytes { storage in
    let buffer = storage.bindMemory(to: UInt8.self)
    guard let context = CGContext(
        data: storage.baseAddress,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue |
            CGBitmapInfo.byteOrder32Big.rawValue
    ) else {
        return
    }

    context.draw(inputImage, in: CGRect(x: 0, y: 0, width: width, height: height))

    // Legacy icon sources could contain an inset squircle over a pale
    // transparency preview. Identify only pale pixels connected to the canvas
    // edge so older sources remain compatible while full-bleed sources pass
    // through unchanged.
    func isExteriorBackground(_ pixel: Int) -> Bool {
        let offset = pixel * bytesPerPixel
        let red = Int(buffer[offset])
        let green = Int(buffer[offset + 1])
        let blue = Int(buffer[offset + 2])
        let darkest = min(red, green, blue)
        let lightest = max(red, green, blue)
        return darkest >= 188 && lightest - darkest <= 48
    }

    var exterior = [UInt8](repeating: 0, count: width * height)
    var queue: [Int] = []
    queue.reserveCapacity(width * height / 5)

    func enqueueIfBackground(_ pixel: Int) {
        guard exterior[pixel] == 0, isExteriorBackground(pixel) else { return }
        exterior[pixel] = 1
        queue.append(pixel)
    }

    for x in 0..<width {
        enqueueIfBackground(x)
        enqueueIfBackground((height - 1) * width + x)
    }
    for y in 0..<height {
        enqueueIfBackground(y * width)
        enqueueIfBackground(y * width + width - 1)
    }

    var cursor = 0
    while cursor < queue.count {
        let pixel = queue[cursor]
        cursor += 1
        let x = pixel % width
        let y = pixel / width

        if x > 0 { enqueueIfBackground(pixel - 1) }
        if x + 1 < width { enqueueIfBackground(pixel + 1) }
        if y > 0 { enqueueIfBackground(pixel - width) }
        if y + 1 < height { enqueueIfBackground(pixel + width) }
    }

    // Extend a legacy icon's blue background through the whole square canvas.
    // Full-bleed regenerated sources have an empty queue and remain untouched.
    for pixel in queue {
        let offset = pixel * bytesPerPixel
        let x = pixel % width
        let y = pixel / width
        let horizontal = Double(x) / Double(max(width - 1, 1))
        let vertical = Double(y) / Double(max(height - 1, 1))

        let topLeft = (red: 17.0, green: 102.0, blue: 255.0)
        let topRight = (red: 19.0, green: 211.0, blue: 233.0)
        let bottomLeft = (red: 7.0, green: 42.0, blue: 188.0)
        let bottomRight = (red: 8.0, green: 119.0, blue: 239.0)

        func interpolate(_ a: Double, _ b: Double, amount: Double) -> Double {
            a + (b - a) * amount
        }

        let topRed = interpolate(topLeft.red, topRight.red, amount: horizontal)
        let topGreen = interpolate(topLeft.green, topRight.green, amount: horizontal)
        let topBlue = interpolate(topLeft.blue, topRight.blue, amount: horizontal)
        let bottomRed = interpolate(bottomLeft.red, bottomRight.red, amount: horizontal)
        let bottomGreen = interpolate(bottomLeft.green, bottomRight.green, amount: horizontal)
        let bottomBlue = interpolate(bottomLeft.blue, bottomRight.blue, amount: horizontal)

        buffer[offset] = UInt8(interpolate(topRed, bottomRed, amount: vertical).rounded())
        buffer[offset + 1] = UInt8(interpolate(topGreen, bottomGreen, amount: vertical).rounded())
        buffer[offset + 2] = UInt8(interpolate(topBlue, bottomBlue, amount: vertical).rounded())
        buffer[offset + 3] = 255
    }

    cleanedImage = context.makeImage()
}

guard
    let cleanedImage,
    let destination = CGImageDestinationCreateWithURL(
        outputURL as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
    )
else {
    fputs("Could not prepare icon image\n", stderr)
    exit(1)
}

CGImageDestinationAddImage(destination, cleanedImage, nil)
guard CGImageDestinationFinalize(destination) else {
    fputs("Could not write \(outputURL.path)\n", stderr)
    exit(1)
}
