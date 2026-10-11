import AppKit

extension AppTheme {
    private func color(_ light: UInt32, _ dark: UInt32) -> NSColor {
        let value = self == .refinedLight ? light : dark
        return NSColor(srgbRed: CGFloat((value >> 16) & 255) / 255, green: CGFloat((value >> 8) & 255) / 255, blue: CGFloat(value & 255) / 255, alpha: 1)
    }
    var background: NSColor { color(0xFFFFFF, 0x1D2230) }
    var text: NSColor { color(0x20283B, 0xEEF1FA) }
    var secondary: NSColor { color(0x65718A, 0xB1BBD1) }
    var accent: NSColor { color(0x6557E8, 0x9C91FF) }
    var inset: NSColor { color(0xF3F2FA, 0x171B27) }
    var border: NSColor { color(0xE3E7EF, 0x343B4F) }
    var appearance: NSAppearance? { NSAppearance(named: self == .refinedLight ? .aqua : .darkAqua) }
}
