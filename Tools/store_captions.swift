// Put a headline above each App Store screenshot, in the app's font and colours.
// Usage: swift Tools/store_captions.swift            (all sets present)
//        swift Tools/store_captions.swift iphone-6.3 (one device folder)
// Input:  AppStore/screenshots/<device>/<lang>/NN-name.png from Tools/store_screenshots*.sh
// Output: AppStore/screenshots/captioned/<device>/<lang>/NN-name.png at the same pixel size.
// Headlines live in AppStore/captions.json ({"vi": {"01-quick-log": ["title", "subtitle"]}, ...}).
import AppKit
import CoreText

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let shots = root.appendingPathComponent("AppStore/screenshots")
let fonts = root.appendingPathComponent("BabyCare/Resources/Fonts")
for name in ["BeVietnamPro-Bold", "BeVietnamPro-Medium"] {
    CTFontManagerRegisterFontsForURL(fonts.appendingPathComponent("\(name).ttf") as CFURL, .process, nil)
}

let captions = try JSONDecoder().decode([String: [String: [String]]].self,
                                        from: Data(contentsOf: root.appendingPathComponent("AppStore/captions.json")))
let devices = CommandLine.arguments.count > 1 ? Array(CommandLine.arguments.dropFirst()) : ["iphone-6.3", "iphone-6.9", "ipad-13", "iphone-duo"]
let accent = NSColor(srgbRed: 0x14 / 255, green: 0x6C / 255, blue: 0x60 / 255, alpha: 1) // AccentColor, light
let deep = NSColor(srgbRed: 0x0E / 255, green: 0x4F / 255, blue: 0x46 / 255, alpha: 1)

/// One centred line, shrunk (down to 75 %) until it fits, so every screenshot in a set gets the same layout.
func line(_ string: String, font name: String, size: CGFloat, color: NSColor, width: CGFloat) -> NSAttributedString {
    var points = size
    while true {
        let text = NSAttributedString(string: string, attributes: [.font: NSFont(name: name, size: points)!, .foregroundColor: color])
        if text.size().width <= width || points <= size * 0.75 {
            if text.size().width > width { print("still too wide: \(string)") }
            return text
        }
        points -= size * 0.02
    }
}

func drawCentered(_ text: NSAttributedString, bottom y: CGFloat, in width: CGFloat) {
    text.draw(at: NSPoint(x: (width - text.size().width) / 2, y: y))
}

func render(_ shot: NSImage, size: NSSize, title: String, subtitle: String) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = size
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    defer { NSGraphicsContext.restoreGraphicsState() }

    NSGradient(starting: accent, ending: deep)!.draw(in: NSRect(origin: .zero, size: size), angle: -90)

    // Headline on top; the short side sets the type size so portrait and landscape read alike.
    let unit = min(size.width, size.height)
    let landscape = size.width > size.height
    let margin = unit * 0.06
    let textWidth = size.width - margin * 2
    let titleSize = unit * (landscape ? 0.056 : 0.07), subtitleSize = unit * (landscape ? 0.032 : 0.042)
    let titleLine = line(title, font: "BeVietnamPro-Bold", size: titleSize, color: .white, width: textWidth)
    let subtitleLine = line(subtitle, font: "BeVietnamPro-Medium", size: subtitleSize, color: .white.withAlphaComponent(0.88), width: textWidth)
    // Fixed line positions from the full sizes, whatever a line shrank to.
    let titleBottom = size.height - unit * 0.05 - titleSize * 1.1
    let subtitleBottom = titleBottom - subtitleSize * 1.55
    drawCentered(titleLine, bottom: titleBottom, in: size.width)
    drawCentered(subtitleLine, bottom: subtitleBottom, in: size.width)

    // The screenshot fills the rest, whole, with rounded corners and a soft shadow.
    let available = NSSize(width: size.width - margin * 2, height: subtitleBottom - unit * 0.05 - unit * 0.04)
    let scale = min(available.width / shot.size.width, available.height / shot.size.height)
    let frame = NSRect(x: (size.width - shot.size.width * scale) / 2, y: unit * 0.04,
                       width: shot.size.width * scale, height: shot.size.height * scale)
    let path = NSBezierPath(roundedRect: frame, xRadius: unit * 0.045, yRadius: unit * 0.045)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.shadowBlurRadius = unit * 0.03
    shadow.shadowOffset = NSSize(width: 0, height: -unit * 0.008)
    shadow.set()
    NSColor.white.setFill()
    path.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.saveGraphicsState()
    path.addClip()
    shot.draw(in: frame)
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

var written = 0
for device in devices {
    for (lang, lines) in captions.sorted(by: { $0.key < $1.key }) {
        let input = shots.appendingPathComponent("\(device)/\(lang)")
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: input.path) else { continue }
        let output = shots.appendingPathComponent("captioned/\(device)/\(lang)")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        for file in files.sorted() where file.hasSuffix(".png") {
            let key = String(file.dropLast(4))
            guard let line = lines[key], line.count == 2 else { print("no caption for \(lang)/\(key), skipped"); continue }
            guard let shot = NSImage(contentsOf: input.appendingPathComponent(file)),
                  let pixels = shot.representations.first else { continue }
            // Draw at the screenshot's pixel size, not its point size.
            let size = NSSize(width: pixels.pixelsWide, height: pixels.pixelsHigh)
            shot.size = size
            let rep = render(shot, size: size, title: line[0], subtitle: line[1])
            try rep.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(file))
            written += 1
        }
    }
}
print("wrote \(written) captioned screenshots to \(shots.appendingPathComponent("captioned").path)")
