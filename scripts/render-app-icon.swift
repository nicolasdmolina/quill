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

/// Alpha silhouette shared by the other Dock icons. Taken from a system app
/// icon, which macOS already clips to the squircle, with the artwork removed.
func systemSquircleMask() -> NSImage {
    let icon = NSWorkspace.shared.icon(forFile: "/System/Applications/Notes.app")
    guard
        let source = icon.representations.max(by: { $0.pixelsWide < $1.pixelsWide })
    else {
        fputs("could not read the system icon shape\n", stderr)
        exit(1)
    }
    var rect = NSRect(x: 0, y: 0, width: source.pixelsWide, height: source.pixelsHigh)
    guard let cg = source.cgImage(forProposedRect: &rect, context: nil, hints: nil) else {
        fputs("could not read the system icon shape\n", stderr)
        exit(1)
    }
    let width = cg.width
    let height = cg.height
    guard
        let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    else {
        fputs("could not allocate the icon mask\n", stderr)
        exit(1)
    }
    let bounds = CGRect(x: 0, y: 0, width: width, height: height)
    ctx.clip(to: bounds, mask: cg)
    ctx.setFillColor(CGColor(gray: 1, alpha: 1))
    ctx.fill(bounds)
    guard let masked = ctx.makeImage() else {
        fputs("could not build the icon mask\n", stderr)
        exit(1)
    }
    return NSImage(cgImage: masked, size: NSSize(width: canvas, height: canvas))
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
    let bounds = NSRect(x: 0, y: 0, width: canvas, height: canvas)
    background.setFill()
    bounds.fill()
    image.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: 1)
    systemSquircleMask().draw(in: bounds, from: .zero, operation: .destinationIn, fraction: 1)
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
