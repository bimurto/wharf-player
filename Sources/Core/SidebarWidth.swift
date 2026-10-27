import Foundation

/// The sidebar's width limits and its saved width in `UserDefaults`.
public final class SidebarWidthStore {
    public static let minimum: Double = 320
    public static let defaultWidth: Double = 380
    /// Largest share of the window the sidebar may take.
    public static let maxFraction: Double = 0.75

    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "sidebar_width") {
        self.defaults = defaults
        self.key = key
    }

    /// The saved width, or nil when none was saved.
    public var saved: Double? {
        let value = defaults.double(forKey: key)
        return value > 0 ? value : nil
    }

    public func save(_ width: Double) {
        guard width.isFinite else { return }
        defaults.set(width, forKey: key)
    }

    /// Largest allowed width in a window `windowWidth` wide; never below the minimum.
    public static func maximum(windowWidth: Double) -> Double {
        max(minimum, windowWidth * maxFraction)
    }

    /// `width` limited to the minimum and 75% of the window. The saved value is not touched.
    public static func clamped(_ width: Double, windowWidth: Double) -> Double {
        min(max(width, minimum), maximum(windowWidth: windowWidth))
    }

    /// A keyboard action on the sidebar divider.
    public enum Resize { case narrower, wider, minimum, maximum }

    public static let step: Double = 20
    public static let largeStep: Double = 50

    /// The width after `action`; `large` is the Shift variant of the arrow keys. Result is clamped.
    public static func resized(_ width: Double, _ action: Resize, large: Bool = false, windowWidth: Double) -> Double {
        let delta = large ? largeStep : step
        switch action {
        case .narrower: return clamped(width - delta, windowWidth: windowWidth)
        case .wider: return clamped(width + delta, windowWidth: windowWidth)
        case .minimum: return minimum
        case .maximum: return maximum(windowWidth: windowWidth)
        }
    }
}
