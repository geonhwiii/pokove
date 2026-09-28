// Draws the background of the disk image scripts/package.sh builds: Config/dmg-background.png,
// 600×400. Run from the repo root: swift scripts/make-dmg-background.swift
//
// A lab floor in pixel art on a 150×100 grid, like the table the games' starters wait on: three
// Poké Balls in grass, fire and water colors along the bottom, and a dotted arrow from where the app
// sits (left) to Applications (right). Config/dmg-settings.py puts the two icons over it.
import AppKit

let columns = 150, rows = 100
let pointSize = CGSize(width: 600, height: 400)

private func rgb(_ hex: UInt32) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

/// The scene at one pixel per cell, y growing downward.
final class Grid {
    let context: CGContext

    init() {
        context = CGContext(data: nil, width: columns, height: rows, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.translateBy(x: 0, y: CGFloat(rows))
        context.scaleBy(x: 1, y: -1)
    }

    func fill(_ x: Int, _ y: Int, _ width: Int = 1, _ height: Int = 1, _ hex: UInt32) {
        context.setFillColor(rgb(hex))
        context.fill(CGRect(x: x, y: y, width: width, height: height))
    }
}

private let floor = 0xE6EEF3 as UInt32
private let floorLine = 0xD7E2EA as UInt32
private let outline = 0x2B2D3A as UInt32

private func drawFloor(_ grid: Grid) {
    grid.fill(0, 0, columns, rows, floor)
    // Tiles, ten cells a side, offset so none is cut in half at the edges.
    for x in stride(from: 5, to: columns, by: 10) { grid.fill(x, 0, 1, rows, floorLine) }
    for y in stride(from: 5, to: rows, by: 10) { grid.fill(0, y, columns, 1, floorLine) }
}

/// The table the balls rest on, across the bottom.
private func drawTable(_ grid: Grid) {
    let top = 78
    grid.fill(0, top, columns, 1, 0xF0C084)          // lit edge
    grid.fill(0, top + 1, columns, 9, 0xD39458)      // top
    for x in stride(from: 3, to: columns, by: 19) { grid.fill(x, top + 4, 7, 1, 0xC4864C) }  // grain
    grid.fill(0, top + 10, columns, 1, 0x9C6334)     // front edge
    grid.fill(0, top + 11, columns, rows - top - 11, 0xB87A42)
    grid.fill(0, top + 11, columns, 1, 0x8A552B)
}

/// A Poké Ball 11 cells across, sitting on the table, its top half in `top`.
private func drawBall(_ grid: Grid, centerX: Int, top: UInt32, shade: UInt32) {
    // Row by row: where the ball starts and how wide it is.
    let shape: [(Int, Int)] = [(3, 5), (1, 9), (1, 9), (0, 11), (0, 11), (0, 11), (0, 11), (0, 11), (1, 9), (1, 9), (3, 5)]
    let x0 = centerX - 5, y0 = 67
    // Shadow on the table.
    grid.fill(x0 + 1, y0 + 11, 9, 1, 0xB47440)
    for (row, span) in shape.enumerated() {
        let y = y0 + row
        grid.fill(x0 + span.0 - 1, y, span.1 + 2, 1, outline)
        let color: UInt32 = row < 5 ? top : (row == 5 ? outline : 0xF4F6FA)
        grid.fill(x0 + span.0, y, span.1, 1, color)
        // The lower-right side is in shade.
        if row != 5 { grid.fill(x0 + span.0 + span.1 - 2, y, 2, 1, row < 5 ? shade : 0xC9CFDA) }
    }
    grid.fill(x0 + 3, y0 - 1, 5, 1, outline)                 // top outline
    grid.fill(x0 + 3, y0 + 11, 5, 1, outline)                // bottom outline
    // The button across the band.
    grid.fill(x0 + 4, y0 + 4, 3, 3, outline)
    grid.fill(x0 + 5, y0 + 5, 1, 1, 0xFFFFFF)
    // A glint.
    grid.fill(x0 + 3, y0 + 1, 2, 1, 0xFFFFFF)
    grid.fill(x0 + 2, y0 + 2, 1, 1, 0xFFFFFF)
}

/// Dots and a head from the app's spot toward Applications, at the icons' height.
private func drawArrow(_ grid: Grid) {
    let y = 42, color = 0x8FA3B6 as UInt32
    for x in stride(from: 60, to: 86, by: 4) { grid.fill(x, y, 2, 2, color) }
    for step in 0..<5 { grid.fill(88 + step, y - 4 + step, 2, 10 - step * 2, color) }
}

let grid = Grid()
drawFloor(grid)
drawArrow(grid)
drawTable(grid)
drawBall(grid, centerX: 57, top: 0x5CBF60, shade: 0x3E8F45)   // grass
drawBall(grid, centerX: 75, top: 0xF26C3A, shade: 0xC24A1E)   // fire
drawBall(grid, centerX: 93, top: 0x4A8FE2, shade: 0x2F68B4)   // water
let cells = grid.context.makeImage()!

/// The grid scaled up without smoothing, `scale` pixels per point.
func render(scale: Int) -> NSBitmapImageRep {
    let width = Int(pointSize.width) * scale, height = Int(pointSize.height) * scale
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = pointSize
    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    context.imageInterpolation = .none
    NSGraphicsContext.current = context
    context.cgContext.interpolationQuality = .none
    context.cgContext.draw(cells, in: CGRect(x: 0, y: 0, width: width, height: height))
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

// One size only: Finder showed a 1×+2× TIFF (tiffutil -cathidpicheck) at double size, and scales
// this up crisply on Retina.
let out = URL(fileURLWithPath: "Config/dmg-background.png")
try! render(scale: 1).representation(using: .png, properties: [:])!.write(to: out)
print("Wrote \(out.path)")
