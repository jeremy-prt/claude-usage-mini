import AppKit

private let barWidth: CGFloat = 22
private let barHeight: CGFloat = 4
private let rowGap: CGFloat = 2.5
private let cornerRadius: CGFloat = 2
private let iconHeight: CGFloat = 18
private let fontSize: CGFloat = 7
private let logoSize: CGFloat = 14

enum MenuBarIconStyle: String {
    case barres, icone, les2
}

func renderMenuBarIcon(pct5h: Double, pct7d: Double, style: MenuBarIconStyle = .barres) -> NSImage {
    switch style {
    case .barres:
        return renderBarsIcon(pct5h: pct5h, pct7d: pct7d)
    case .icone:
        return renderLogoOnlyIcon()
    case .les2:
        return renderLogoAndBarsIcon(pct5h: pct5h, pct7d: pct7d)
    }
}

func renderMenuBarIconUnauthenticated(style: MenuBarIconStyle = .barres) -> NSImage {
    switch style {
    case .barres:
        return renderBarsIconUnauthenticated()
    case .icone:
        return renderLogoOnlyIcon()
    case .les2:
        return renderLogoAndBarsIconUnauthenticated()
    }
}

// MARK: - Barres seules

private func renderBarsIcon(pct5h: Double, pct7d: Double) -> NSImage {
    let labelWidth: CGFloat = 12
    let totalWidth = labelWidth + 2 + barWidth + 2
    let image = NSImage(size: NSSize(width: totalWidth, height: iconHeight), flipped: true) { _ in
        let topY = (iconHeight - barHeight * 2 - rowGap) / 2
        let bottomY = topY + barHeight + rowGap
        drawLabel("5h", x: 0, y: topY, width: labelWidth)
        drawBar(x: labelWidth + 2, y: topY, width: barWidth, height: barHeight, pct: pct5h)
        drawLabel("7d", x: 0, y: bottomY, width: labelWidth)
        drawBar(x: labelWidth + 2, y: bottomY, width: barWidth, height: barHeight, pct: pct7d)
        return true
    }
    image.isTemplate = true
    return image
}

private func renderBarsIconUnauthenticated() -> NSImage {
    let labelWidth: CGFloat = 12
    let totalWidth = labelWidth + 2 + barWidth + 2
    let image = NSImage(size: NSSize(width: totalWidth, height: iconHeight), flipped: true) { _ in
        let topY = (iconHeight - barHeight * 2 - rowGap) / 2
        let bottomY = topY + barHeight + rowGap
        drawLabel("5h", x: 0, y: topY, width: labelWidth)
        drawDashedBar(x: labelWidth + 2, y: topY, width: barWidth, height: barHeight)
        drawLabel("7d", x: 0, y: bottomY, width: labelWidth)
        drawDashedBar(x: labelWidth + 2, y: bottomY, width: barWidth, height: barHeight)
        return true
    }
    image.isTemplate = true
    return image
}

// MARK: - Logo seul

private func renderLogoOnlyIcon() -> NSImage {
    let image = NSImage(size: NSSize(width: logoSize + 2, height: iconHeight), flipped: true) { _ in
        drawClaudeLogo(x: 1, y: (iconHeight - logoSize) / 2, size: logoSize)
        return true
    }
    image.isTemplate = true
    return image
}

// MARK: - Logo + Barres

private func renderLogoAndBarsIcon(pct5h: Double, pct7d: Double) -> NSImage {
    let labelWidth: CGFloat = 12
    let gap: CGFloat = 3
    let totalWidth = logoSize + gap + labelWidth + 2 + barWidth + 2
    let image = NSImage(size: NSSize(width: totalWidth, height: iconHeight), flipped: true) { _ in
        drawClaudeLogo(x: 0, y: (iconHeight - logoSize) / 2, size: logoSize)
        let offset = logoSize + gap
        let topY = (iconHeight - barHeight * 2 - rowGap) / 2
        let bottomY = topY + barHeight + rowGap
        drawLabel("5h", x: offset, y: topY, width: labelWidth)
        drawBar(x: offset + labelWidth + 2, y: topY, width: barWidth, height: barHeight, pct: pct5h)
        drawLabel("7d", x: offset, y: bottomY, width: labelWidth)
        drawBar(x: offset + labelWidth + 2, y: bottomY, width: barWidth, height: barHeight, pct: pct7d)
        return true
    }
    image.isTemplate = true
    return image
}

