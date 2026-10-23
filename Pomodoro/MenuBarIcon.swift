import AppKit

/// Monochrome template icons for the menu bar, so they match the other
/// status items in light mode, dark mode, and tinted menu bars.
enum MenuBarIcon {
    static let work: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.setFill()

            // Tomato body.
            NSBezierPath(ovalIn: NSRect(x: 1.5, y: 1, width: 15, height: 13)).fill()

            // Calyx: a five-point leaf crown, cut out of the body with a small gap.
            let crown = star(center: NSPoint(x: 9, y: 13), outer: 4.6, inner: 1.6)
            let context = NSGraphicsContext.current
            context?.compositingOperation = .clear
            crown.lineWidth = 2
            crown.stroke()
            context?.compositingOperation = .sourceOver
            crown.fill()

            // Stem.
            let stem = NSBezierPath()
            stem.move(to: NSPoint(x: 9, y: 14))
            stem.curve(to: NSPoint(x: 11, y: 17.5), controlPoint1: NSPoint(x: 9, y: 16), controlPoint2: NSPoint(x: 10, y: 17))
            stem.lineWidth = 1.4
            stem.lineCapStyle = .round
            NSColor.black.setStroke()
            stem.stroke()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Pomodoro"
        return image
    }()

    static let rest: NSImage = {
        let image = NSImage(systemSymbolName: "cup.and.saucer.fill", accessibilityDescription: "Break") ?? work
        image.isTemplate = true
        return image
    }()

    static func image(for phase: Phase) -> NSImage {
        phase == .work ? work : rest
    }

    private static func star(center: NSPoint, outer: CGFloat, inner: CGFloat) -> NSBezierPath {
        let path = NSBezierPath()
        for index in 0..<10 {
            let radius = index.isMultiple(of: 2) ? outer : inner
            let angle = CGFloat(index) * .pi / 5 + .pi / 2
            let point = NSPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle) * 0.7)
            if index == 0 {
                path.move(to: point)
            } else {
                path.line(to: point)
            }
        }
        path.close()
        path.lineJoinStyle = .round
        return path
    }
}
