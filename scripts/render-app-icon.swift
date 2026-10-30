import AppKit

/// Draws the menu-bar feather (macos/Resources/feather.svg, the same paths as
/// MenuBarController.featherSVG) onto the two app-icon plates. Light mode is
/// dark ink on a light plate; dark mode is light ink on a dark plate, which is
/// what a template status icon becomes in each appearance.

let repoRoot = URL(fileURLWithPath: CommandLine.arguments[1])
let svgURL = repoRoot.appendingPathComponent("macos/Resources/feather.svg")
let outDir = repoRoot.appendingPathComponent(
    "macos/Resources/Assets.xcassets/AppIcon.appiconset"
)

guard var svg = try? String(contentsOf: svgURL, encoding: .utf8) else {
    fputs("missing \(svgURL.path)\n", stderr)
    exit(1)
}

let canvas: CGFloat = 1024
let inkBox: CGFloat = 620

func plate(_ hex: String) -> NSColor {
    var value: UInt64 = 0
    Scanner(string: hex).scanHexInt64(&value)
    return NSColor(
        calibratedRed: CGFloat((value >> 16) & 0xFF) / 255,
        green: CGFloat((value >> 8) & 0xFF) / 255,
        blue: CGFloat(value & 0xFF) / 255,
        alpha: 1
    )
}

func render(stroke: String) -> NSImage {
    let colored = svg.replacingOccurrences(of: "currentColor", with: stroke)
    guard let data = colored.data(using: .utf8), let feather = NSImage(data: data) else {
        fputs("could not draw feather\n", stderr)
        exit(1)
    }
    feather.size = NSSize(width: inkBox, height: inkBox)
    let image = NSImage(size: NSSize(width: canvas, height: canvas))
    image.lockFocus()
    let origin = (canvas - inkBox) / 2
    feather.draw(
        in: NSRect(x: origin, y: origin, width: inkBox, height: inkBox),
        from: .zero,
        operation: .sourceOver,
        fraction: 1
    )
    image.unlockFocus()
    return image
}

func png(_ image: NSImage, background: NSColor, to url: URL) {
    guard
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 1024,
            pixelsHigh: 1024,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
    else {
        fputs("could not allocate \(url.path)\n", stderr)
        exit(1)
    }
    rep.size = NSSize(width: canvas, height: canvas)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    background.setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: canvas, height: canvas)).fill()
    image.draw(
        in: NSRect(x: 0, y: 0, width: canvas, height: canvas),
        from: .zero,
        operation: .sourceOver,
        fraction: 1
    )
    NSGraphicsContext.restoreGraphicsState()
    guard let data = rep.representation(using: .png, properties: [:]) else {
        fputs("could not encode \(url.path)\n", stderr)
        exit(1)
    }
    try! data.write(to: url)
}

let light = outDir.appendingPathComponent("AppIcon-light.png")
let dark = outDir.appendingPathComponent("AppIcon-dark.png")
png(render(stroke: "#1C1C1E"), background: plate("F4F4F5"), to: light)
png(render(stroke: "#F4F4F5"), background: plate("1C1C1E"), to: dark)
print(light.path)
print(dark.path)
