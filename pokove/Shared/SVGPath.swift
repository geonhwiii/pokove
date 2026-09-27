import SwiftUI

/// Parses SVG path data (`d` attributes) into a SwiftUI `Path`, in the SVG's own coordinates.
/// Supports M, L, H, V, C, S, Q, T and Z, absolute and relative — enough for icon sets.
nonisolated enum SVGPath {
    static func parse(_ data: String) -> Path {
        var path = Path()
        var scanner = Tokenizer(data)
        var command: Character = "M"
        var current = CGPoint.zero
        var start = CGPoint.zero
        var lastControl: CGPoint?
        var lastCommand: Character = " "

        while let token = scanner.next() {
            if case .command(let letter) = token {
                command = letter
                if letter == "Z" || letter == "z" {
                    path.closeSubpath()
                    current = start
                    lastControl = nil
                    lastCommand = letter
                    continue
                }
            } else {
                scanner.pushBack(token)
            }

            let relative = command.isLowercase
            func point() -> CGPoint? {
                guard let x = scanner.number(), let y = scanner.number() else { return nil }
                return relative ? CGPoint(x: current.x + x, y: current.y + y) : CGPoint(x: x, y: y)
            }

            switch command.uppercased().first {
            case "M":
                guard let p = point() else { return path }
                path.move(to: p)
                current = p
                start = p
                // Further pairs after a moveto are implicit linetos.
                command = relative ? "l" : "L"
                lastControl = nil
            case "L":
                guard let p = point() else { return path }
                path.addLine(to: p)
                current = p
                lastControl = nil
            case "H":
                guard let x = scanner.number() else { return path }
                current = CGPoint(x: relative ? current.x + x : x, y: current.y)
                path.addLine(to: current)
                lastControl = nil
            case "V":
                guard let y = scanner.number() else { return path }
                current = CGPoint(x: current.x, y: relative ? current.y + y : y)
                path.addLine(to: current)
                lastControl = nil
            case "C":
                guard let c1 = point(), let c2 = point(), let p = point() else { return path }
                path.addCurve(to: p, control1: c1, control2: c2)
                current = p
                lastControl = c2
            case "S":
                let reflected = reflect(lastControl, around: current, if: "CcSs".contains(lastCommand))
                guard let c2 = point(), let p = point() else { return path }
                path.addCurve(to: p, control1: reflected, control2: c2)
                current = p
                lastControl = c2
            case "Q":
                guard let c = point(), let p = point() else { return path }
                path.addQuadCurve(to: p, control: c)
                current = p
                lastControl = c
            case "T":
                let c = reflect(lastControl, around: current, if: "QqTt".contains(lastCommand))
                guard let p = point() else { return path }
                path.addQuadCurve(to: p, control: c)
                current = p
                lastControl = c
            default:
                return path
            }
            lastCommand = command
        }
        return path
    }

    private static func reflect(_ control: CGPoint?, around point: CGPoint, if applies: Bool) -> CGPoint {
        guard applies, let control else { return point }
        return CGPoint(x: 2 * point.x - control.x, y: 2 * point.y - control.y)
    }

    private enum Token {
        case command(Character)
        case number(CGFloat)
    }

    private struct Tokenizer {
        private let chars: [Character]
        private var index = 0
        private var pushed: Token?

        init(_ text: String) { chars = Array(text) }

        mutating func pushBack(_ token: Token) { pushed = token }

        mutating func number() -> CGFloat? {
            guard let token = next() else { return nil }
            if case .number(let value) = token { return value }
            pushBack(token)
            return nil
        }

        mutating func next() -> Token? {
            if let pushed {
                self.pushed = nil
                return pushed
            }
            while index < chars.count, chars[index] == " " || chars[index] == "," || chars[index].isNewline {
                index += 1
            }
            guard index < chars.count else { return nil }
            let char = chars[index]
            if char.isLetter && char != "e" && char != "E" {
                index += 1
                return .command(char)
            }
            // A number: optional sign, digits, at most one dot, optional exponent.
            var text = ""
            if char == "-" || char == "+" {
                text.append(char)
                index += 1
            }
            var seenDot = false
            while index < chars.count {
                let c = chars[index]
                if c.isNumber {
                    text.append(c)
                } else if c == "." && !seenDot {
                    seenDot = true
                    text.append(c)
                } else if (c == "e" || c == "E"), !text.isEmpty {
                    text.append(c)
                    index += 1
                    if index < chars.count, chars[index] == "-" || chars[index] == "+" {
                        text.append(chars[index])
                        index += 1
                    }
                    continue
                } else {
                    break
                }
                index += 1
            }
            guard let value = Double(text) else {
                index += 1
                return next()
            }
            return .number(CGFloat(value))
        }
    }
}

/// An SVG path drawn to fit its rect, keeping the view box's aspect ratio.
struct SVGShape: Shape {
    let path: Path
    let viewBox: CGRect

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width / viewBox.width, rect.height / viewBox.height)
        let offsetX = rect.minX + (rect.width - viewBox.width * scale) / 2 - viewBox.minX * scale
        let offsetY = rect.minY + (rect.height - viewBox.height * scale) / 2 - viewBox.minY * scale
        return path.applying(CGAffineTransform(a: scale, b: 0, c: 0, d: scale, tx: offsetX, ty: offsetY))
    }
}
