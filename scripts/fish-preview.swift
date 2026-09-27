// Renders every fishing sprite into a contact sheet for reviewing pixel art.
//   swiftc -o build/fish-preview dancove/Fishing/PixelSprite.swift dancove/Fishing/FishCatalog.swift scripts/fish-preview.swift
//   build/fish-preview build/fish-sheet.png [scale]
import AppKit

let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "fish-sheet.png"
let scale = CommandLine.arguments.count > 2 ? Int(CommandLine.arguments[2]) ?? 8 : 8

let species = FishCatalog.all
for fish in species {
    let widths = fish.sprite.rows.map(\.count)
    if (widths.max() ?? 0) > 22 || fish.sprite.rows.count > 14 {
        print("⚠️ \(fish.id): \(widths.max() ?? 0)x\(fish.sprite.rows.count) exceeds 22x14")
    }
}

let columns = 6
let cellW = PixelSprite.canvasWidth * scale + 24
let cellH = PixelSprite.canvasHeight * scale + 44
let rows = (species.count + columns - 1) / columns
let size = NSSize(width: columns * cellW, height: rows * cellH)
let image = NSImage(size: size)
image.lockFocus()
NSColor.black.setFill()
NSRect(origin: .zero, size: size).fill()
NSGraphicsContext.current?.imageInterpolation = .none

for (index, fish) in species.enumerated() {
    let col = index % columns
    let row = index / columns
    let x = CGFloat(col * cellW + 12)
    let y = size.height - CGFloat((row + 1) * cellH) + 34
    let tint = NSColor(
        red: CGFloat((fish.rarity.hex >> 16) & 0xFF) / 255,
        green: CGFloat((fish.rarity.hex >> 8) & 0xFF) / 255,
        blue: CGFloat(fish.rarity.hex & 0xFF) / 255,
        alpha: 1
    )
    let card = NSRect(x: x - 6, y: y - 6, width: CGFloat(PixelSprite.canvasWidth * scale + 12), height: CGFloat(PixelSprite.canvasHeight * scale + 12))
    tint.withAlphaComponent(0.1).setFill()
    NSBezierPath(roundedRect: card, xRadius: 10, yRadius: 10).fill()
    if let cg = fish.sprite.makeImage() {
        let rect = NSRect(x: x, y: y, width: CGFloat(cg.width * scale), height: CGFloat(cg.height * scale))
        NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height)).draw(in: rect)
    }
    let label = "\(fish.name) · \(fish.rarity.title)" as NSString
    label.draw(at: NSPoint(x: x - 4, y: y - 30), withAttributes: [
        .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
        .foregroundColor: tint,
    ])
}
image.unlockFocus()

let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
print("Wrote \(output) (\(species.count) sprites)")
