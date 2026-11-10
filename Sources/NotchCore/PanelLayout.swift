import Foundation

public struct NotchLayout: Equatable {
    public let screen: CGRect
    public let notchWidth: CGFloat
    public let notchHeight: CGFloat
    public let centerX: CGFloat
    public static let width: CGFloat = 440
    public static let bodyHeight: CGFloat = 330
    public init(screen: CGRect, notchWidth: CGFloat, notchHeight: CGFloat, centerX: CGFloat? = nil) {
        self.screen = screen
        self.notchWidth = max(120, notchWidth)
        self.notchHeight = max(24, notchHeight)
        self.centerX = centerX ?? screen.midX
    }
    public var windowFrame: CGRect {
        CGRect(x: centerX - 240, y: screen.maxY - notchHeight - Self.bodyHeight - 24,
               width: 480, height: notchHeight + Self.bodyHeight + 24)
    }
    // A narrow live strip sits immediately under the camera housing. It does not cover menu icons.
    public func visibleSize(expanded: Bool) -> CGSize {
        expanded ? CGSize(width: Self.width, height: notchHeight + Self.bodyHeight) : CGSize(width: notchWidth, height: notchHeight + 20)
    }
    public func screenRect(expanded: Bool) -> CGRect {
        let size = visibleSize(expanded: expanded)
        return CGRect(x: centerX - size.width / 2, y: screen.maxY - size.height, width: size.width, height: size.height + 2)
    }
    public func localRect(expanded: Bool) -> CGRect {
        let r = screenRect(expanded: expanded)
        return r.offsetBy(dx: -windowFrame.minX, dy: -windowFrame.minY)
    }
}

public enum PageBounds {
    public static func page(_ requested: Int, count: Int, size: Int) -> Int {
        min(max(0, requested), max(0, (count - 1) / max(1, size)))
    }
}