private func renderLogoAndBarsIconUnauthenticated() -> NSImage {
    let labelWidth: CGFloat = 12
    let gap: CGFloat = 3
    let totalWidth = logoSize + gap + labelWidth + 2 + barWidth + 2
    let image = NSImage(size: NSSize(width: totalWidth, height: iconHeight), flipped: true) { _ in
        drawClaudeLogo(x: 0, y: (iconHeight - logoSize) / 2, size: logoSize)
        let offset = logoSize + gap
        let topY = (iconHeight - barHeight * 2 - rowGap) / 2
        let bottomY = topY + barHeight + rowGap
        drawLabel("5h", x: offset, y: topY, width: labelWidth)
        drawDashedBar(x: offset + labelWidth + 2, y: topY, width: barWidth, height: barHeight)
        drawLabel("7d", x: offset, y: bottomY, width: labelWidth)
        drawDashedBar(x: offset + labelWidth + 2, y: bottomY, width: barWidth, height: barHeight)
        return true
    }
    image.isTemplate = true
    return image
}

// MARK: - Drawing helpers

private func drawLabel(_ text: String, x: CGFloat, y: CGFloat, width: CGFloat) {
    let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .medium)
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black]
    let str = NSAttributedString(string: text, attributes: attrs)
    let size = str.size()
    let labelY = y + (barHeight - size.height) / 2
    str.draw(at: NSPoint(x: x + width - size.width, y: labelY))
}

private func drawBar(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, pct: Double) {
    let bgRect = NSRect(x: x, y: y, width: width, height: height)
    let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: cornerRadius, yRadius: cornerRadius)
    NSColor.black.withAlphaComponent(0.25).setFill()
    bgPath.fill()

    let clampedPct = max(0, min(1, pct))
    if clampedPct > 0 {
        let fillRect = NSRect(x: x, y: y, width: width * clampedPct, height: height)
        let fillPath = NSBezierPath(roundedRect: fillRect, xRadius: cornerRadius, yRadius: cornerRadius)
        NSColor.black.setFill()
        fillPath.fill()
    }
}

private func drawDashedBar(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
    let rect = NSRect(x: x, y: y, width: width, height: height)
    let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
    NSColor.black.withAlphaComponent(0.25).setStroke()
    path.lineWidth = 1
    path.setLineDash([2, 2], count: 2, phase: 0)
    path.stroke()
}

// MARK: - Claude logo (vector from official SVG, viewBox 0 0 256 257)

nonisolated(unsafe) private let claudeLogoPath: NSBezierPath = {
    let path = NSBezierPath()
    // Official Claude sparkle logo path, scaled to unit square
    let svgPath = "M50.228,170.321 L100.585,142.064 L101.428,139.601 L100.585,138.24 L98.123,138.24 L89.697,137.722 L60.922,136.944 L35.97,135.907 L11.795,134.611 L5.703,133.314 L0,125.796 L0.583,122.037 L5.703,118.603 L13.027,119.251 L29.229,120.352 L53.533,122.037 L71.162,123.074 L97.28,125.796 L101.428,125.796 L102.011,124.111 L100.585,123.074 L99.484,122.037 L74.337,104.992 L47.117,86.975 L32.859,76.605 L25.146,71.355 L21.258,66.43 L19.573,55.672 L26.573,47.959 L35.97,48.608 L38.368,49.256 L47.895,56.579 L68.245,72.329 L94.817,91.9 L98.706,95.14 L100.261,94.038 L100.456,93.261 L98.706,90.344 L84.253,64.226 L68.828,37.654 L61.958,26.636 L60.144,20.026 L59.042,12.248 L67.014,1.425 L71.42,0 L82.05,1.426 L86.522,5.314 L93.132,20.415 L103.826,44.201 L120.417,76.541 L125.278,86.133 L127.87,95.012 L128.843,97.734 L130.528,97.734 L130.528,96.178 L131.888,77.967 L134.416,55.607 L136.879,26.831 L137.722,18.731 L141.74,9.009 L149.711,3.759 L155.933,6.74 L161.053,14.064 L160.34,18.794 L157.294,38.562 L151.332,69.542 L147.443,90.281 L149.711,90.281 L152.304,87.688 L162.803,73.754 L180.431,51.718 L188.209,42.969 L197.282,33.312 L203.115,28.711 L214.133,28.711 L222.233,40.766 L218.605,53.209 L207.263,67.597 L197.865,79.781 L184.385,97.928 L175.959,112.446 L176.737,113.612 L178.747,113.418 L209.207,106.937 L225.669,103.955 L245.306,100.585 L254.186,104.733 L255.157,108.946 L251.657,117.566 L230.659,122.75 L206.031,127.676 L169.349,136.361 L168.895,136.685 L169.414,137.333 L185.94,138.888 L193.005,139.277 L210.309,139.277 L242.519,141.675 L250.945,147.249 L256,154.054 L255.157,159.238 L242.195,165.849 L224.697,161.701 L183.867,151.98 L169.867,148.48 L167.923,148.48 L167.923,149.647 L179.589,161.053 L200.976,180.367 L227.743,205.254 L229.103,211.411 L225.669,216.271 L222.039,215.753 L198.513,198.06 L189.44,190.088 L168.895,172.784 L167.535,172.784 L167.535,174.598 L172.265,181.533 L197.282,219.123 L198.578,230.659 L196.764,234.419 L190.283,236.687 L183.153,235.39 L168.506,214.846 L153.406,191.708 L141.221,170.969 L139.731,171.812 L132.537,249.26 L129.167,253.213 L121.389,256.194 L114.909,251.269 L111.473,243.297 L114.908,227.548 L119.056,207.004 L122.426,190.671 L125.472,170.386 L127.287,163.646 L127.157,163.192 L125.667,163.386 L110.372,184.385 L87.105,215.818 L68.699,235.52 L64.292,237.27 L56.644,233.316 L57.357,226.252 L61.634,219.966 L87.104,187.561 L102.464,167.469 L112.381,155.869 L112.316,154.183 L111.733,154.183 L44.07,198.125 L32.015,199.68 L26.83,194.82 L27.478,186.848 L29.941,184.255 L50.291,170.256"

    // Parse and create path
    let scale: CGFloat = 1.0 / 256.0
    let commands = svgPath.components(separatedBy: " ")
    var i = 0
    while i < commands.count {
        let cmd = commands[i]
        if cmd.hasPrefix("M") || cmd.hasPrefix("L") {
            let coords = cmd.dropFirst().components(separatedBy: ",")
            if coords.count == 2, let px = Double(coords[0]), let py = Double(coords[1]) {
                let point = NSPoint(x: CGFloat(px) * scale, y: CGFloat(py) * scale)
                if cmd.hasPrefix("M") { path.move(to: point) }
                else { path.line(to: point) }
            }
        }
        i += 1
    }
    path.close()
    return path
}()

private func drawClaudeLogo(x: CGFloat, y: CGFloat, size: CGFloat) {
    var transform = AffineTransform.identity
    transform.scale(size)
    transform.translate(x: x / size, y: y / size)
    let scaled = claudeLogoPath.copy() as! NSBezierPath
    scaled.transform(using: transform)
    NSColor.black.setFill()
    scaled.fill()
}
